enum TestFrames {

    static let silence: [UInt8] = [0xF8, 0xFF, 0xFE]

    static func makeOpusFrame(size: Int = 80, seed: UInt8 = 0x42) -> [UInt8] {
        var frame = [UInt8](repeating: 0, count: size)
        for i in 0..<size {
            frame[i] = UInt8((Int(seed) + i * 31) & 0xFF)
        }
        return frame
    }

    static func makeVideoFrame(size: Int = 1024, seed: UInt8 = 0xAA) -> [UInt8] {
        var frame = [UInt8](repeating: 0, count: size)
        for i in 0..<size {
            frame[i] = UInt8((Int(seed) + i * 17) & 0xFF)
        }
        return frame
    }
}
