import CLibDave
import Testing

@Suite("Libdave Smoke")
struct LibdaveSmokeTests {

    @Test func maxSupportedProtocolVersionIsGreaterThanZero() {
        let version = daveMaxSupportedProtocolVersion()
        #expect(version > 0)
    }

    @Test func sessionCreateAndDestroy() throws {
        for _ in 0..<200 {
            let session = try #require(daveSessionCreate(nil, "smoke-test", nil, nil))
            daveSessionDestroy(session)
        }
    }

    @Test func encryptorCreateAndDestroy() throws {
        for _ in 0..<200 {
            let encryptor = try #require(daveEncryptorCreate())
            daveEncryptorDestroy(encryptor)
        }
    }

    @Test func decryptorCreateAndDestroy() throws {
        for _ in 0..<200 {
            let decryptor = try #require(daveDecryptorCreate())
            daveDecryptorDestroy(decryptor)
        }
    }
}
