import Foundation
import ASBMUtilCore

@Observable
@MainActor
final class BatchStatusViewModel {
    var activityId = ""
    var status = ""
    var isPolling = false
    var isChecking = false
    var pollInterval: Int = 10
    var pollTimeout: Int = 240
    var pollLog: [PollLogEntry] = []
    var errorMessage: String?
    private var pollTask: Task<Void, Never>?

    struct PollLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let status: String
    }

    var canCheck: Bool {
        !activityId.trimmingCharacters(in: .whitespaces).isEmpty && !isChecking && !isPolling
    }

    func checkOnce(client: APIClient) async {
        guard canCheck else { return }
        isChecking = true
        errorMessage = nil

        do {
            status = try await client.activityStatus(id: activityId.trimmingCharacters(in: .whitespaces))
            pollLog.append(PollLogEntry(timestamp: Date(), status: status))
        } catch {
            errorMessage = error.localizedDescription
        }

        isChecking = false
    }

    func startPolling(client: APIClient) {
        guard canCheck else { return }
        isPolling = true
        errorMessage = nil
        pollLog.removeAll()

        pollTask = Task {
            let deadline = Date().addingTimeInterval(TimeInterval(pollTimeout))
            let trimmedId = activityId.trimmingCharacters(in: .whitespaces)

            while Date() < deadline && !Task.isCancelled {
                do {
                    let currentStatus = try await client.activityStatus(id: trimmedId)
                    status = currentStatus
                    pollLog.append(PollLogEntry(timestamp: Date(), status: currentStatus))

                    if currentStatus == "COMPLETE" || currentStatus == "COMPLETED" ||
                       currentStatus == "FAILED" || currentStatus == "ERROR" {
                        break
                    }

                    try await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)
                } catch {
                    if !Task.isCancelled {
                        errorMessage = error.localizedDescription
                    }
                    break
                }
            }

            if Date() >= deadline && !Task.isCancelled {
                status = "TIMEOUT"
                pollLog.append(PollLogEntry(timestamp: Date(), status: "TIMEOUT"))
            }

            isPolling = false
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
    }
}
