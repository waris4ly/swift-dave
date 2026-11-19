import Testing

@testable import Dave

@Suite("DaveSession Real Libdave Integration")
struct DaveSessionIntegrationTests {

    @Test
    func twoPartyLoopbackViaPublicSessionAPI() async throws {
        let channelID: UInt64 = 888_001
        let userA: UInt64 = 1_000_001
        let userB: UInt64 = 1_000_002

        let sessionA = try DaveSession(userID: userA, channelID: channelID)
        let sessionB = try DaveSession(userID: userB, channelID: channelID)

        let sender = try TestExternalSender(groupID: channelID)
        let extData = sender.marshalledExternalSender()

        try await sessionA.setExternalSender(extData)
        try await sessionB.setExternalSender(extData)

        try await sessionA.addUser(userID: userB)
        try await sessionB.addUser(userID: userA)

        let streamA = await sessionA.outgoing
        var iterA = streamA.makeAsyncIterator()

        let streamB = await sessionB.outgoing
        var iterB = streamB.makeAsyncIterator()

        try await sessionA.acknowledgeProtocolVersion(.v1)
        _ = await iterA.next()

        try await sessionB.acknowledgeProtocolVersion(.v1)
        let keyPkgBMsg = await iterB.next()
        let keyPkgB: [UInt8]
        guard case .keyPackage(let bytes) = keyPkgBMsg else {
            Issue.record("Expected key package from session B")
            return
        }
        keyPkgB = bytes

        let proposal = sender.proposeAdd(epoch: 0, keyPackage: keyPkgB)
        try await sessionA.processProposals(proposal)

        let commitWelcomeMsg = await iterA.next()
        let commitWelcomeBytes: [UInt8]
        guard case .commitAndWelcome(let bytes) = commitWelcomeMsg else {
            Issue.record("Expected commit and welcome from session A")
            return
        }
        commitWelcomeBytes = bytes

        let (commit, welcome) = sender.splitCommitWelcome(commitWelcomeBytes)

        try await sessionA.announceCommitTransition(transitionID: 1, commit: commit)
        try await sessionA.prepareTransition(transitionID: 1, protocolVersion: .v1)
        let readyA = await iterA.next()
        #expect(readyA == .readyForTransition(transitionID: 1))
        try await sessionA.executeTransition(transitionID: 1)

        try await sessionB.processWelcome(transitionID: 1, welcome: welcome)
        try await sessionB.prepareTransition(transitionID: 1, protocolVersion: .v1)
        let readyB = await iterB.next()
        #expect(readyB == .readyForTransition(transitionID: 1))
        try await sessionB.executeTransition(transitionID: 1)

        #expect(await sessionA.isReady)
        #expect(await sessionB.isReady)

        try await sessionA.assignSSRC(11, codec: .opus)
        try await sessionB.assignSSRC(22, codec: .opus)

        let plainAtoB: [UInt8] = [0xF8, 0xFF, 0xFE, 0x01, 0x02, 0x03, 0x04, 0x05]
        let cipherA = try await sessionA.encrypt(frame: plainAtoB, ssrc: 11)
        let decryptedB = try await sessionB.decrypt(frame: cipherA, userID: userA)
        #expect(decryptedB == plainAtoB)

        let plainBtoA: [UInt8] = [0xF8, 0xFF, 0xFE, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE]
        let cipherB = try await sessionB.encrypt(frame: plainBtoA, ssrc: 22)
        let decryptedA = try await sessionA.decrypt(frame: cipherB, userID: userB)
        #expect(decryptedA == plainBtoA)

        let authA = try await sessionA.lastEpochAuthenticator()
        let authB = try await sessionB.lastEpochAuthenticator()
        #expect(!authA.isEmpty)
        #expect(authA == authB)

        let fpA = try await sessionA.pairwiseFingerprint(version: .v1, userID: userB)
        let fpB = try await sessionB.pairwiseFingerprint(version: .v1, userID: userA)
        #expect(!fpA.isEmpty)
        #expect(fpA == fpB)

        await sessionA.close()
        await sessionB.close()
    }
}
