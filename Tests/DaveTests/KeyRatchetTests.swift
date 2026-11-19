import CLibDave
import Testing

@testable import Dave

@Suite("KeyRatchet Lifecycle and Transitions")
struct KeyRatchetTests {

    @Test
    func creationAndTeardown() throws {
        let group = try TestGroup(groupID: 555_001)
        let memberA = try group.addMember(userID: "5001")
        _ = try group.addMember(userID: "5002")

        let ratchet = try memberA.session.keyRatchet(for: memberA.userID)
        ratchet.close()
        ratchet.close()

        #expect(throws: DaveError.handleClosed) {
            try ratchet.withUnsafeHandle { _ in 0 }
        }
    }

    @Test
    func sequentialGenerationsAdvanceSmoothly() throws {
        let group = try TestGroup(groupID: 555_002)
        let memberA = try group.addMember(userID: "6001")
        let memberB = try group.addMember(userID: "6002")
        try group.syncTwoPartyRatchets()

        // encrypt and decrypt 25 consecutive frames to advance nonces
        for i in 0..<25 {
            let plaintext = TestFrames.makeOpusFrame(size: 80, seed: UInt8(i & 0xFF))
            let encrypted = try memberA.encryptor.encrypt(ssrc: 1, frame: plaintext)
            let decrypted = try memberB.decryptor.decrypt(encryptedFrame: encrypted)
            #expect(decrypted == plaintext)
        }
    }

    @Test
    func ratchetTransitionToNilDisablesEncryption() throws {
        let group = try TestGroup(groupID: 555_003)
        let memberA = try group.addMember(userID: "7001")
        _ = try group.addMember(userID: "7002")
        try group.syncTwoPartyRatchets()

        let hasRatchetInitial = try memberA.encryptor.hasKeyRatchet
        #expect(hasRatchetInitial)

        try memberA.encryptor.setKeyRatchet(nil)
        let hasRatchetAfterNil = try memberA.encryptor.hasKeyRatchet
        #expect(!hasRatchetAfterNil)
    }
}
