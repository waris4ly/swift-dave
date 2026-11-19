import os

// raw pointer wrapper with idempotent teardown, actor-confined in public api
final class NativeHandle<Pointer>: @unchecked Sendable {

    private var pointer: Pointer?
    private let destroy: (Pointer) -> Void
    private var lock = os_unfair_lock_s()

    init(_ pointer: Pointer, destroy: @escaping (Pointer) -> Void) {
        self.pointer = pointer
        self.destroy = destroy
    }

    deinit {
        close()
    }

    func close() {
        os_unfair_lock_lock(&lock)
        guard let p = pointer else {
            os_unfair_lock_unlock(&lock)
            return
        }
        pointer = nil
        os_unfair_lock_unlock(&lock)
        destroy(p)
    }

    func withUnsafePointer<R, E: Error>(_ body: (Pointer) throws(E) -> R) throws(DaveError) -> R {
        os_unfair_lock_lock(&lock)
        guard let p = pointer else {
            os_unfair_lock_unlock(&lock)
            throw DaveError.handleClosed
        }
        os_unfair_lock_unlock(&lock)

        do {
            return try body(p)
        } catch let err as DaveError {
            throw err
        } catch {
            throw DaveError.invalidInput
        }
    }
}
