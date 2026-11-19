import Testing

@testable import Dave

@Suite("DaveSession State Machine Scenarios")
struct DaveSessionStateMachineTests {

    private func makeSession(
        userID: UInt64 = 1001,
        channelID: UInt64 = 2001
    ) -> (DaveSession, MockEngine, MockFrameEncryptor) {
        let engine = MockEngine()
        let encryptor = MockFrameEncryptor()
        let session = DaveSession(
            userID: userID,
            channelID: channelID,
            engine: engine,
            encryptor: encryptor,
            decryptorFactory: { MockFrameDecryptor() }
        )
        return (session, engine, encryptor)
    }

    @Test
    func firstJoinLifecycle() async throws {
        let (session, _, encryptor) = makeSession()

        var ready = await session.isReady
        #expect(!ready)

        let stream = await session.outgoing
        var iterator = stream.makeAsyncIterator()

        try await session.acknowledgeProtocolVersion(.v1)
        let msg1 = await iterator.next()
        #expect(msg1 == .keyPackage([0xDE, 0xAD, 0xBE, 0xEF]))

        try await session.prepareTransition(transitionID: 0, protocolVersion: .v1)
        ready = await session.isReady
        #expect(ready)
        #expect(encryptor.hasKeyRatchet)
        #expect(!encryptor.isPassthroughMode)

        try await session.assignSSRC(42, codec: .opus)
        let plaintext: [UInt8] = [1, 2, 3, 4]
        let ciphertext = try await session.encrypt(frame: plaintext, ssrc: 42)
        #expect(ciphertext == plaintext.map { $0 ^ 0xAA })
    }

