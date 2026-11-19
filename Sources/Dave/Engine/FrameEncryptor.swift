public protocol FrameEncryptor: Sendable {
    func setKeyRatchet(_ ratchet: (any KeyRatchetHandle)?) throws(DaveError)
    func setPassthroughMode(_ enabled: Bool) throws(DaveError)
    func assignSSRC(_ ssrc: UInt32, codec: DaveCodec) throws(DaveError)
    var hasKeyRatchet: Bool { get throws(DaveError) }
    var isPassthroughMode: Bool { get throws(DaveError) }
    func encrypt(ssrc: UInt32, frame: [UInt8]) throws(DaveError) -> [UInt8]
    func close()
}
