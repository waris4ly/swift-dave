public enum DaveCodec: Sendable, Equatable {
    case opus
    case vp8
    case vp9
    case h264
    case h265
    case av1
}

public struct DaveConfiguration: Sendable, Equatable {
    public var authSessionID: String?

    public init(authSessionID: String? = nil) {
        self.authSessionID = authSessionID
    }
}
