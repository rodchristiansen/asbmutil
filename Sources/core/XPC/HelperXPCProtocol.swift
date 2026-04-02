import Foundation

/// Protocol for the helper daemon - called by the GUI app
@objc public protocol HelperXPCProtocol {
    /// Run the CLI with the given arguments
    func runCommand(arguments: [String], reply: @escaping @Sendable (Int32) -> Void)

    /// Stop the currently running command
    func stopCommand(reply: @escaping @Sendable (Bool) -> Void)
}

/// Protocol for callbacks from helper to GUI app
@objc public protocol HelperXPCClientProtocol {
    /// A line of output was received from the command
    func outputReceived(_ line: String)

    /// The command completed with the given exit code
    func commandCompleted(exitCode: Int32)

    /// An error occurred
    func errorOccurred(_ message: String)
}
