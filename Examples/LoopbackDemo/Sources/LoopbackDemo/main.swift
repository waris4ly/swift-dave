import Dave

let userA: UInt64 = 1_001
let userB: UInt64 = 2_002
let channelID: UInt64 = 55_555

let sessionA = try DaveSession(userID: userA, channelID: channelID)
let sessionB = try DaveSession(userID: userB, channelID: channelID)

// gateway sends protocol version 0 (e2ee disabled)
try await sessionA.acknowledgeProtocolVersion(.disabled)
try await sessionB.acknowledgeProtocolVersion(.disabled)

// both sessions execute transition 0 to disabled passthrough
try await sessionA.prepareTransition(transitionID: 0, protocolVersion: .disabled)
try await sessionA.executeTransition(transitionID: 0)

try await sessionB.prepareTransition(transitionID: 0, protocolVersion: .disabled)
try await sessionB.executeTransition(transitionID: 0)

try await sessionA.addUser(userID: userB)
try await sessionB.addUser(userID: userA)

try await sessionA.assignSSRC(11, codec: .opus)
try await sessionB.assignSSRC(22, codec: .opus)

// both sessions are ready under the hold rule
let readyA = await sessionA.isReady
let readyB = await sessionB.isReady
assert(readyA)
assert(readyB)

// loopback opus audio frame from user A to user B
let audioFrame = [UInt8](repeating: 0x42, count: 80)
let encryptedA = try await sessionA.encrypt(frame: audioFrame, ssrc: 11)
let decryptedB = try await sessionB.decrypt(frame: encryptedA, userID: userA)
assert(decryptedB == audioFrame)

// loopback opus audio frame from user B to user A
let replyFrame = [UInt8](repeating: 0x99, count: 80)
let encryptedB = try await sessionB.encrypt(frame: replyFrame, ssrc: 22)
let decryptedA = try await sessionA.decrypt(frame: encryptedB, userID: userB)
assert(decryptedA == replyFrame)

await sessionA.close()
await sessionB.close()
