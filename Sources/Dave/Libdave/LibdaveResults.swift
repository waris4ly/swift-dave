import CLibDave

final class LibdaveCommitResult: Sendable {

    private let handle: NativeHandle<DAVECommitResultHandle>

    init(_ rawHandle: DAVECommitResultHandle) {
        self.handle = NativeHandle(rawHandle, destroy: daveCommitResultDestroy)
    }

    func close() {
        handle.close()
    }

    var isFailed: Bool {
        get throws(DaveError) {
            try handle.withUnsafePointer { daveCommitResultIsFailed($0) }
        }
    }

    var isIgnored: Bool {
        get throws(DaveError) {
            try handle.withUnsafePointer { daveCommitResultIsIgnored($0) }
        }
    }

    func rosterMemberIDs() throws(DaveError) -> [UInt64] {
        try handle.withUnsafePointer { p in
            var idsPtr: UnsafeMutablePointer<UInt64>?
            var count: Int = 0
            daveCommitResultGetRosterMemberIds(p, &idsPtr, &count)
            return copyAndFreeUInt64Array(pointer: idsPtr, count: count)
        }
    }

    func rosterMemberSignature(rosterID: UInt64) throws(DaveError) -> [UInt8] {
        try handle.withUnsafePointer { p in
            var sigPtr: UnsafeMutablePointer<UInt8>?
            var count: Int = 0
            daveCommitResultGetRosterMemberSignature(p, rosterID, &sigPtr, &count)
            return copyAndFreeBytes(pointer: sigPtr, count: count)
        }
    }
}

final class LibdaveWelcomeResult: Sendable {

    private let handle: NativeHandle<DAVEWelcomeResultHandle>

    init(_ rawHandle: DAVEWelcomeResultHandle) {
        self.handle = NativeHandle(rawHandle, destroy: daveWelcomeResultDestroy)
    }

    func close() {
        handle.close()
    }

    func rosterMemberIDs() throws(DaveError) -> [UInt64] {
        try handle.withUnsafePointer { p in
            var idsPtr: UnsafeMutablePointer<UInt64>?
            var count: Int = 0
            daveWelcomeResultGetRosterMemberIds(p, &idsPtr, &count)
            return copyAndFreeUInt64Array(pointer: idsPtr, count: count)
        }
    }

    func rosterMemberSignature(rosterID: UInt64) throws(DaveError) -> [UInt8] {
        try handle.withUnsafePointer { p in
            var sigPtr: UnsafeMutablePointer<UInt8>?
            var count: Int = 0
            daveWelcomeResultGetRosterMemberSignature(p, rosterID, &sigPtr, &count)
            return copyAndFreeBytes(pointer: sigPtr, count: count)
        }
    }
}
