import Foundation
import ASBMUtilCore

@Observable
@MainActor
final class SettingsViewModel {
    // Credential fields
    var clientId = ""
    var keyId = ""
    var pemContent = ""
    var selectedProfileName = ""
    var newProfileName = ""

    // State
    var isSaving = false
    var isTesting = false
    var saveStatus: SaveStatus?
    var testStatus: TestStatus?
    var errorMessage: String?
    var profiles: [ProfileInfo] = []

    enum SaveStatus {
        case success
        case error(String)
    }

    enum TestStatus {
        case success
        case error(String)
    }

    func loadProfiles() {
        profiles = Keychain.listProfiles()
        selectedProfileName = Keychain.getCurrentProfile()
        loadCredentials(for: selectedProfileName)
    }

    func loadCredentials(for profileName: String) {
        selectedProfileName = profileName
        saveStatus = nil
        testStatus = nil

        if let blob = Keychain.loadBlob(profileName: profileName) {
            clientId = blob.clientId
            keyId = blob.keyId
            pemContent = blob.privateKey
        } else {
            clientId = ""
            keyId = ""
            pemContent = ""
        }
    }

    func saveCredentials() {
        isSaving = true
        saveStatus = nil

        let blob = KCBlob(clientId: clientId, keyId: keyId, privateKey: pemContent, teamId: "")
        let status = Keychain.saveBlob(blob, profileName: selectedProfileName)

        if status == 0 {
            saveStatus = .success
            // Refresh profiles list
            profiles = Keychain.listProfiles()
        } else {
            saveStatus = .error("Keychain write failed (status: \(status))")
        }

        isSaving = false
    }

    func testConnection() async {
        isTesting = true
        testStatus = nil

        do {
            let credentials = try Creds.load(profileName: selectedProfileName)
            let client = try await APIClient(credentials: credentials, profileName: selectedProfileName)
            // Try listing servers as a connectivity test
            _ = try await client.listMdmServers()
            testStatus = .success
        } catch {
            testStatus = .error(error.localizedDescription)
        }

        isTesting = false
    }

    func createProfile(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Save a placeholder blob to register the profile in Keychain
        let blob = KCBlob(clientId: "", keyId: "", privateKey: "", teamId: "")
        Keychain.saveBlob(blob, profileName: trimmed)
        profiles = Keychain.listProfiles()
        selectedProfileName = trimmed
        clientId = ""
        keyId = ""
        pemContent = ""
        newProfileName = ""
    }

    func deleteProfile(name: String) {
        _ = Keychain.deleteBlob(profileName: name)
        profiles = Keychain.listProfiles()

        if selectedProfileName == name {
            selectedProfileName = Keychain.getCurrentProfile()
            loadCredentials(for: selectedProfileName)
        }
    }
}
