import Foundation
import Testing

@testable import Dave

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

#if canImport(MachO)
    import MachO
#endif

@Suite("Process Exit With Live Objects")
struct ProcessExitTests {

    private static let envKey = "SWIFT_DAVE_PROCESS_EXIT_CHILD"

    @Test
    func liveNativeObjectsExitCleanly() throws {
        if ProcessInfo.processInfo.environment[Self.envKey] == "1" {
            let session = try LibdaveSession()
            let encryptor = try LibdaveEncryptor()
            let decryptor = try LibdaveDecryptor()
            _ = (session, encryptor, decryptor)
            exit(0)
        }

        let args = ProcessInfo.processInfo.arguments
        let execPath = args[0]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: execPath)
        var childArgs = Array(args.dropFirst())
        if let filterIdx = childArgs.firstIndex(of: "--filter") {
            if filterIdx + 1 < childArgs.count {
                childArgs.remove(at: filterIdx + 1)
            }
            childArgs.remove(at: filterIdx)
        }
        childArgs.append(contentsOf: ["--filter", "liveNativeObjectsExitCleanly"])
        process.arguments = childArgs

        var env = ProcessInfo.processInfo.environment
        env[Self.envKey] = "1"

        #if canImport(Darwin)
            env["DYLD_FRAMEWORK_PATH"] =
                "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks"

            #if canImport(MachO)
                var loadedSanitizers: [String] = []
                let imageCount = _dyld_image_count()
                for i in 0..<imageCount {
                    guard let namePtr = _dyld_get_image_name(i) else { continue }
                    let name = String(cString: namePtr)
                    if name.contains("libclang_rt.") && name.hasSuffix(".dylib") {
                        loadedSanitizers.append(name)
                    }
                }
                if !loadedSanitizers.isEmpty {
                    env["DYLD_INSERT_LIBRARIES"] = loadedSanitizers.joined(separator: ":")
                }
            #endif
        #endif

        process.environment = env
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0)
        #expect(process.terminationReason == .exit)
    }
}
