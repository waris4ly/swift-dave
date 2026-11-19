import CLibDave

func copyAndFreeBytes(pointer: UnsafeMutablePointer<UInt8>?, count: Int) -> [UInt8] {
    guard let pointer, count > 0 else {
        if let pointer {
            daveFree(pointer)
        }
        return []
    }
    defer { daveFree(pointer) }
    return Array(UnsafeBufferPointer(start: pointer, count: count))
}

func copyAndFreeUInt64Array(pointer: UnsafeMutablePointer<UInt64>?, count: Int) -> [UInt64] {
    guard let pointer, count > 0 else {
        if let pointer {
            daveFree(pointer)
        }
        return []
    }
    defer { daveFree(pointer) }
    return Array(UnsafeBufferPointer(start: pointer, count: count))
}

func checkedInt<T: BinaryInteger>(_ value: T) throws(DaveError) -> Int {
    guard let result = Int(exactly: value) else {
        throw .integerOverflow
    }
    return result
}

func checkedUInt32<T: BinaryInteger>(_ value: T) throws(DaveError) -> UInt32 {
    guard let result = UInt32(exactly: value) else {
        throw .integerOverflow
    }
    return result
}
