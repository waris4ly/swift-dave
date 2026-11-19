public protocol MLSEngine: Sendable {
    func initialize(version: UInt16, groupID: UInt64, selfUserID: String) throws(DaveError)
    func reset() throws(DaveError)
    func setProtocolVersion(_ version: UInt16) throws(DaveError)
    var protocolVersion: UInt16 { get throws(DaveError) }
    func setExternalSender(_ bytes: [UInt8]) throws(DaveError)
    func addRecognizedUser(_ userID: String) throws(DaveError)
    func removeRecognizedUser(_ userID: String) throws(DaveError)
    func processProposals(_ proposals: [UInt8]) throws(DaveError) -> [UInt8]
    func processCommit(_ commit: [UInt8]) throws(DaveError) -> CommitOutcome
    func processWelcome(_ welcome: [UInt8]) throws(DaveError)
    func marshalledKeyPackage() throws(DaveError) -> [UInt8]
    func getKeyRatchet(for userID: String) throws(DaveError) -> any KeyRatchetHandle
    func lastEpochAuthenticator() throws(DaveError) -> [UInt8]
    func pairwiseFingerprint(version: UInt16, userID: String) async throws(DaveError) -> [UInt8]
    func close()
}
