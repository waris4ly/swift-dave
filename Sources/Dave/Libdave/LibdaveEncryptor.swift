import CLibDave

final class LibdaveEncryptor: Sendable {

    private let handle: NativeHandle<DAVEEncryptorHandle>

    init() throws(DaveError) {
        guard let raw = daveEncryptorCreate() else {
            throw .handleClosed
        }
        self.handle = NativeHandle(raw, destroy: daveEncryptorDestroy)
    }

    func close() {
        handle.close()
    }

    func setKeyRatchet(_ ratchet: (any KeyRatchetHandle)?) throws(DaveError) {
        try handle.withUnsafePointer { enc in
            if let libdaveRatchet = ratchet as? LibdaveKeyRatchet {
                try libdaveRatchet.withUnsafeHandle { r in
                    daveEncryptorSetKeyRatchet(enc, r)
                }
            } else if ratchet == nil {
                daveEncryptorSetKeyRatchet(enc, nil)
            } else {
                throw DaveError.invalidInput
            }
        }
    }

    func setPassthroughMode(_ enabled: Bool) throws(DaveError) {
        try handle.withUnsafePointer { enc in
            daveEncryptorSetPassthroughMode(enc, enabled)
        }
    }

    func assignSSRC(_ ssrc: UInt32, codec: DaveCodec) throws(DaveError) {
        try assignSSRC(ssrc, codec: codec.cCodec)
    }

    func assignSSRC(_ ssrc: UInt32, codec: DAVECodec = DAVE_CODEC_OPUS) throws(DaveError) {
        try handle.withUnsafePointer { enc in
            daveEncryptorAssignSsrcToCodec(enc, ssrc, codec)
        }
    }

    var protocolVersion: UInt16 {
        get throws(DaveError) {
            try handle.withUnsafePointer { daveEncryptorGetProtocolVersion($0) }
        }
    }

    var hasKeyRatchet: Bool {
        get throws(DaveError) {
            try handle.withUnsafePointer { daveEncryptorHasKeyRatchet($0) }
        }
    }

    var isPassthroughMode: Bool {
        get throws(DaveError) {
            try handle.withUnsafePointer { daveEncryptorIsPassthroughMode($0) }
        }
    }

    func maxCiphertextByteSize(
        frameSize: Int,
        mediaType: DAVEMediaType = DAVE_MEDIA_TYPE_AUDIO
    ) throws(DaveError) -> Int {
        try handle.withUnsafePointer { enc in
            let cap = daveEncryptorGetMaxCiphertextByteSize(enc, mediaType, frameSize)
            return try checkedInt(cap)
        }
    }

    func encrypt(
        ssrc: UInt32,
        frame: [UInt8],
        mediaType: DAVEMediaType = DAVE_MEDIA_TYPE_AUDIO
    ) throws(DaveError) -> [UInt8] {
        try handle.withUnsafePointer { enc in
            let capacity = daveEncryptorGetMaxCiphertextByteSize(enc, mediaType, frame.count)
            let capInt = try checkedInt(capacity)
            var output = [UInt8](repeating: 0, count: capInt)
            var bytesWritten: Int = 0

            let result = frame.withUnsafeBufferPointer { inBuf in
                output.withUnsafeMutableBufferPointer { outBuf in
                    daveEncryptorEncrypt(
                        enc,
                        mediaType,
                        ssrc,
                        inBuf.baseAddress,
                        inBuf.count,
                        outBuf.baseAddress,
                        outBuf.count,
                        &bytesWritten
                    )
                }
            }

            try checkEncryptorResult(result)
            output.removeSubrange(bytesWritten..<capInt)
            return output
        }
    }
}
