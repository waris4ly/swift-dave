import Testing

@testable import Dave

@Suite("LibdaveSession Two-Party Loopback")
struct LibdaveSessionTests {

    @Test
    func twoPartyNegotiationAndLoopback() async throws {
        let group = try TestGroup(groupID: 888_888)
        let memberA = try group.addMember(userID: "1111222233334444")
        let memberB = try group.addMember(userID: "5555666677778888")

        // epoch authenticators match
        let authA = try memberA.session.lastEpochAuthenticator()
        let authB = try memberB.session.lastEpochAuthenticator()
        #expect(!authA.isEmpty)
        #expect(authA == authB)

        // pairwise fingerprints match
        let fpA = try await memberA.session.pairwiseFingerprint(version: 1, userID: memberB.userID)
        let fpB = try await memberB.session.pairwiseFingerprint(version: 1, userID: memberA.userID)
        #expect(!fpA.isEmpty)
        #expect(fpA == fpB)

        // set up ratchets for bidirectional audio
        try group.syncTwoPartyRatchets()

        // audio: A -> B
        let plaintextFromA = TestFrames.makeOpusFrame(size: 80, seed: 0x11)
        let encryptedFromA = try memberA.encryptor.encrypt(
            ssrc: 1,
            frame: plaintextFromA
        )
        #expect(encryptedFromA != plaintextFromA)
        #expect(encryptedFromA.count > plaintextFromA.count)

        let decryptedByB = try memberB.decryptor.decrypt(encryptedFrame: encryptedFromA)
        #expect(decryptedByB == plaintextFromA)

        // audio: B -> A
        let plaintextFromB = TestFrames.makeOpusFrame(size: 96, seed: 0x22)
        let encryptedFromB = try memberB.encryptor.encrypt(
            ssrc: 2,
            frame: plaintextFromB
        )
        #expect(encryptedFromB != plaintextFromB)

        let decryptedByA = try memberA.decryptor.decrypt(encryptedFrame: encryptedFromB)
        #expect(decryptedByA == plaintextFromB)
    }

    @Test
    func sessionCloseInvalidatesCalls() throws {
        let session = try LibdaveSession()
        session.close()

        #expect(throws: DaveError.handleClosed) {
            _ = try session.protocolVersion
        }
    }

    @Test
    func commitAndWelcomeRosterResults() throws {
        let sender = try TestExternalSender(groupID: 999_999)
        let sessionA = try LibdaveSession()
        let sessionB = try LibdaveSession()

        let ext = sender.marshalledExternalSender()
        try sessionA.setExternalSender(ext)
        try sessionB.setExternalSender(ext)

        let userA = "1234123412341234"
        let userB = "5678567856785678"

        try sessionA.initialize(version: 1, groupID: 999_999, selfUserID: userA)
        try sessionB.initialize(version: 1, groupID: 999_999, selfUserID: userB)

        try sessionA.addRecognizedUser(userB)
        try sessionB.addRecognizedUser(userA)

        let keyPackageB = try sessionB.marshalledKeyPackage()
        let proposal = sender.proposeAdd(epoch: 0, keyPackage: keyPackageB)

        let commitWelcome = try sessionA.processProposals(proposal)
        let (commit, welcome) = sender.splitCommitWelcome(commitWelcome)

        let commitResult = try sessionA.processCommitResult(commit)
        let isFailed = try commitResult.isFailed
        let isIgnored = try commitResult.isIgnored
        #expect(!isFailed)
        #expect(!isIgnored)

        let commitRoster = try commitResult.rosterMemberIDs()
        #expect(commitRoster.count == 2)
        let sigA = try commitResult.rosterMemberSignature(rosterID: 1_234_123_412_341_234)
        #expect(!sigA.isEmpty)

        let welcomeResult = try sessionB.processWelcomeResult(welcome)
        let welcomeRoster = try welcomeResult.rosterMemberIDs()
        #expect(welcomeRoster.count == 2)
        let sigB = try welcomeResult.rosterMemberSignature(rosterID: 5_678_567_856_785_678)
        #expect(!sigB.isEmpty)
    }
}
