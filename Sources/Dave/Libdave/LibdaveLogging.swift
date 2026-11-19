import CLibDave
import os

// log sink storage protected by lock for thread-safe native callback delivery
private final class LogSinkState: @unchecked Sendable {
    var sink: DaveLogSink?
    var lock = os_unfair_lock_s()
}

// libdave invokes logging from background threads, so state is protected by lock
private let globalLogState = LogSinkState()

private func cLogCallback(
    severity: DAVELoggingSeverity,
    file: UnsafePointer<CChar>?,
    line: Int32,
    message: UnsafePointer<CChar>?
) {
    os_unfair_lock_lock(&globalLogState.lock)
    let sink = globalLogState.sink
    os_unfair_lock_unlock(&globalLogState.lock)

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
    os_unfair_lock_lock(&globalLogState.lock)
    globalLogState.sink = sink
    os_unfair_lock_unlock(&globalLogState.lock)

    if sink != nil {
        daveSetLogSinkCallback(cLogCallback)
    } else {
        daveSetLogSinkCallback(nil)
    }
}
