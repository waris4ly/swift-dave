struct UserRegistry: Sendable {

    private let decryptorFactory: @Sendable () throws(DaveError) -> any FrameDecryptor
    private var decryptors: [UInt64: any FrameDecryptor] = [:]

    init(decryptorFactory: @escaping @Sendable () throws(DaveError) -> any FrameDecryptor) {
        self.decryptorFactory = decryptorFactory
    }

    mutating func addUser(_ id: UInt64) throws(DaveError) -> any FrameDecryptor {
        if let existing = decryptors[id] {
            return existing
        }
        let decryptor = try decryptorFactory()
        decryptors[id] = decryptor
        return decryptor
    }

    mutating func removeUser(_ id: UInt64) {
        if let old = decryptors.removeValue(forKey: id) {
            old.close()
        }
    }

    func decryptor(for id: UInt64) -> (any FrameDecryptor)? {
        decryptors[id]
    }

    var recognizedUserIDs: [UInt64] {
        Array(decryptors.keys)
    }

    func updateKeyRatchets(
        using getRatchet: (UInt64) throws(DaveError) -> (any KeyRatchetHandle)?
    ) throws(DaveError) {
        for (id, dec) in decryptors {
            let ratchet = try getRatchet(id)
            try dec.transitionToKeyRatchet(ratchet)
        }
    }

    func setPassthroughMode(_ enabled: Bool) throws(DaveError) {
        for dec in decryptors.values {
            try dec.transitionToPassthroughMode(enabled)
        }
    }

    mutating func closeAll() {
        for dec in decryptors.values {
            dec.close()
        }
        decryptors.removeAll()
    }
}
