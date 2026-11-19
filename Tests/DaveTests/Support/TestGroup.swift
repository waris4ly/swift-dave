import CLibDave

@testable import Dave

final class TestMember {

    let userID: String
    let session: LibdaveSession
    let encryptor: LibdaveEncryptor
    let decryptor: LibdaveDecryptor

    init(userID: String) throws(DaveError) {
        self.userID = userID
        self.session = try LibdaveSession()
        self.encryptor = try LibdaveEncryptor()
        self.decryptor = try LibdaveDecryptor()
    }
}

final class TestGroup {

    let groupID: UInt64
    let sender: TestExternalSender
    private(set) var members: [TestMember]

    init(groupID: UInt64 = 100_001) throws(DaveError) {
        self.groupID = groupID
        self.sender = try TestExternalSender(groupID: groupID)
        self.members = []
    }

    func addMember(userID: String) throws(DaveError) -> TestMember {
        let member = try TestMember(userID: userID)
        let extPkg = sender.marshalledExternalSender()
        try member.session.setExternalSender(extPkg)
        try member.session.initialize(version: 1, groupID: groupID, selfUserID: userID)

        for existing in members {
            try member.session.addRecognizedUser(existing.userID)
            try existing.session.addRecognizedUser(userID)
        }

        if members.isEmpty {
            members.append(member)
            return member
        }

        let keyPackage = try member.session.marshalledKeyPackage()
        let epoch = UInt32(members.count - 1)
        let proposal = sender.proposeAdd(epoch: epoch, keyPackage: keyPackage)

        let commitWelcome = try members[0].session.processProposals(proposal)
        let (commit, welcome) = sender.splitCommitWelcome(commitWelcome)

        _ = try members[0].session.processCommit(commit)
        _ = try member.session.processWelcome(welcome)

        for other in members.dropFirst() {
            _ = try other.session.processCommit(commit)
        }

        members.append(member)
        return member
    }

    func syncTwoPartyRatchets() throws(DaveError) {
        guard members.count == 2 else { return }
        let a = members[0]
        let b = members[1]

        let ratchetA = try a.session.keyRatchet(for: a.userID)
        try a.encryptor.setKeyRatchet(ratchetA)
        try a.encryptor.setPassthroughMode(false)
        try a.encryptor.assignSSRC(1, codec: DAVE_CODEC_OPUS)

        let ratchetBForA = try b.session.keyRatchet(for: a.userID)
        try b.decryptor.transitionToKeyRatchet(ratchetBForA)
        try b.decryptor.transitionToPassthroughMode(false)

        let ratchetB = try b.session.keyRatchet(for: b.userID)
        try b.encryptor.setKeyRatchet(ratchetB)
        try b.encryptor.setPassthroughMode(false)
        try b.encryptor.assignSSRC(2, codec: DAVE_CODEC_OPUS)

        let ratchetAForB = try a.session.keyRatchet(for: b.userID)
        try a.decryptor.transitionToKeyRatchet(ratchetAForB)
        try a.decryptor.transitionToPassthroughMode(false)
    }
}
