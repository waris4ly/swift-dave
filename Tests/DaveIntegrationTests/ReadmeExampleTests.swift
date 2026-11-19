import Testing

@testable import Dave

@Suite("Readme Example Snippet")
struct ReadmeExampleTests {

    @Test
    func readmeExampleCompilesAndRuns() async throws {
        // initialize a session for user and channel
        let session = try DaveSession(
            userID: 123_456_789,
            channelID: 987_654_321
        )

        // consume outgoing voice gateway messages in a background task
        let consumerTask = Task {
            for await message in await session.outgoing {
                switch message {
                case .keyPackage:
                    break
                case .commitAndWelcome:
                    break
                case .readyForTransition:
                    break
                case .invalidCommitWelcome:
                    break
                }
            }
        }

        // acknowledge protocol version when discord voice gateway connects
        try await session.acknowledgeProtocolVersion(.disabled)
        try await session.prepareTransition(transitionID: 0, protocolVersion: .disabled)
        try await session.executeTransition(transitionID: 0)

        // configure outgoing ssrc for audio
        try await session.assignSSRC(1001, codec: .opus)

        // encrypt audio frame
        guard await session.isReady else {
            return
        }

        let audioFrame = [UInt8](repeating: 0x42, count: 80)
        let encrypted = try await session.encrypt(frame: audioFrame, ssrc: 1001)
        #expect(!encrypted.isEmpty)

        // decrypt incoming audio frames from remote users
        try await session.addUser(userID: 222_333_444)
        let decrypted = try await session.decrypt(frame: encrypted, userID: 222_333_444)
        #expect(decrypted == audioFrame)

        await session.close()
        consumerTask.cancel()
    }
}
