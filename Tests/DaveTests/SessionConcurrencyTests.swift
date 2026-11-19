import Testing

@testable import Dave

@Suite("DaveSession Concurrency Stress")
struct DaveSessionConcurrencyTests {

    @Test
    func concurrentAccessUnderTaskGroup() async throws {
        let engine = MockEngine()
        let encryptor = MockFrameEncryptor()
        let session = DaveSession(
            userID: 9999,
            channelID: 8888,
            engine: engine,
            encryptor: encryptor,
            decryptorFactory: { MockFrameDecryptor() }
        )

        try await session.acknowledgeProtocolVersion(.v1)
        try await session.prepareTransition(transitionID: 0, protocolVersion: .v1)
        try await session.addUser(userID: 1111)
        try await session.addUser(userID: 2222)
        try await session.assignSSRC(101, codec: .opus)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    for _ in 0..<50 {
                        _ = await session.isReady
                    }
                }
            }

            for i in 0..<5 {
                group.addTask {
                    let frame = [UInt8](repeating: UInt8(i), count: 32)
                    for _ in 0..<50 {
                        // concurrent transitions may temporarily throw not ready
                        _ = try? await session.encrypt(frame: frame, ssrc: 101)
                    }
                }
            }

            for i in 0..<5 {
                group.addTask {
                    let frame = [UInt8](repeating: UInt8(i + 10), count: 32)
                    for _ in 0..<50 {
                        // concurrent removals may cause user lookups to throw
                        _ = try? await session.decrypt(frame: frame, userID: 1111)
                    }
                }
            }

            group.addTask {
                for u in 3000..<3030 {
                    // concurrent user modifications intentionally ignore duplicate/transient errors
                    _ = try? await session.addUser(userID: UInt64(u))
                    _ = try? await session.removeUser(userID: UInt64(u))
                }
            }
        }

        await session.close()
    }
}
