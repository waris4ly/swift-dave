import CBoringSSL
import Testing

@Suite("BoringSSL Link")
struct BoringSSLLinkTests {

    @Test func sha256OfAbcMatchesKnownVector() {
        let input: [UInt8] = [0x61, 0x62, 0x63]  // "abc"
        var digest = [UInt8](repeating: 0, count: 32)

        _ = input.withUnsafeBufferPointer { inputBuffer in
            digest.withUnsafeMutableBufferPointer { digestBuffer in
                CCryptoBoringSSL_SHA256(
                    inputBuffer.baseAddress,
                    inputBuffer.count,
                    digestBuffer.baseAddress
                )
            }
        }

        let expected: [UInt8] = [
            0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
            0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
            0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
            0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad,
        ]

        #expect(digest == expected)
    }
}
