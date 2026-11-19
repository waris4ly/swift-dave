import Testing

@testable import Dave

@Suite("NativeHandle Lifecycle")
struct NativeHandleTests {

    @Test
    func createAndUse() throws {
        var destroyed = false
        let raw = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        raw.pointee = 42

        let handle = NativeHandle(raw) { p in
            destroyed = true
            p.deallocate()
        }

        let readValue = try handle.withUnsafePointer { p in
            p.pointee
        }
        #expect(readValue == 42)
        #expect(!destroyed)

        handle.close()
        #expect(destroyed)
    }

    @Test
    func idempotentClose() {
        var destroyCount = 0
        let raw = UnsafeMutablePointer<Int>.allocate(capacity: 1)

        let handle = NativeHandle(raw) { p in
            destroyCount += 1
            p.deallocate()
        }

        handle.close()
        handle.close()
        handle.close()

        #expect(destroyCount == 1)
    }

    @Test
    func useAfterCloseThrows() {
        let raw = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        let handle = NativeHandle(raw) { p in
            p.deallocate()
        }

        handle.close()

        #expect(throws: DaveError.handleClosed) {
            try handle.withUnsafePointer { _ in
                0
            }
        }
    }

    @Test
    func deinitDestroysExactlyOnce() {
        var destroyCount = 0
        let raw = UnsafeMutablePointer<Int>.allocate(capacity: 1)

        do {
            let handle = NativeHandle(raw) { p in
                destroyCount += 1
                p.deallocate()
            }
            _ = handle
        }

        #expect(destroyCount == 1)
    }
}
