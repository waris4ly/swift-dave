import os

@testable import Dave

final class MockKeyRatchet: KeyRatchetHandle {
    let id: String
    private let state = OSAllocatedUnfairLock(initialState: false)

    init(id: String = "mock-ratchet") {
        self.id = id
    }

    var isClosed: Bool {
        state.withLock { $0 }
    }

    func close() {
        state.withLock { $0 = true }
    }
}

final class MockFrameEncryptor: FrameEncryptor {
    struct State {
        var ratchet: (any KeyRatchetHandle)?
        var passthrough: Bool = true
        var assignedSSRCs: [UInt32: DaveCodec] = [:]
        var isClosed: Bool = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func setKeyRatchet(_ ratchet: (any KeyRatchetHandle)?) throws(DaveError) {
        let res: Result<Void, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            s.ratchet = ratchet
            return .success(())
        }
        switch res {
        case .success: return
        case .failure(let err): throw err
        }
    }

    func setPassthroughMode(_ enabled: Bool) throws(DaveError) {
        let res: Result<Void, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            s.passthrough = enabled
            return .success(())
        }
        switch res {
        case .success: return
        case .failure(let err): throw err
        }
    }

    func assignSSRC(_ ssrc: UInt32, codec: DaveCodec) throws(DaveError) {
        let res: Result<Void, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            s.assignedSSRCs[ssrc] = codec
            return .success(())
        }
        switch res {
        case .success: return
        case .failure(let err): throw err
        }
    }

    var hasKeyRatchet: Bool {
        state.withLock { $0.ratchet != nil }
    }

    var isPassthroughMode: Bool {
        state.withLock { $0.passthrough }
    }

    func encrypt(ssrc: UInt32, frame: [UInt8]) throws(DaveError) -> [UInt8] {
        let res: Result<[UInt8], DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            if s.passthrough { return .success(frame) }
            return .success(frame.map { $0 ^ 0xAA })
        }
        switch res {
        case .success(let data): return data
        case .failure(let err): throw err
        }
    }

    func close() {
        state.withLock { $0.isClosed = true }
    }
}

final class MockFrameDecryptor: FrameDecryptor {
    struct State {
        var ratchet: (any KeyRatchetHandle)?
        var passthrough: Bool = true
        var isClosed: Bool = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func transitionToKeyRatchet(_ ratchet: (any KeyRatchetHandle)?) throws(DaveError) {
        let res: Result<Void, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            s.ratchet = ratchet
            return .success(())
        }
        switch res {
        case .success: return
        case .failure(let err): throw err
        }
    }

    func transitionToPassthroughMode(_ enabled: Bool) throws(DaveError) {
        let res: Result<Void, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            s.passthrough = enabled
            return .success(())
        }
        switch res {
        case .success: return
        case .failure(let err): throw err
        }
    }

    func decrypt(encryptedFrame: [UInt8]) throws(DaveError) -> [UInt8] {
        let res: Result<[UInt8], DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            if s.passthrough { return .success(encryptedFrame) }
            return .success(encryptedFrame.map { $0 ^ 0xAA })
        }
        switch res {
        case .success(let data): return data
        case .failure(let err): throw err
        }
    }

    func close() {
        state.withLock { $0.isClosed = true }
    }
}

final class MockEngine: MLSEngine {
    struct State {
        var initializedVersion: UInt16?
        var initializedGroupID: UInt64?
        var initializedSelfUserID: String?
        var isReset: Bool = false
        var isClosed: Bool = false
        var externalSenderData: [UInt8]?
        var recognizedUsers: Set<String> = []
        var proposalsResponse: [UInt8] = [1, 2, 3]
        var commitOutcome: CommitOutcome = .ok
        var welcomeShouldThrow: Bool = false
        var keyPackageBytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
        var ratchets: [String: MockKeyRatchet] = [:]
        var authenticatorBytes: [UInt8] = [0x01, 0x02]
        var fingerprintBytes: [UInt8] = [0x09, 0x08]
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func setCommitOutcome(_ outcome: CommitOutcome) {
        state.withLock { $0.commitOutcome = outcome }
    }

    func setWelcomeShouldThrow(_ value: Bool) {
        state.withLock { $0.welcomeShouldThrow = value }
    }

    func setProposalsResponse(_ response: [UInt8]) {
        state.withLock { $0.proposalsResponse = response }
    }

