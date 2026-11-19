import CLibDave

final class LibdaveKeyRatchet: KeyRatchetHandle {

    private let handle: NativeHandle<DAVEKeyRatchetHandle>

    init(_ rawHandle: DAVEKeyRatchetHandle) {
        self.handle = NativeHandle(rawHandle, destroy: daveKeyRatchetDestroy)
    }

    func close() {
        handle.close()
    }

    func withUnsafeHandle<R, E: Error>(_ body: (DAVEKeyRatchetHandle) throws(E) -> R)
        throws(DaveError) -> R
    {
        try handle.withUnsafePointer(body)
    }
}
