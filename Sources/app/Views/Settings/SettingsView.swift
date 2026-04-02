import SwiftUI
import UniformTypeIdentifiers
import ASBMUtilCore

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = SettingsViewModel()
    @State private var showFilePicker = false
    @State private var showDeleteConfirmation = false
    @State private var profileToDelete = ""
    @State private var expandedProfile: String?
    @State private var renamingProfile: String?
    @State private var renameText = ""

    var body: some View {
        TabView {
            profilesTab
                .padding(.top, 8)
                .tabItem { Label("Profiles", systemImage: "person.2") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 520)
        .onAppear { viewModel.loadProfiles() }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "pem") ?? .plainText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    viewModel.pemContent = content
                }
            }
        }
        .alert("Rename Profile", isPresented: Binding(
            get: { renamingProfile != nil },
            set: { if !$0 { renamingProfile = nil } }
        )) {
            TextField("New name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingProfile = nil }
            Button("Rename") {
                if let oldName = renamingProfile, !renameText.trimmingCharacters(in: .whitespaces).isEmpty, renameText != oldName {
                    // Copy credentials to new name, delete old
                    if let blob = Keychain.loadBlob(profileName: oldName) {
                        Keychain.saveBlob(blob, profileName: renameText)
                    }
                    _ = Keychain.deleteBlob(profileName: oldName)
                    if Keychain.getCurrentProfile() == oldName {
                        _ = Keychain.setCurrentProfile(renameText)
                    }
                    if expandedProfile == oldName { expandedProfile = renameText }
                    viewModel.loadProfiles()
                    appViewModel.loadProfiles()
                }
                renamingProfile = nil
            }
        } message: {
            Text("Enter a new name for '\(renamingProfile ?? "")'")
        }
        .alert("Delete Profile", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteProfile(name: profileToDelete)
                appViewModel.loadProfiles()
                if expandedProfile == profileToDelete { expandedProfile = nil }
            }
        } message: {
            Text("Delete '\(profileToDelete)' and its credentials? This cannot be undone.")
        }
    }

    // MARK: - Profiles Tab (with inline credentials accordion)

    @State private var showNewProfile = false
    @State private var newName = ""
    @State private var newClientId = ""
    @State private var newKeyId = ""
    @State private var newPem = ""
    @State private var showNewPemPicker = false

    private var profilesTab: some View {
        Form {
            ForEach(viewModel.profiles, id: \.name) { profile in
                profileRow(profile)
            }

            Section {
                Button {
                    showNewProfile = true
                    newName = ""
                    newClientId = ""
                    newKeyId = ""
                    newPem = ""
                } label: {
                    Label("Add Profile", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showNewProfile) {
            newProfileSheet
        }
    }

    private var newProfileSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Profile").font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Profile Name").font(.caption).foregroundStyle(.secondary)
                TextField("e.g. production, school-west", text: $newName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Client ID").font(.caption).foregroundStyle(.secondary)
                TextField("SCHOOLAPI.xxx or BUSINESSAPI.xxx", text: $newClientId)
                    .textFieldStyle(.roundedBorder).fontDesign(.monospaced).font(.callout)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Key ID").font(.caption).foregroundStyle(.secondary)
                TextField("Key ID from Apple", text: $newKeyId)
                    .textFieldStyle(.roundedBorder).fontDesign(.monospaced).font(.callout)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Private Key").font(.caption).foregroundStyle(.secondary)
                HStack {
                    if newPem.isEmpty {
                        Button("Select PEM File...") { showNewPemPicker = true }
                            .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.caption)
                        Text("Loaded (\(newPem.count) chars)")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Change...") { showNewPemPicker = true }
                            .controlSize(.small)
                    }
                }
            }

            HStack {
                Button("Cancel") { showNewProfile = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    let blob = KCBlob(clientId: newClientId, keyId: newKeyId, privateKey: newPem, teamId: "")
                    Keychain.saveBlob(blob, profileName: newName)
                    viewModel.loadProfiles()
                    appViewModel.loadProfiles()
                    expandedProfile = newName
                    showNewProfile = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty
                          || newClientId.isEmpty || newKeyId.isEmpty || newPem.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 440)
        .fileImporter(
            isPresented: $showNewPemPicker,
            allowedContentTypes: [UTType(filenameExtension: "pem") ?? .plainText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    newPem = content
                }
            }
        }
    }

    private func profileRow(_ profile: ProfileInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: expandedProfile == profile.name ? "chevron.down" : "chevron.right")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(profile.name)
                            .font(.body).fontWeight(.medium)
                        if profile.name == Keychain.getCurrentProfile() {
                            Text("Active")
                                .font(.caption2)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: 8) {
                        Text(profile.scope.isEmpty ? "No credentials" : profile.scope)
                            .font(.caption).foregroundStyle(.secondary)
                        if !profile.clientId.isEmpty {
                            Text(String(profile.clientId.prefix(24)) + "...")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                Button {
                    renamingProfile = profile.name
                    renameText = profile.name
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .controlSize(.small)
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    profileToDelete = profile.name
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(viewModel.profiles.count <= 1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    if expandedProfile == profile.name {
                        expandedProfile = nil
                    } else {
                        expandedProfile = profile.name
                        viewModel.loadCredentials(for: profile.name)
                    }
                }
            }

            if expandedProfile == profile.name {
                credentialFields()
                    .padding(.top, 10)
                    .padding(.leading, 28)
            }
        }
    }

    private func credentialFields() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Client ID").font(.caption).foregroundStyle(.secondary)
                TextField("SCHOOLAPI.xxx or BUSINESSAPI.xxx", text: $viewModel.clientId)
                    .textFieldStyle(.roundedBorder).fontDesign(.monospaced).font(.callout)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Key ID").font(.caption).foregroundStyle(.secondary)
                TextField("Key ID from Apple", text: $viewModel.keyId)
                    .textFieldStyle(.roundedBorder).fontDesign(.monospaced).font(.callout)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Private Key").font(.caption).foregroundStyle(.secondary)
                HStack {
                    if viewModel.pemContent.isEmpty {
                        Button("Select PEM File...") { showFilePicker = true }
                            .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.caption)
                        Text("Loaded (\(viewModel.pemContent.count) chars)")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Change...") { showFilePicker = true }
                            .controlSize(.small)
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Save") {
                    viewModel.saveCredentials()
                    appViewModel.loadProfiles()
                    viewModel.loadProfiles()
                }
                .buttonStyle(.borderedProminent).controlSize(.small)
                .disabled(viewModel.clientId.isEmpty || viewModel.keyId.isEmpty || viewModel.pemContent.isEmpty)

                Button("Test Connection") {
                    Task { await viewModel.testConnection() }
                }
                .controlSize(.small)
                .disabled(viewModel.isTesting || viewModel.clientId.isEmpty)

                if viewModel.isTesting { ProgressView().controlSize(.small) }

                Spacer()

                statusIndicator
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if let status = viewModel.testStatus {
            switch status {
            case .success:
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.caption)
            case .error(let msg):
                Label(msg, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red).font(.caption).lineLimit(1)
            }
        } else if let status = viewModel.saveStatus {
            switch status {
            case .success:
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.caption)
            case .error(let msg):
                Label(msg, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red).font(.caption).lineLimit(1)
            }
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ASBMUtil").font(.title3).fontWeight(.semibold)
                        Text("Apple School & Business Manager CLI + GUI")
                            .font(.caption).foregroundStyle(.secondary)
                        Link("github.com/rodchristiansen/asbmutil",
                             destination: URL(string: "https://github.com/rodchristiansen/asbmutil")!)
                            .font(.caption)
                    }
                }

                VStack(spacing: 6) {
                    labeledInfo("Version", AppVersion.version)
                    labeledInfo("Keychain", Keychain.service)
                    labeledInfo("Platform", "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
                    labeledInfo("Swift", "6.0")
                }

                Divider()

                // Related projects
                VStack(alignment: .leading, spacing: 8) {
                    Text("Related Projects").font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary).textCase(.uppercase)
                    projectRow("ReportMate", "Unified reporting + visibility for Mac + Windows fleets", "https://github.com/reportmate")
                    projectRow("BootstrapMate", "Provisioning + bootstrap tooling with a DevOps-first workflow", "https://github.com/bootstrapmate")
                    projectRow("Cimian", "Managed software deployment for MSI(X), EXE, NUPKG, and PWSH on Windows", "https://github.com/windowsadmins/cimian")
                }

                Divider()

                // Author
                VStack(alignment: .leading, spacing: 6) {
                    Text("Author").font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary).textCase(.uppercase)
                    Text("Rod Christiansen").font(.body).fontWeight(.medium)
                    Text("Devices Administrator Lead at Emily Carr University of Art + Design")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Vancouver, BC, Canada")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Managing a fleet of 1000+ computers. Focused on infrastructure, DevOps architecture, CI/CD pipelines, and automating at scale.")
                        .font(.caption).foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        linkRow("GitHub", "github.com/rodchristiansen", "https://github.com/rodchristiansen")
                        linkRow("Blog", "blog.focused.systems", "https://blog.focused.systems")
                    }
                    .padding(.top, 4)
                }
            }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func projectRow(_ name: String, _ desc: String, _ urlString: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let url = URL(string: urlString) {
                Link(name, destination: url)
                    .font(.callout).fontWeight(.medium)
            } else {
                Text(name).font(.callout).fontWeight(.medium)
            }
            Text(desc).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func linkRow(_ label: String, _ display: String, _ urlString: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.callout).fontWeight(.medium)
            if let url = URL(string: urlString) {
                Link(display, destination: url)
                    .font(.caption).foregroundStyle(.blue)
            }
        }
    }

    private func labeledInfo(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value).font(.caption).textSelection(.enabled)
            Spacer()
        }
    }

}