    func setKeyPackageBytes(_ bytes: [UInt8]) {
        state.withLock { $0.keyPackageBytes = bytes }
    }

    var recognizedUsers: Set<String> {
        state.withLock { $0.recognizedUsers }
    }

    var isReset: Bool {
        state.withLock { $0.isReset }
    }

    func initialize(version: UInt16, groupID: UInt64, selfUserID: String) throws(DaveError) {
        let res: Result<Void, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            s.initializedVersion = version
            s.initializedGroupID = groupID
            s.initializedSelfUserID = selfUserID
            return .success(())
        }
        switch res {
        case .success: return
        case .failure(let err): throw err
        }
    }

    func reset() throws(DaveError) {
        let res: Result<Void, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            s.isReset = true
            return .success(())
        }
        switch res {
        case .success: return
        case .failure(let err): throw err
        }
    }

    func setProtocolVersion(_ version: UInt16) throws(DaveError) {
        let res: Result<Void, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            s.initializedVersion = version
            return .success(())
        }
        switch res {
        case .success: return
        case .failure(let err): throw err
        }
    }

    var protocolVersion: UInt16 {
        get throws(DaveError) {
            let res: Result<UInt16, DaveError> = state.withLock { s in
                if s.isClosed { return .failure(.handleClosed) }
                return .success(s.initializedVersion ?? 0)
            }
            switch res {
            case .success(let v): return v
            case .failure(let err): throw err
            }
        }
    }

    func setExternalSender(_ bytes: [UInt8]) throws(DaveError) {
        let res: Result<Void, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            s.externalSenderData = bytes
            return .success(())
        }
        switch res {
        case .success: return
        case .failure(let err): throw err
        }
    }

    func addRecognizedUser(_ userID: String) throws(DaveError) {
        let res: Result<Void, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            s.recognizedUsers.insert(userID)
            return .success(())
        }
        switch res {
        case .success: return
        case .failure(let err): throw err
        }
    }

    func removeRecognizedUser(_ userID: String) throws(DaveError) {
        let res: Result<Void, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            s.recognizedUsers.remove(userID)
            return .success(())
        }
        switch res {
        case .success: return
        case .failure(let err): throw err
        }
    }

    func processProposals(_ proposals: [UInt8]) throws(DaveError) -> [UInt8] {
        let res: Result<[UInt8], DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            return .success(s.proposalsResponse)
        }
        switch res {
        case .success(let data): return data
        case .failure(let err): throw err
        }
    }

    func processCommit(_ commit: [UInt8]) throws(DaveError) -> CommitOutcome {
        let res: Result<CommitOutcome, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            return .success(s.commitOutcome)
        }
        switch res {
        case .success(let o): return o
        case .failure(let err): throw err
        }
    }

    func processWelcome(_ welcome: [UInt8]) throws(DaveError) {
        let res: Result<Void, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            if s.welcomeShouldThrow { return .failure(.commitFailed) }
            return .success(())
        }
        switch res {
        case .success: return
        case .failure(let err): throw err
        }
    }

    func marshalledKeyPackage() throws(DaveError) -> [UInt8] {
        let res: Result<[UInt8], DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            return .success(s.keyPackageBytes)
        }
        switch res {
        case .success(let kp): return kp
        case .failure(let err): throw err
        }
    }

    func getKeyRatchet(for userID: String) throws(DaveError) -> any KeyRatchetHandle {
        let res: Result<any KeyRatchetHandle, DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            if let existing = s.ratchets[userID] { return .success(existing) }
            let r = MockKeyRatchet(id: userID)
            s.ratchets[userID] = r
            return .success(r)
        }
        switch res {
        case .success(let r): return r
        case .failure(let err): throw err
        }
    }

    func lastEpochAuthenticator() throws(DaveError) -> [UInt8] {
        let res: Result<[UInt8], DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            return .success(s.authenticatorBytes)
        }
        switch res {
        case .success(let a): return a
        case .failure(let err): throw err
        }
    }

    func pairwiseFingerprint(version: UInt16, userID: String) async throws(DaveError) -> [UInt8] {
        let res: Result<[UInt8], DaveError> = state.withLock { s in
            if s.isClosed { return .failure(.handleClosed) }
            return .success(s.fingerprintBytes)
        }
        switch res {
        case .success(let fp): return fp
        case .failure(let err): throw err
        }
    }

    func close() {
        state.withLock { s in
            s.isClosed = true
            for r in s.ratchets.values { r.close() }
        }
    }
}
