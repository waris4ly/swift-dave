public enum DaveError: Error, Sendable, Equatable {
    case handleClosed
    case encryptionFailure
    case decryptionFailure
    case missingKeyRatchet
    case missingCryptor
    case tooManyAttempts
    case invalidNonce
    case commitFailed
    case commitIgnored
    case mlsFailure(source: String, reason: String)
    case bufferTooSmall
    case invalidInput
    case integerOverflow
    case unknownResultCode(Int)
    case notReady
    case unknownUser
    case unknownTransition
}
