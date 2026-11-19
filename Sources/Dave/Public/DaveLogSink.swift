public enum DaveLogLevel: Int, Sendable, Equatable, Comparable {
    case verbose = 0
    case info = 1
    case warning = 2
    case error = 3

    public static func < (lhs: DaveLogLevel, rhs: DaveLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public typealias DaveLogSink =
    @Sendable (
        _ level: DaveLogLevel,
        _ file: String,
        _ line: Int,
        _ message: String
    ) -> Void
