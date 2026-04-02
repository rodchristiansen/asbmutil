import Foundation
import ASBMUtilCore

@Observable
@MainActor
final class XPCClient: @unchecked Sendable {
    private var connection: NSXPCConnection?
    private(set) var isRunning = false
    private(set) var lastExitCode: Int32?
    private(set) var connectionError: String?
    var outputLines: [String] = []

    private let callbackHandler = XPCCallbackHandler()

    func connect() {
        let conn = NSXPCConnection(machServiceName: "com.github.rodchristiansen.asbmutil.helper")
        conn.remoteObjectInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        conn.exportedInterface = NSXPCInterface(with: HelperXPCClientProtocol.self)
        conn.exportedObject = callbackHandler

        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
                self?.isRunning = false
            }
        }

        conn.resume()
        connection = conn

        // Wire up callback handler to update our state
        callbackHandler.onOutput = { [weak self] line in
            Task { @MainActor in
                self?.outputLines.append(line)
            }
        }
        callbackHandler.onCompleted = { [weak self] exitCode in
            Task { @MainActor in
                self?.isRunning = false
                self?.lastExitCode = exitCode
            }
        }
        callbackHandler.onError = { [weak self] message in
            Task { @MainActor in
                self?.connectionError = message
                self?.isRunning = false
            }
        }
    }

    func runCommand(arguments: [String]) {
        if connection == nil { connect() }

        outputLines.removeAll()
        isRunning = true
        lastExitCode = nil
        connectionError = nil

        guard let proxy = connection?.remoteObjectProxyWithErrorHandler({ [weak self] error in
            Task { @MainActor in
                self?.connectionError = error.localizedDescription
                self?.isRunning = false
            }
        }) as? HelperXPCProtocol else {
            connectionError = "Failed to get XPC proxy"
            isRunning = false
            return
        }

        proxy.runCommand(arguments: arguments) { [weak self] exitCode in
            Task { @MainActor in
                self?.lastExitCode = exitCode
                self?.isRunning = false
            }
        }
    }

    func stopCommand() {
        guard let proxy = connection?.remoteObjectProxy as? HelperXPCProtocol else { return }
        proxy.stopCommand { _ in }
    }
}

// MARK: - Callback Handler

private final class XPCCallbackHandler: NSObject, HelperXPCClientProtocol, @unchecked Sendable {
    var onOutput: (@Sendable (String) -> Void)?
    var onCompleted: (@Sendable (Int32) -> Void)?
    var onError: (@Sendable (String) -> Void)?

    func outputReceived(_ line: String) {
        onOutput?(line)
    }

    func commandCompleted(exitCode: Int32) {
        onCompleted?(exitCode)
    }

    func errorOccurred(_ message: String) {
        onError?(message)
    }
}
