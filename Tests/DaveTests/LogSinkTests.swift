import Testing
import os

@testable import Dave

@Suite("LogSink Bridge", .serialized)
struct LogSinkTests {

    @Test
    func logSinkReceivesMessages() throws {
        let messages = OSAllocatedUnfairLock(initialState: [String]())

        setDaveLogSink { _, _, _, message in
            messages.withLock { $0.append(message) }
        }

        // creating a session produces info logs in libdave
        let session = try LibdaveSession()
        session.close()

        setDaveLogSink(nil)

        let captured = messages.withLock { $0 }
        #expect(!captured.isEmpty)
    }

    @Test
    func replacingLogSinkDoesNotCrash() throws {
        let countA = OSAllocatedUnfairLock(initialState: 0)
        let countB = OSAllocatedUnfairLock(initialState: 0)

        setDaveLogSink { _, _, _, _ in
            countA.withLock { $0 += 1 }
        }
        let session1 = try LibdaveSession()
        session1.close()

        setDaveLogSink { _, _, _, _ in
            countB.withLock { $0 += 1 }
        }
        let session2 = try LibdaveSession()
        session2.close()

        setDaveLogSink(nil)
        let session3 = try LibdaveSession()
        session3.close()

        #expect(countA.withLock { $0 } > 0)
        #expect(countB.withLock { $0 } > 0)
    }
}
