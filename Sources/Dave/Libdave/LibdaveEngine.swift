import CLibDave

extension DaveCodec {
    var cCodec: DAVECodec {
        switch self {
        case .opus: return DAVE_CODEC_OPUS
        case .vp8: return DAVE_CODEC_VP8
        case .vp9: return DAVE_CODEC_VP9
        case .h264: return DAVE_CODEC_H264
        case .h265: return DAVE_CODEC_H265
        case .av1: return DAVE_CODEC_AV1
        }
    }
}

extension LibdaveEncryptor: FrameEncryptor {
    func encrypt(ssrc: UInt32, frame: [UInt8]) throws(DaveError) -> [UInt8] {
        try encrypt(ssrc: ssrc, frame: frame, mediaType: DAVE_MEDIA_TYPE_AUDIO)
    }
}

extension LibdaveDecryptor: FrameDecryptor {
    func decrypt(encryptedFrame: [UInt8]) throws(DaveError) -> [UInt8] {
        try decrypt(encryptedFrame: encryptedFrame, mediaType: DAVE_MEDIA_TYPE_AUDIO)
    }
}

extension LibdaveSession: MLSEngine {
    func getKeyRatchet(for userID: String) throws(DaveError) -> any KeyRatchetHandle {
        try keyRatchet(for: userID)
    }
}
