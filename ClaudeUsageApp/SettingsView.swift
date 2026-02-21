import SwiftUI
import WidgetKit

struct SettingsView: View {
    @State private var sessionKey: String = ""
    @State private var organizationID: String = ""
    @State private var testResult: ConnectionTestResult?
    @State private var isTesting = false
    @State private var showSessionKey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                authSection
                testSection
                instructionsSection
                widgetSection
            }
            .padding(24)
        }
        .frame(minWidth: 520, minHeight: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { loadConfig() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle")
                .font(.title2)
                .foregroundStyle(Color(hex: "#F97316"))
            VStack(alignment: .leading, spacing: 2) {
                Text("TokenEater")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Configurez votre connexion pour afficher la consommation dans le widget")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Auth

    private var authSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Authentification")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Session Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        if showSessionKey {
                            TextField("sk-ant-sid01-...", text: $sessionKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            SecureField("sk-ant-sid01-...", text: $sessionKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                        Button {
                            showSessionKey.toggle()
                        } label: {
                            Image(systemName: showSessionKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Organization ID (cookie **lastActiveOrg**)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Cookie lastActiveOrg — ex: 941eb286-b278-...", text: $organizationID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding(4)
        }
        .onChange(of: sessionKey) { saveConfig() }
        .onChange(of: organizationID) { saveConfig() }
    }

    // MARK: - Test

    private var testSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    testConnection()
                } label: {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "network")
                        }
                        Text("Tester la connexion")
                    }
                }
                .disabled(sessionKey.isEmpty || organizationID.isEmpty || isTesting)

                Spacer()

                Button {
                    WidgetCenter.shared.reloadAllTimelines()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Rafraichir le widget")
                    }
                }
                .disabled(sessionKey.isEmpty)
            }

            if let result = testResult {
                HStack(spacing: 6) {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.success ? .green : .red)
                    Text(result.message)
                        .font(.callout)
                    Spacer()
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                )
            }
        }
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Comment configurer")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    instructionStep(1, "Ouvrez **claude.ai** dans Chrome et connectez-vous")
                    instructionStep(2, "Ouvrez les DevTools : **Cmd + Option + I**")
                    instructionStep(3, "Allez dans l'onglet **Application** > **Cookies** > **claude.ai**")
                    instructionStep(4, "Copiez le cookie **sessionKey** (commence par `sk-ant-sid01-`)")
                    instructionStep(5, "Copiez le cookie **lastActiveOrg** (c'est l'Organization ID)")
                    instructionStep(6, "Collez les deux valeurs dans les champs ci-dessus")
                }

                Divider()

                Text("Les cookies expirent environ chaque mois. Si le widget affiche une erreur, mettez-les a jour ici.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(4)
        }
    }

    private func instructionStep(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color(hex: "#F97316")))
            Text(text)
                .font(.callout)
        }
    }

    // MARK: - Widget Info

    private var widgetSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ajouter le widget")
                    .font(.headline)
                Text("Clic droit sur le bureau > **Modifier les widgets** > cherchez \"TokenEater\"")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(4)
        }
    }

    // MARK: - Config Persistence

    private func loadConfig() {
        if let config = SharedStorage.readConfig(fromHost: true) {
            sessionKey = config.sessionKey
            organizationID = config.organizationID
        }
    }

    private func saveConfig() {
        let config = SharedConfig(sessionKey: sessionKey, organizationID: organizationID)
        SharedStorage.writeConfig(config, fromHost: true)
    }

    // MARK: - Actions

    private func testConnection() {
        isTesting = true
        testResult = nil
        saveConfig()

        Task {
            let result = await ClaudeAPIClient.shared.testConnection(
                sessionKey: sessionKey,
                orgID: organizationID
            )

            await MainActor.run {
                testResult = result
                isTesting = false

                if result.success {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
    }
}
