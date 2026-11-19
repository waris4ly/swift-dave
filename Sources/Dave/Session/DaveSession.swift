import Foundation

public actor DaveSession {

    public let selfUserID: UInt64
    public let channelID: UInt64
    public let configuration: DaveConfiguration

    private let engine: any MLSEngine
    private let encryptor: any FrameEncryptor
    private var users: UserRegistry
    private var transitions = TransitionTracker()
    private var pendingGroupTransitions: Set<UInt64> = []

    private let outgoingStream: AsyncStream<DaveOutgoing>
    private let outgoingContinuation: AsyncStream<DaveOutgoing>.Continuation

    private var currentProtocolVersion: DaveProtocolVersion?
    private var isInitialized: Bool = false
    private var isClosed: Bool = false
    private var hasEncryptorRatchet: Bool = false

    public static var maxSupportedProtocolVersion: DaveProtocolVersion {
        DaveProtocolVersion.maxSupported
    }

    public var outgoing: AsyncStream<DaveOutgoing> {
        outgoingStream
    }

    /// whether frames can be encrypted and sent; callers must hold frames while false
    public var isReady: Bool {
        if isClosed { return false }
        guard let version = currentProtocolVersion else {
            return false
        }
        if version == .disabled {
            return true
        }
        // when encryptor is closed or query fails, default to unready
        let passthrough = (try? encryptor.isPassthroughMode) ?? true
        let hasRatchet = (try? encryptor.hasKeyRatchet) ?? false
        return !passthrough && hasRatchet
    }

    public init(
        userID: UInt64,
        channelID: UInt64,
        configuration: DaveConfiguration = .init()
    ) throws(DaveError) {
        let engine = try LibdaveSession(authSessionID: configuration.authSessionID)
        let encryptor = try LibdaveEncryptor()
        try encryptor.setPassthroughMode(true)

        self.init(
            userID: userID,
            channelID: channelID,
            configuration: configuration,
            engine: engine,
            encryptor: encryptor,
            decryptorFactory: { () throws(DaveError) -> any FrameDecryptor in
                try LibdaveDecryptor()
            }
        )
    }

    init(
        userID: UInt64,
        channelID: UInt64,
        configuration: DaveConfiguration = .init(),
        engine: any MLSEngine,
        encryptor: any FrameEncryptor,
        decryptorFactory: @escaping @Sendable () throws(DaveError) -> any FrameDecryptor
    ) {
        self.selfUserID = userID
        self.channelID = channelID
        self.configuration = configuration
        self.engine = engine
        self.encryptor = encryptor
        self.users = UserRegistry(decryptorFactory: decryptorFactory)

        let (stream, continuation) = AsyncStream.makeStream(of: DaveOutgoing.self)
        self.outgoingStream = stream
        self.outgoingContinuation = continuation
    }

    public func acknowledgeProtocolVersion(_ version: DaveProtocolVersion) throws(DaveError) {
        guard !isClosed else { throw DaveError.handleClosed }
        currentProtocolVersion = version
        if version > .disabled {
            try initSessionIfNeeded(version: version)
            let kp = try engine.marshalledKeyPackage()
            outgoingContinuation.yield(.keyPackage(kp))
        } else {
            try prepareTransition(transitionID: 0, protocolVersion: .disabled)
            try executeTransition(transitionID: 0)
        }
    }

    public func prepareEpoch(
        _ epoch: UInt64,
        protocolVersion: DaveProtocolVersion
    ) throws(DaveError) {
        guard !isClosed else { throw DaveError.handleClosed }
        if epoch == 1 {
            currentProtocolVersion = protocolVersion
            if protocolVersion > .disabled {
                try initSessionIfNeeded(version: protocolVersion)
                let kp = try engine.marshalledKeyPackage()
                outgoingContinuation.yield(.keyPackage(kp))
            }
        }
    }

    public func setExternalSender(_ senderData: [UInt8]) throws(DaveError) {
        guard !isClosed else { throw DaveError.handleClosed }
        try engine.setExternalSender(senderData)
    }

    public func processProposals(_ proposalsData: [UInt8]) throws(DaveError) {
        guard !isClosed else { throw DaveError.handleClosed }
        let commitWelcome = try engine.processProposals(proposalsData)
        if !commitWelcome.isEmpty {
            outgoingContinuation.yield(.commitAndWelcome(commitWelcome))
        }
    }

    public func announceCommitTransition(
        transitionID: UInt64,
        commit: [UInt8]
    ) throws(DaveError) {
        guard !isClosed else { throw DaveError.handleClosed }
        let outcome = try engine.processCommit(commit)
        switch outcome {
        case .ignored:
            return
        case .failed:
            outgoingContinuation.yield(.invalidCommitWelcome(transitionID: transitionID))
            try reinitProtocol()
        case .ok:
            try applyGroupTransition(transitionID: transitionID)
        }
    }

    public func processWelcome(
        transitionID: UInt64,
        welcome: [UInt8]
    ) throws(DaveError) {
        guard !isClosed else { throw DaveError.handleClosed }
        do {
            try engine.processWelcome(welcome)
            try applyGroupTransition(transitionID: transitionID)
        } catch {
            outgoingContinuation.yield(.invalidCommitWelcome(transitionID: transitionID))
            try reinitProtocol()
        }
    }

    public func prepareTransition(
        transitionID: UInt64,
        protocolVersion: DaveProtocolVersion
    ) throws(DaveError) {
        guard !isClosed else { throw DaveError.handleClosed }
        transitions.prepare(transitionID: transitionID, version: protocolVersion)

        if protocolVersion == .disabled {
            try users.setPassthroughMode(true)
            if transitionID == 0 {
                try encryptor.setPassthroughMode(true)
                try encryptor.setKeyRatchet(nil)
                hasEncryptorRatchet = false
            } else {
                outgoingContinuation.yield(.readyForTransition(transitionID: transitionID))
            }
            return
        }

        if pendingGroupTransitions.contains(transitionID) || transitionID == 0 {
            try finishPrepareTransition(transitionID: transitionID, version: protocolVersion)
        }
    }

    public func executeTransition(transitionID: UInt64) throws(DaveError) {
        guard !isClosed else { throw DaveError.handleClosed }
        guard let version = transitions.consume(transitionID: transitionID) else {
            throw DaveError.unknownTransition
        }
        currentProtocolVersion = version
        if version == .disabled {
            try engine.reset()
            try encryptor.setPassthroughMode(true)
            try encryptor.setKeyRatchet(nil)
            try users.setPassthroughMode(true)
            hasEncryptorRatchet = false
        } else {
            let selfRatchet = try engine.getKeyRatchet(for: String(selfUserID))
            try encryptor.setKeyRatchet(selfRatchet)
            try encryptor.setPassthroughMode(false)
            hasEncryptorRatchet = true
        }
    }

    public func addUser(userID: UInt64) throws(DaveError) {
        guard !isClosed else { throw DaveError.handleClosed }
        try engine.addRecognizedUser(String(userID))
        let decryptor = try users.addUser(userID)
        // remote user may not have an active ratchet until the next commit
        if let version = currentProtocolVersion, version > .disabled,
            let ratchet = try? engine.getKeyRatchet(for: String(userID))
        {
            try decryptor.transitionToKeyRatchet(ratchet)
            try decryptor.transitionToPassthroughMode(false)
        } else {
            try decryptor.transitionToPassthroughMode(true)
        }
    }

    public func removeUser(userID: UInt64) throws(DaveError) {
        guard !isClosed else { throw DaveError.handleClosed }
        try engine.removeRecognizedUser(String(userID))
        users.removeUser(userID)
    }

    public func assignSSRC(_ ssrc: UInt32, codec: DaveCodec = .opus) throws(DaveError) {
        guard !isClosed else { throw DaveError.handleClosed }
        try encryptor.assignSSRC(ssrc, codec: codec)
    }

    /// encrypts a frame; throws notReady when isReady is false to enforce the hold rule
    public func encrypt(frame: [UInt8], ssrc: UInt32) throws(DaveError) -> [UInt8] {
        guard !isClosed else { throw DaveError.handleClosed }
        guard isReady else { throw DaveError.notReady }
        return try encryptor.encrypt(ssrc: ssrc, frame: frame)
    }

    public func decrypt(frame: [UInt8], userID: UInt64) throws(DaveError) -> [UInt8] {
        guard !isClosed else { throw DaveError.handleClosed }
        guard let decryptor = users.decryptor(for: userID) else {
            throw DaveError.unknownUser
        }
        return try decryptor.decrypt(encryptedFrame: frame)
    }

    public func lastEpochAuthenticator() throws(DaveError) -> [UInt8] {
        guard !isClosed else { throw DaveError.handleClosed }
        return try engine.lastEpochAuthenticator()
    }

    public func pairwiseFingerprint(
        version: DaveProtocolVersion,
        userID: UInt64
    ) async throws(DaveError) -> [UInt8] {
        guard !isClosed else { throw DaveError.handleClosed }
        return try await engine.pairwiseFingerprint(
            version: version.rawValue,
            userID: String(userID)
        )
    }

    public func close() async {
        guard !isClosed else { return }
        isClosed = true
        outgoingContinuation.finish()
        transitions.clear()
        pendingGroupTransitions.removeAll()
        users.closeAll()
        encryptor.close()
        engine.close()
    }

    private func initSessionIfNeeded(version: DaveProtocolVersion) throws(DaveError) {
        if !isInitialized {
            try engine.initialize(
                version: version.rawValue,
                groupID: channelID,
                selfUserID: String(selfUserID)
            )
            isInitialized = true
        } else {
            try engine.setProtocolVersion(version.rawValue)
        }
    }

    private func reinitProtocol() throws(DaveError) {
        try engine.reset()
        let version = currentProtocolVersion ?? .v1
        try engine.initialize(
            version: version.rawValue,
            groupID: channelID,
            selfUserID: String(selfUserID)
        )
        for uid in users.recognizedUserIDs {
            try engine.addRecognizedUser(String(uid))
        }
        let kp = try engine.marshalledKeyPackage()
        outgoingContinuation.yield(.keyPackage(kp))
    }

    private func applyGroupTransition(transitionID: UInt64) throws(DaveError) {
        pendingGroupTransitions.insert(transitionID)
        if let version = transitions.version(for: transitionID) {
            try finishPrepareTransition(transitionID: transitionID, version: version)
        }
    }

    private func finishPrepareTransition(
        transitionID: UInt64,
        version: DaveProtocolVersion
    ) throws(DaveError) {
        pendingGroupTransitions.remove(transitionID)
        if version > .disabled {
            try users.updateKeyRatchets { uid in
                // members not yet in the active roster return nil and remain in passthrough
                try? engine.getKeyRatchet(for: String(uid))
            }
            if transitionID == 0 {
                let selfRatchet = try engine.getKeyRatchet(for: String(selfUserID))
                try encryptor.setKeyRatchet(selfRatchet)
                try encryptor.setPassthroughMode(false)
                hasEncryptorRatchet = true
            } else {
                outgoingContinuation.yield(.readyForTransition(transitionID: transitionID))
            }
        }
    }
}
