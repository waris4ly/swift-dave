import CLibDave

final class LibdaveSession: Sendable {

    private let handle: NativeHandle<DAVESessionHandle>

    init(authSessionID: String? = nil) throws(DaveError) {
        let raw =
            authSessionID.map { id in
                id.withCString { daveSessionCreate(nil, $0, nil, nil) }
            } ?? daveSessionCreate(nil, nil, nil, nil)

        guard let raw else {
            throw .handleClosed
        }
        self.handle = NativeHandle(raw, destroy: daveSessionDestroy)
    }

    func close() {
        handle.close()
    }

    func initialize(
        version: UInt16,
        groupID: UInt64,
        selfUserID: String
    ) throws(DaveError) {
        try handle.withUnsafePointer { s in
            selfUserID.withCString { userPtr in
                daveSessionInit(s, version, groupID, userPtr)
            }
        }
    }

    func reset() throws(DaveError) {
        try handle.withUnsafePointer { daveSessionReset($0) }
    }

    func setProtocolVersion(_ version: UInt16) throws(DaveError) {
        try handle.withUnsafePointer { daveSessionSetProtocolVersion($0, version) }
    }

    var protocolVersion: UInt16 {
        get throws(DaveError) {
            try handle.withUnsafePointer { daveSessionGetProtocolVersion($0) }
        }
    }

    func lastEpochAuthenticator() throws(DaveError) -> [UInt8] {
        try handle.withUnsafePointer { s in
            var outPtr: UnsafeMutablePointer<UInt8>?
            var count: Int = 0
            daveSessionGetLastEpochAuthenticator(s, &outPtr, &count)
            return copyAndFreeBytes(pointer: outPtr, count: count)
        }
    }

    func setExternalSender(_ bytes: [UInt8]) throws(DaveError) {
        try handle.withUnsafePointer { s in
            bytes.withUnsafeBufferPointer { buf in
                daveSessionSetExternalSender(s, buf.baseAddress, buf.count)
            }
        }
    }

    func addRecognizedUser(_ userID: String) throws(DaveError) {
        try handle.withUnsafePointer { s in
            userID.withCString { daveSessionAddRecognizedUser(s, $0) }
        }
    }

    func removeRecognizedUser(_ userID: String) throws(DaveError) {
        try handle.withUnsafePointer { s in
            userID.withCString { daveSessionRemoveRecognizedUser(s, $0) }
        }
    }

    func processProposals(_ proposals: [UInt8]) throws(DaveError) -> [UInt8] {
        try handle.withUnsafePointer { s in
            var outPtr: UnsafeMutablePointer<UInt8>?
            var count: Int = 0
            proposals.withUnsafeBufferPointer { buf in
                daveSessionProcessProposals(s, buf.baseAddress, buf.count, &outPtr, &count)
            }
            return copyAndFreeBytes(pointer: outPtr, count: count)
        }
    }

    func processCommitResult(_ commit: [UInt8]) throws(DaveError) -> LibdaveCommitResult {
        try handle.withUnsafePointer { (s) throws(DaveError) in
            let resHandle = commit.withUnsafeBufferPointer { buf in
                daveSessionProcessCommit(s, buf.baseAddress, buf.count)
            }
            guard let resHandle else {
                throw DaveError.commitFailed
            }
            return LibdaveCommitResult(resHandle)
        }
    }

    func processCommit(_ commit: [UInt8]) throws(DaveError) -> CommitOutcome {
        let res = try processCommitResult(commit)
        if try res.isIgnored {
            return .ignored
        }
        if try res.isFailed {
            return .failed
        }
        return .ok
    }

    func processWelcomeResult(_ welcome: [UInt8]) throws(DaveError) -> LibdaveWelcomeResult {
        try handle.withUnsafePointer { (s) throws(DaveError) in
            let resHandle = welcome.withUnsafeBufferPointer { buf in
                daveSessionProcessWelcome(s, buf.baseAddress, buf.count)
            }
            guard let resHandle else {
                throw DaveError.commitFailed
            }
            return LibdaveWelcomeResult(resHandle)
        }
    }

    func processWelcome(_ welcome: [UInt8]) throws(DaveError) {
        _ = try processWelcomeResult(welcome)
    }

    func marshalledKeyPackage() throws(DaveError) -> [UInt8] {
        try handle.withUnsafePointer { s in
            var outPtr: UnsafeMutablePointer<UInt8>?
            var count: Int = 0
            daveSessionGetMarshalledKeyPackage(s, &outPtr, &count)
            return copyAndFreeBytes(pointer: outPtr, count: count)
        }
    }

    func keyRatchet(for userID: String) throws(DaveError) -> LibdaveKeyRatchet {
        try handle.withUnsafePointer { (s) throws(DaveError) in
            let ratchetHandle = userID.withCString { daveSessionGetKeyRatchet(s, $0) }
            guard let ratchetHandle else {
                throw DaveError.missingKeyRatchet
            }
            return LibdaveKeyRatchet(ratchetHandle)
        }
    }

    func pairwiseFingerprint(version: UInt16, userID: String) async throws(DaveError) -> [UInt8] {
        try handle.withUnsafePointer { _ in () }
        return await withCheckedContinuation { continuation in
            do {
                try handle.withUnsafePointer { s in
                    let contPtr = UnsafeMutablePointer<CheckedContinuation<[UInt8], Never>>
                        .allocate(capacity: 1)
                    contPtr.initialize(to: continuation)
                    userID.withCString { userPtr in
                        daveSessionGetPairwiseFingerprint(
                            s,
                            version,
                            userPtr,
                            { fpPtr, len, ctx in
                                guard let ctx else { return }
                                let p = ctx.assumingMemoryBound(
                                    to: CheckedContinuation<[UInt8], Never>.self)
                                let bytes: [UInt8]
                                if let fpPtr, len > 0 {
                                    bytes = Array(UnsafeBufferPointer(start: fpPtr, count: len))
                                } else {
                                    bytes = []
                                }
                                let cont = p.move()
                                p.deallocate()
                                cont.resume(returning: bytes)
                            },
                            contPtr
                        )
                    }
                }
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}
