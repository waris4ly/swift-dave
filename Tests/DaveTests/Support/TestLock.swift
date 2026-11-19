#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

final class TestLock<State>: @unchecked Sendable {
    private var state: State
    private var mutex = pthread_mutex_t()

    init(initialState: State) {
        self.state = initialState
        pthread_mutex_init(&mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }

    func withLock<R>(_ body: (inout State) throws -> R) rethrows -> R {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        return try body(&state)
    }
}
