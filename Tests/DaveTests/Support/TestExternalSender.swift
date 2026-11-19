import CDaveTestSupport

@testable import Dave

final class TestExternalSender {

    private var handle: DAVEExternalSenderHandle?

    init(groupID: UInt64) throws(DaveError) {
        guard let raw = daveExternalSenderCreate(groupID) else {
            throw DaveError.handleClosed
        }
        self.handle = raw
    }

    deinit {
        close()
    }

    func close() {
        guard let h = handle else { return }
        handle = nil
        daveExternalSenderDestroy(h)
    }

    func marshalledExternalSender() -> [UInt8] {
        guard let handle else { return [] }
        var outPtr: UnsafeMutablePointer<UInt8>?
        var count: Int = 0
        daveExternalSenderGetMarshalledExternalSender(handle, &outPtr, &count)
        guard let outPtr, count > 0 else {
            if let outPtr {
                daveTestFree(outPtr)
            }
            return []
        }
        defer { daveTestFree(outPtr) }
        return Array(UnsafeBufferPointer(start: outPtr, count: count))
    }

    func proposeAdd(epoch: UInt32, keyPackage: [UInt8]) -> [UInt8] {
        guard let handle else { return [] }
        var outPtr: UnsafeMutablePointer<UInt8>?
        var count: Int = 0
        keyPackage.withUnsafeBufferPointer { buf in
            daveExternalSenderProposeAdd(
                handle,
                epoch,
                buf.baseAddress,
                buf.count,
                &outPtr,
                &count
            )
        }
        guard let outPtr, count > 0 else {
            if let outPtr {
                daveTestFree(outPtr)
            }
            return []
        }
        defer { daveTestFree(outPtr) }
        return Array(UnsafeBufferPointer(start: outPtr, count: count))
    }

    func splitCommitWelcome(_ commitWelcome: [UInt8]) -> (commit: [UInt8], welcome: [UInt8]) {
        guard let handle else { return ([], []) }
        var commitPtr: UnsafeMutablePointer<UInt8>?
        var commitLen: Int = 0
        var welcomePtr: UnsafeMutablePointer<UInt8>?
        var welcomeLen: Int = 0

        commitWelcome.withUnsafeBufferPointer { buf in
            daveExternalSenderSplitCommitWelcome(
                handle,
                buf.baseAddress,
                buf.count,
                &commitPtr,
                &commitLen,
                &welcomePtr,
                &welcomeLen
            )
        }

        let commit: [UInt8]
        if let commitPtr, commitLen > 0 {
            commit = Array(UnsafeBufferPointer(start: commitPtr, count: commitLen))
            daveTestFree(commitPtr)
        } else {
            if let commitPtr { daveTestFree(commitPtr) }
            commit = []
        }

        let welcome: [UInt8]
        if let welcomePtr, welcomeLen > 0 {
            welcome = Array(UnsafeBufferPointer(start: welcomePtr, count: welcomeLen))
            daveTestFree(welcomePtr)
        } else {
            if let welcomePtr { daveTestFree(welcomePtr) }
            welcome = []
        }

        return (commit, welcome)
    }
}
