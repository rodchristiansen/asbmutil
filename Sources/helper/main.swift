import Foundation
import ASBMUtilCore

// MARK: - Helper Delegate

final class HelperDelegate: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Validate connecting process via code signing
        guard validateClient(newConnection) else {
            return false
        }

        newConnection.exportedInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        newConnection.exportedObject = HelperService()

        newConnection.remoteObjectInterface = NSXPCInterface(with: HelperXPCClientProtocol.self)

        newConnection.invalidationHandler = { [weak newConnection] in
            _ = newConnection // prevent retain cycle warning
        }

        newConnection.resume()
        return true
    }

    private func validateClient(_ connection: NSXPCConnection) -> Bool {
        #if DEBUG
        return true
        #else
        let pid = connection.processIdentifier
        var code: SecCode?

        let attrs = [kSecGuestAttributePid: pid] as CFDictionary
        guard SecCodeCopyGuestWithAttributes(nil, attrs, [], &code) == errSecSuccess,
              let secCode = code else {
            return false
        }

        // Require our team ID
        let requirement = "anchor apple generic and certificate leaf[subject.OU] = \"7TF6CSP83S\""
        var secRequirement: SecRequirement?
        guard SecRequirementCreateWithString(requirement as CFString, [], &secRequirement) == errSecSuccess,
              let req = secRequirement else {
            return false
        }

        return SecCodeCheckValidity(secCode, [], req) == errSecSuccess
        #endif
    }
}

// MARK: - Helper Service

final class HelperService: NSObject, HelperXPCProtocol, @unchecked Sendable {
    private var currentProcess: Process?
    private let processLock = NSLock()

    func runCommand(arguments: [String], reply: @escaping @Sendable (Int32) -> Void) {
        let connection = NSXPCConnection.current()
        let clientProxy = connection?.remoteObjectProxy as? any HelperXPCClientProtocol
        nonisolated(unsafe) let proxy = clientProxy

        let process = Process()

        // Find the CLI binary - look next to the helper first, then /usr/local/bin
        let helperPath = ProcessInfo.processInfo.arguments[0]
        let helperDir = URL(fileURLWithPath: helperPath).deletingLastPathComponent()
        let cliPath = helperDir.appendingPathComponent("asbmutil").path

        if FileManager.default.fileExists(atPath: cliPath) {
            process.executableURL = URL(fileURLWithPath: cliPath)
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/asbmutil")
        }

        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        processLock.lock()
        currentProcess = process
        processLock.unlock()

        // Stream output line-by-line
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            if let line = String(data: data, encoding: .utf8) {
                // Send each line back to the GUI
                for outputLine in line.components(separatedBy: .newlines) where !outputLine.isEmpty {
                    proxy?.outputReceived(outputLine)
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            pipe.fileHandleForReading.readabilityHandler = nil

            self?.processLock.lock()
            self?.currentProcess = nil
            self?.processLock.unlock()

            let exitCode = proc.terminationStatus
            proxy?.commandCompleted(exitCode: exitCode)
            reply(exitCode)
        }

        do {
            try process.run()
        } catch {
            clientProxy?.errorOccurred("Failed to launch command: \(error.localizedDescription)")
            reply(-1)
        }
    }

    func stopCommand(reply: @escaping @Sendable (Bool) -> Void) {
        processLock.lock()
        let process = currentProcess
        processLock.unlock()

        if let process = process, process.isRunning {
            process.terminate()
            reply(true)
        } else {
            reply(false)
        }
    }
}

// MARK: - Main

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: "com.github.rodchristiansen.asbmutil.helper")
listener.delegate = delegate
listener.resume()

RunLoop.main.run()
