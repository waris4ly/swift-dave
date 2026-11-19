import CLibDave

final class LibdaveDecryptor: Sendable {

    private let handle: NativeHandle<DAVEDecryptorHandle>

    init() throws(DaveError) {
        guard let raw = daveDecryptorCreate() else {
            throw .handleClosed
        }
        self.handle = NativeHandle(raw, destroy: daveDecryptorDestroy)
    }

    func close() {
        handle.close()
    }

    func transitionToKeyRatchet(_ ratchet: (any KeyRatchetHandle)?) throws(DaveError) {
        try handle.withUnsafePointer { dec in
            if let libdaveRatchet = ratchet as? LibdaveKeyRatchet {
                try libdaveRatchet.withUnsafeHandle { r in
                    daveDecryptorTransitionToKeyRatchet(dec, r)
                }
            } else if ratchet == nil {
                daveDecryptorTransitionToKeyRatchet(dec, nil)
            } else {
                throw DaveError.invalidInput
            }
        }
    }

    func transitionToPassthroughMode(_ enabled: Bool) throws(DaveError) {
        try handle.withUnsafePointer { dec in
            daveDecryptorTransitionToPassthroughMode(dec, enabled)
        }
    }

    func maxPlaintextByteSize(
        encryptedFrameSize: Int,
        mediaType: DAVEMediaType = DAVE_MEDIA_TYPE_AUDIO
    ) throws(DaveError) -> Int {
        try handle.withUnsafePointer { dec in
            let cap = daveDecryptorGetMaxPlaintextByteSize(dec, mediaType, encryptedFrameSize)
            return try checkedInt(cap)
        }
    }

    func decrypt(
        encryptedFrame: [UInt8],
        mediaType: DAVEMediaType = DAVE_MEDIA_TYPE_AUDIO
    ) throws(DaveError) -> [UInt8] {
        try handle.withUnsafePointer { dec in
            let capacity = daveDecryptorGetMaxPlaintextByteSize(
                dec, mediaType, encryptedFrame.count)
            let capInt = try checkedInt(capacity)
            var output = [UInt8](repeating: 0, count: capInt)
            var bytesWritten: Int = 0

            let result = encryptedFrame.withUnsafeBufferPointer { inBuf in
                output.withUnsafeMutableBufferPointer { outBuf in
                    daveDecryptorDecrypt(
                        dec,
                        mediaType,
                        inBuf.baseAddress,
                        inBuf.count,
                        outBuf.baseAddress,
                        outBuf.count,
                        &bytesWritten
                    )
                }
            }

            try checkDecryptorResult(result)
            output.removeSubrange(bytesWritten..<capInt)
            return output
        }
    }
}
