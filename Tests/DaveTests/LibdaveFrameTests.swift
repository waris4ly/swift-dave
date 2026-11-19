import CLibDave
import Testing

@testable import Dave

@Suite("LibdaveFrame Encryption and Decryption")
struct LibdaveFrameTests {

    @Test
    func passthroughModeRoundTripsPlaintext() throws {
        let encryptor = try LibdaveEncryptor()
        try encryptor.setPassthroughMode(true)
        try encryptor.assignSSRC(1, codec: DAVE_CODEC_OPUS)

        let decryptor = try LibdaveDecryptor()
        try decryptor.transitionToPassthroughMode(true)

        let plaintext = TestFrames.makeOpusFrame(size: 80, seed: 0x33)
        let encrypted = try encryptor.encrypt(ssrc: 1, frame: plaintext)
        #expect(encrypted == plaintext)

        let decrypted = try decryptor.decrypt(encryptedFrame: encrypted)
        #expect(decrypted == plaintext)
    }

    @Test
    func tamperedFrameFailsDecryption() throws {
        let group = try TestGroup(groupID: 123_456)
        let memberA = try group.addMember(userID: "1001")
        let memberB = try group.addMember(userID: "1002")
        try group.syncTwoPartyRatchets()

        let plaintext = TestFrames.makeOpusFrame(size: 80, seed: 0x44)
        var encrypted = try memberA.encryptor.encrypt(ssrc: 1, frame: plaintext)

        #expect(encrypted.count > 10)
        encrypted[10] ^= 0xFF

        #expect(throws: DaveError.self) {
            _ = try memberB.decryptor.decrypt(encryptedFrame: encrypted)
        }
    }

    @Test
    func silenceFramePassesThroughUndecrypted() throws {
        let group = try TestGroup(groupID: 123_457)
        _ = try group.addMember(userID: "2001")
        let memberB = try group.addMember(userID: "2002")
        try group.syncTwoPartyRatchets()

        let silence = TestFrames.silence
        let result = try memberB.decryptor.decrypt(encryptedFrame: silence)
        #expect(result == silence)
    }

    @Test
    func wrongUserFailsDecryption() throws {
        // group 1 with members A and B
        let group1 = try TestGroup(groupID: 123_458)
        let memberA = try group1.addMember(userID: "3001")
        _ = try group1.addMember(userID: "3002")
        try group1.syncTwoPartyRatchets()

        // group 2 with members C and D
        let group2 = try TestGroup(groupID: 123_459)
        _ = try group2.addMember(userID: "4001")
        let memberD = try group2.addMember(userID: "4002")
        try group2.syncTwoPartyRatchets()

        let plaintext = TestFrames.makeOpusFrame(size: 80, seed: 0x55)
        let encryptedByA = try memberA.encryptor.encrypt(ssrc: 1, frame: plaintext)

        // member D from group 2 attempting to decrypt frame from group 1 member A
        #expect(throws: DaveError.self) {
            _ = try memberD.decryptor.decrypt(encryptedFrame: encryptedByA)
        }
    }
}
