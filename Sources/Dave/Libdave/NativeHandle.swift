#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

// raw pointer wrapper with idempotent teardown, actor-confined in public api
final class NativeHandle<Pointer>: @unchecked Sendable {

    private var pointer: Pointer?
    private let destroy: (Pointer) -> Void
    private var mutex = pthread_mutex_t()

    init(_ pointer: Pointer, destroy: @escaping (Pointer) -> Void) {
        self.pointer = pointer
        self.destroy = destroy
        pthread_mutex_init(&mutex, nil)
    }

    deinit {
        close()
        pthread_mutex_destroy(&mutex)
    }

    func close() {
        pthread_mutex_lock(&mutex)
        guard let p = pointer else {
            pthread_mutex_unlock(&mutex)
            return
        }
        pointer = nil
        pthread_mutex_unlock(&mutex)
        destroy(p)
    }

    func withUnsafePointer<R, E: Error>(_ body: (Pointer) throws(E) -> R) throws(DaveError) -> R {
        pthread_mutex_lock(&mutex)
        guard let p = pointer else {
            pthread_mutex_unlock(&mutex)
            throw DaveError.handleClosed
        }
        pthread_mutex_unlock(&mutex)

        do {
            return try body(p)
        } catch let err as DaveError {
            throw err
        } catch {
            throw DaveError.invalidInput
        }
    }
}
