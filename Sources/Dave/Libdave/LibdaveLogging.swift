import CLibDave

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

// log sink storage protected by lock for thread-safe native callback delivery
private final class LogSinkState: @unchecked Sendable {
    var sink: DaveLogSink?
    var mutex = pthread_mutex_t()

    init() {
        pthread_mutex_init(&mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }
}

// libdave invokes logging from background threads, so state is protected by lock
private let globalLogState = LogSinkState()

private func cLogCallback(
    severity: DAVELoggingSeverity,
    file: UnsafePointer<CChar>?,
    line: Int32,
    message: UnsafePointer<CChar>?
) {
    pthread_mutex_lock(&globalLogState.mutex)
    let sink = globalLogState.sink
    pthread_mutex_unlock(&globalLogState.mutex)

    guard let sink else { return }

    let level: DaveLogLevel
    switch severity {
    case DAVE_LOGGING_SEVERITY_VERBOSE:
        level = .verbose
    case DAVE_LOGGING_SEVERITY_INFO:
        level = .info
    case DAVE_LOGGING_SEVERITY_WARNING:
        level = .warning
    default:
        level = .error
    }

    let filePath = file.map { String(cString: $0) } ?? ""
    let messageText = message.map { String(cString: $0) } ?? ""
    sink(level, filePath, Int(line), messageText)
}

public func setDaveLogSink(_ sink: DaveLogSink?) {
    pthread_mutex_lock(&globalLogState.mutex)
    globalLogState.sink = sink
    pthread_mutex_unlock(&globalLogState.mutex)

    if sink != nil {
        daveSetLogSinkCallback(cLogCallback)
    } else {
        daveSetLogSinkCallback(nil)
    }
}
