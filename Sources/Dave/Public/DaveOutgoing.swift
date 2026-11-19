public enum DaveOutgoing: Sendable, Equatable {
    case keyPackage([UInt8])
    case commitAndWelcome([UInt8])
    case readyForTransition(transitionID: UInt64)
    case invalidCommitWelcome(transitionID: UInt64)
}
