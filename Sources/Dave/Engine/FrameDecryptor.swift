public protocol FrameDecryptor: Sendable {
    func transitionToKeyRatchet(_ ratchet: (any KeyRatchetHandle)?) throws(DaveError)
    func transitionToPassthroughMode(_ enabled: Bool) throws(DaveError)
    func decrypt(encryptedFrame: [UInt8]) throws(DaveError) -> [UInt8]
    func close()
}
