struct TransitionTracker: Sendable {

    private var preparedTransitions: [UInt64: DaveProtocolVersion] = [:]

    mutating func prepare(transitionID: UInt64, version: DaveProtocolVersion) {
        preparedTransitions[transitionID] = version
    }

    mutating func consume(transitionID: UInt64) -> DaveProtocolVersion? {
        preparedTransitions.removeValue(forKey: transitionID)
    }

    func version(for transitionID: UInt64) -> DaveProtocolVersion? {
        preparedTransitions[transitionID]
    }

    func isPrepared(transitionID: UInt64) -> Bool {
        preparedTransitions[transitionID] != nil
    }

    mutating func clear() {
        preparedTransitions.removeAll()
    }
}