    @Test
    func secondUserJoinsAndLeaves() async throws {
        let (session, engine, _) = makeSession()
        let stream = await session.outgoing
        var iterator = stream.makeAsyncIterator()

        try await session.acknowledgeProtocolVersion(.v1)
        _ = await iterator.next()

        try await session.addUser(userID: 2002)
        #expect(engine.recognizedUsers.contains("2002"))

        engine.setProposalsResponse([0xAA, 0xBB])
        try await session.processProposals([0x11, 0x22])
        let commitWelcomeMsg = await iterator.next()
        #expect(commitWelcomeMsg == .commitAndWelcome([0xAA, 0xBB]))

        engine.setCommitOutcome(.ok)
        try await session.announceCommitTransition(transitionID: 1, commit: [0xAA])
        try await session.prepareTransition(transitionID: 1, protocolVersion: .v1)

        let readyMsg = await iterator.next()
        #expect(readyMsg == .readyForTransition(transitionID: 1))

        try await session.executeTransition(transitionID: 1)
        let isReady = await session.isReady
        #expect(isReady)

        let encryptedFrame: [UInt8] = [10, 20, 30]
        let decrypted = try await session.decrypt(frame: encryptedFrame, userID: 2002)
        #expect(decrypted == encryptedFrame.map { $0 ^ 0xAA })

        try await session.removeUser(userID: 2002)
        #expect(!engine.recognizedUsers.contains("2002"))

        await #expect(throws: DaveError.unknownUser) {
            _ = try await session.decrypt(frame: encryptedFrame, userID: 2002)
        }
    }

    @Test
    func welcomeProcessingFlow() async throws {
        let (session, _, _) = makeSession()
        let stream = await session.outgoing
        var iterator = stream.makeAsyncIterator()

        try await session.acknowledgeProtocolVersion(.v1)
        _ = await iterator.next()

        try await session.addUser(userID: 3003)

        try await session.processWelcome(transitionID: 5, welcome: [0x55, 0x66])
        try await session.prepareTransition(transitionID: 5, protocolVersion: .v1)

        let readyMsg = await iterator.next()
        #expect(readyMsg == .readyForTransition(transitionID: 5))

        try await session.executeTransition(transitionID: 5)
        let ready = await session.isReady
        #expect(ready)
    }

    @Test
    func downgradeToVersionZero() async throws {
        let (session, engine, encryptor) = makeSession()
        let stream = await session.outgoing
        var iterator = stream.makeAsyncIterator()

        try await session.acknowledgeProtocolVersion(.v1)
        _ = await iterator.next()
        try await session.prepareTransition(transitionID: 0, protocolVersion: .v1)
        #expect(await session.isReady)

        try await session.prepareTransition(transitionID: 10, protocolVersion: .disabled)
        let readyMsg = await iterator.next()
        #expect(readyMsg == .readyForTransition(transitionID: 10))

        try await session.executeTransition(transitionID: 10)
        #expect(engine.isReset)
        #expect(encryptor.isPassthroughMode)
        #expect(!encryptor.hasKeyRatchet)
        // in version 0 passthrough mode is active, isReady is true
        #expect(await session.isReady)
    }

    @Test
    func epochChangeBookkeeping() async throws {
        let (session, _, _) = makeSession()
        let stream = await session.outgoing
        var iterator = stream.makeAsyncIterator()

        // epoch 1 triggers a fresh key package
        try await session.prepareEpoch(1, protocolVersion: .v1)
        let msg = await iterator.next()
        #expect(msg == .keyPackage([0xDE, 0xAD, 0xBE, 0xEF]))

        // subsequent epochs are bookkeeping only
        try await session.prepareEpoch(2, protocolVersion: .v1)
        try await session.prepareEpoch(3, protocolVersion: .v1)
    }

    @Test
    func invalidCommitTriggersRecovery() async throws {
        let (session, engine, _) = makeSession()
        let stream = await session.outgoing
        var iterator = stream.makeAsyncIterator()

        try await session.acknowledgeProtocolVersion(.v1)
        _ = await iterator.next()

        engine.setCommitOutcome(.failed)
        engine.setKeyPackageBytes([0x11, 0x22, 0x33, 0x44])
        try await session.announceCommitTransition(transitionID: 99, commit: [0xFF])

        let invalidMsg = await iterator.next()
        #expect(invalidMsg == .invalidCommitWelcome(transitionID: 99))

        let freshKeyPkgMsg = await iterator.next()
        #expect(freshKeyPkgMsg == .keyPackage([0x11, 0x22, 0x33, 0x44]))
        #expect(engine.isReset)
    }

    @Test
    func welcomeFailureTriggersRecovery() async throws {
        let (session, engine, _) = makeSession()
        let stream = await session.outgoing
        var iterator = stream.makeAsyncIterator()

        try await session.acknowledgeProtocolVersion(.v1)
        _ = await iterator.next()

        engine.setWelcomeShouldThrow(true)
        engine.setKeyPackageBytes([0x99, 0x88])
        try await session.processWelcome(transitionID: 77, welcome: [0x00])

        let invalidMsg = await iterator.next()
        #expect(invalidMsg == .invalidCommitWelcome(transitionID: 77))

        let freshKeyPkgMsg = await iterator.next()
        #expect(freshKeyPkgMsg == .keyPackage([0x99, 0x88]))
        #expect(engine.isReset)
    }

    @Test
    func unknownTransitionIDThrows() async throws {
        let (session, _, _) = makeSession()
        await #expect(throws: DaveError.unknownTransition) {
            try await session.executeTransition(transitionID: 999_999)
        }
    }

    @Test
    func isReadyAndHoldRule() async throws {
        let (session, _, _) = makeSession()

        // not ready: encrypt must throw notReady
        await #expect(throws: DaveError.notReady) {
            _ = try await session.encrypt(frame: [1, 2, 3], ssrc: 1)
        }

        try await session.acknowledgeProtocolVersion(.v1)
        try await session.prepareTransition(transitionID: 0, protocolVersion: .v1)
        #expect(await session.isReady)

        let encrypted = try await session.encrypt(frame: [1, 2, 3], ssrc: 1)
        #expect(!encrypted.isEmpty)
    }

    @Test
    func eventsAfterCloseThrow() async throws {
        let (session, _, _) = makeSession()
        await session.close()
        await session.close()

        await #expect(throws: DaveError.handleClosed) {
            try await session.acknowledgeProtocolVersion(.v1)
        }
        await #expect(throws: DaveError.handleClosed) {
            try await session.prepareEpoch(1, protocolVersion: .v1)
        }
        await #expect(throws: DaveError.handleClosed) {
            try await session.setExternalSender([1])
        }
        await #expect(throws: DaveError.handleClosed) {
            try await session.processProposals([1])
        }
        await #expect(throws: DaveError.handleClosed) {
            try await session.announceCommitTransition(transitionID: 1, commit: [1])
        }
        await #expect(throws: DaveError.handleClosed) {
            try await session.processWelcome(transitionID: 1, welcome: [1])
        }
        await #expect(throws: DaveError.handleClosed) {
            try await session.prepareTransition(transitionID: 1, protocolVersion: .v1)
        }
        await #expect(throws: DaveError.handleClosed) {
            try await session.executeTransition(transitionID: 1)
        }
        await #expect(throws: DaveError.handleClosed) {
            try await session.addUser(userID: 1)
        }
        await #expect(throws: DaveError.handleClosed) {
            try await session.removeUser(userID: 1)
        }
        await #expect(throws: DaveError.handleClosed) {
            try await session.assignSSRC(1)
        }
        await #expect(throws: DaveError.handleClosed) {
            _ = try await session.encrypt(frame: [1], ssrc: 1)
        }
        await #expect(throws: DaveError.handleClosed) {
            _ = try await session.decrypt(frame: [1], userID: 1)
        }
    }
}
