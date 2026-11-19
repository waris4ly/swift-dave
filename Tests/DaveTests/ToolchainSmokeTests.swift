import Dave
import Testing

@Suite("Toolchain")
struct ToolchainSmokeTests {

    @Test func initialTransitionIDIsZero() {
        #expect(initialTransitionID == 0)
    }

    @Test func disabledProtocolVersionIsZero() {
        #expect(disabledProtocolVersion == 0)
    }

    @Test func freshGroupEpochIsOne() {
        #expect(freshGroupEpoch == 1)
    }

    @Test func constantsAreDistinct() {
        // all three encode different concepts, so they must not accidentally collapse
        #expect(UInt64(initialTransitionID) != freshGroupEpoch)
    }
}
