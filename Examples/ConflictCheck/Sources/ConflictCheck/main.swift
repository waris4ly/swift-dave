import Crypto
import Dave
import NIOSSL

// 1. Verify swift-crypto works in this binary
let cryptoDigest = SHA256.hash(data: [0x61, 0x62, 0x63])
assert(cryptoDigest.withUnsafeBytes { $0.count } == 32)

// 2. Verify swift-nio-ssl initializes
let tlsConfiguration = TLSConfiguration.makeClientConfiguration()
assert(tlsConfiguration.minimumTLSVersion == .tlsv1)

// 3. Verify swift-dave runs and calls libdave
let maxVersion = daveMaxSupportedProtocolVersion()
assert(maxVersion > 0)

// 4. Verify libdave session lifecycle in this binary
let session = daveSessionCreate(nil, "conflict-check", nil, nil)
assert(session != nil)
daveSessionDestroy(session)
