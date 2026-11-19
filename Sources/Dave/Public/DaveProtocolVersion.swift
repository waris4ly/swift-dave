import CLibDave

public struct DaveProtocolVersion: RawRepresentable, Sendable, Equatable, Hashable, Comparable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let disabled = DaveProtocolVersion(rawValue: 0)
    public static let v1 = DaveProtocolVersion(rawValue: 1)

    public static func < (lhs: DaveProtocolVersion, rhs: DaveProtocolVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static var maxSupported: DaveProtocolVersion {
        DaveProtocolVersion(rawValue: daveMaxSupportedProtocolVersion())
    }
}
