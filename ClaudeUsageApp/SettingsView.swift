import SwiftUI
import WidgetKit

extension Notification.Name {
    static let displaySettingsDidChange = Notification.Name("displaySettingsDidChange")
}

struct SettingsView: View {
    var onConfigSaved: (() -> Void)?

    @State private var sessionKey = ""
    @State private var organizationID = ""
    @State private var testResult: ConnectionTestResult?
    @State private var isTesting = false
    @State private var showSessionKey = false
    @State private var showGuide = false
    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var importSuccess = false
    @State private var detectedBrowsers: [DetectedBrowser] = []
    @State private var showBrowserPicker = false
    @State private var authMethodLabel = ""
    @State private var isOAuth = false

    @AppStorage("showMenuBar") private var showMenuBar = true

    @AppStorage("pacingDisplayMode") private var pacingDisplayMode = "dotDelta"

    @State private var pinnedFiveHour = true
    @State private var pinnedSevenDay = true
    @State private var pinnedSonnet = false
    @State private var pinnedPacing = false

    @State private var proxyEnabled = false
    @State private var proxyHost = "127.0.0.1"
    @State private var proxyPort = "1080"

    // Colors kept for guide/browser picker sheets
    private let sheetBg = Color(hex: "#141416")
    private let sheetCard = Color.white.opacity(0.04)
    private let accent = Color(hex: "#FF9F0A")
    private let accentRed = Color(hex: "#FF453A")

    var body: some View {
        VStack(spacing: 0) {
            // App header
            HStack(spacing: 12) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text("TokenEater")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("settings.subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("v1.1.0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            TabView {
                connectionTab
                    .tabItem {
                        Label("settings.tab.connection", systemImage: "bolt.horizontal.fill")
                    }
                displayTab
                    .tabItem {
                        Label("settings.tab.display", systemImage: "menubar.rectangle")
                    }
                proxyTab
                    .tabItem {
                        Label("settings.tab.proxy", systemImage: "network")
                    }
            }
        }
        .frame(width: 500, height: isOAuth ? 400 : 480)
        .onAppear { loadConfig() }
        .sheet(isPresented: $showGuide) { guideSheet }
        .sheet(isPresented: $showBrowserPicker) { browserPickerSheet }
    }

    // MARK: - Connection Tab

    private var connectionTab: some View {
        Form {
            Section {
                HStack {
                    if isImporting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("connect.button")
                            .fontWeight(.medium)
                        Text("connect.subtitle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !authMethodLabel.isEmpty {
                        Text(authMethodLabel)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.green.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Button("connect.button") {
                        connectAutoDetect()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isImporting)
                }

                if let message = importMessage {
                    Label(message, systemImage: importSuccess ? "checkmark.circle.fill" : "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(importSuccess ? .green : .orange)
                }
            }

            if !isOAuth {
                Section {
                    LabeledContent("settings.sessionkey") {
                        HStack(spacing: 6) {
                            Group {
                                if showSessionKey {
                                    TextField("sk-ant-sid01-...", text: $sessionKey)
                                } else {
                                    SecureField("sk-ant-sid01-...", text: $sessionKey)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))

                            Button {
                                showSessionKey.toggle()
                            } label: {
                                Image(systemName: showSessionKey ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    LabeledContent("settings.orgid") {
                        TextField("941eb286-b278-...", text: $organizationID)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                } header: {
                    Text("settings.manual")
                } footer: {
                    Text("settings.orgid.hint")
                }
            }

            Section {
                HStack(spacing: 12) {
                    Button {
                        testConnection()
                    } label: {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("settings.test", systemImage: "bolt.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled((!isOAuth && (sessionKey.isEmpty || organizationID.isEmpty)) || isTesting)

                    Button {
                        WidgetCenter.shared.reloadAllTimelines()
                    } label: {
                        Label("settings.refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(!isOAuth && sessionKey.isEmpty)

                    Spacer()

                    Button {
                        showGuide = true
                    } label: {
                        Label("settings.guide", systemImage: "questionmark.circle")
                    }
                }

                if let result = testResult {
                    Label(
                        result.message,
                        systemImage: result.success ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(result.success ? .green : .red)
                }
            } footer: {
                Text("settings.footer")
            }
        }
        .formStyle(.grouped)
        .onChange(of: sessionKey) { _ in saveConfig() }
        .onChange(of: organizationID) { _ in saveConfig() }
    }

    // MARK: - Display Tab

    private var displayTab: some View {
        Form {
            Section("settings.menubar.title") {
                Toggle("settings.menubar.toggle", isOn: $showMenuBar)
            }

            Section {
                Toggle("metric.session", isOn: $pinnedFiveHour)
                Toggle("metric.weekly", isOn: $pinnedSevenDay)
                Toggle("metric.sonnet", isOn: $pinnedSonnet)
                Toggle("pacing.label", isOn: $pinnedPacing)
            } header: {
                Text("settings.metrics.pinned")
            } footer: {
                Text("settings.metrics.pinned.footer")
            }
            Section("settings.pacing.display") {
                Picker("Mode", selection: $pacingDisplayMode) {
                    Text("settings.pacing.dot").tag("dot")
                    Text("settings.pacing.dotdelta").tag("dotDelta")
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
        .onAppear { loadPinnedMetrics() }
        .onChange(of: pinnedFiveHour) { _ in savePinnedMetrics() }
        .onChange(of: pinnedSevenDay) { _ in savePinnedMetrics() }
        .onChange(of: pinnedSonnet) { _ in savePinnedMetrics() }
        .onChange(of: pinnedPacing) { _ in savePinnedMetrics() }
        .onChange(of: pacingDisplayMode) { _ in
            NotificationCenter.default.post(name: .displaySettingsDidChange, object: nil)
        }
    }

    // MARK: - Proxy Tab

    private var proxyTab: some View {
        Form {
            Section {
                Toggle("settings.proxy.toggle", isOn: $proxyEnabled)
            } footer: {
                Text("settings.proxy.footer")
            }

            Section("settings.proxy.config") {
                LabeledContent("settings.proxy.host") {
                    TextField("127.0.0.1", text: $proxyHost)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
                LabeledContent("settings.proxy.port") {
                    TextField("1080", text: $proxyPort)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 80)
                }
            }
            .disabled(!proxyEnabled)

            Section {
                Text("settings.proxy.hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: proxyEnabled) { _ in saveConfig() }
        .onChange(of: proxyHost) { _ in saveConfig() }
        .onChange(of: proxyPort) { _ in saveConfig() }
    }

    // MARK: - Guide Sheet

    private var guideSheet: some View {
        ZStack {
            sheetBg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("guide.title")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        showGuide = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

                VStack(spacing: 10) {
                    guideStep(1, "globe", LocalizedStringKey("guide.step1"))
                    guideStep(2, "terminal", LocalizedStringKey("guide.step2"))
                    guideStep(3, "tray.full", LocalizedStringKey("guide.step3"))
                    guideStep(4, "key.fill", LocalizedStringKey("guide.step4"), detail: String(localized: "guide.step4.detail"))
                    guideStep(5, "building.2", LocalizedStringKey("guide.step5"), detail: String(localized: "guide.step5.detail"))
                    guideStep(6, "checkmark.circle", LocalizedStringKey("guide.step6"))

                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 14))
                            .foregroundStyle(accent)
                            .frame(width: 32, height: 32)
                            .background(accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("guide.widget")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("guide.widget.detail")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(accent.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(accent.opacity(0.15), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                Spacer(minLength: 0)
            }
        }
        .frame(width: 440, height: 540)
    }

    private func guideStep(_ number: Int, _ icon: String, _ text: LocalizedStringKey, detail: String? = nil) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Text("\(number)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [accent, accentRed],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                if let detail = detail {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(sheetCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    // MARK: - Browser Picker Sheet

    private var browserPickerSheet: some View {
        ZStack {
            sheetBg.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text("import.picker.title")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        showBrowserPicker = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(detectedBrowsers) { browser in
                    Button {
                        importFromBrowser(browser)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: browserIcon(browser.id))
                                .font(.system(size: 18))
                                .foregroundStyle(accent)
                                .frame(width: 36, height: 36)
                                .background(accent.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(browser.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                Text(String(format: String(localized: "import.profiles"), browser.cookiePaths.count))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.35))
                            }

                            Spacer()

                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(sheetCard)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                if isImporting {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(accent)
                        Text("import.loading")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                if let message = importMessage, !importSuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(accentRed)
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(width: 360, height: 320)
    }

    private func browserIcon(_ id: String) -> String {
        switch id {
        case "chrome": return "globe"
        case "arc": return "circle.hexagongrid"
        case "brave": return "shield"
        case "edge": return "globe.americas"
        default: return "globe"
        }
    }

    // MARK: - Config Persistence

    private func loadConfig() {
        if let config = SharedStorage.readConfig(fromHost: true) {
            sessionKey = config.sessionKey
            organizationID = config.organizationID
            proxyEnabled = config.proxyEnabled
            proxyHost = config.proxyHost
            proxyPort = String(config.proxyPort)
        }
        loadPinnedMetrics()
        if KeychainOAuthReader.readClaudeCodeToken() != nil {
            authMethodLabel = String(localized: "connect.method.oauth")
            isOAuth = true
        } else if !sessionKey.isEmpty && !organizationID.isEmpty {
            authMethodLabel = String(localized: "connect.method.cookies")
            isOAuth = false
        }
    }

    private func saveConfig() {
        let config = SharedConfig(
            sessionKey: sessionKey,
            organizationID: organizationID,
            proxyEnabled: proxyEnabled,
            proxyHost: proxyHost,
            proxyPort: Int(proxyPort) ?? 1080
        )
        SharedStorage.writeConfig(config, fromHost: true)
        onConfigSaved?()
    }

    private func loadPinnedMetrics() {
        if let saved = UserDefaults.standard.stringArray(forKey: "pinnedMetrics") {
            let set = Set(saved)
            pinnedFiveHour = set.contains(MetricID.fiveHour.rawValue)
            pinnedSevenDay = set.contains(MetricID.sevenDay.rawValue)
            pinnedSonnet = set.contains(MetricID.sonnet.rawValue)
            pinnedPacing = set.contains(MetricID.pacing.rawValue)
        }
    }

    private func savePinnedMetrics() {
        var metrics: [String] = []
        if pinnedFiveHour { metrics.append(MetricID.fiveHour.rawValue) }
        if pinnedSevenDay { metrics.append(MetricID.sevenDay.rawValue) }
        if pinnedSonnet { metrics.append(MetricID.sonnet.rawValue) }
        if pinnedPacing { metrics.append(MetricID.pacing.rawValue) }
        if metrics.isEmpty { metrics.append(MetricID.fiveHour.rawValue); pinnedFiveHour = true }
        UserDefaults.standard.set(metrics, forKey: "pinnedMetrics")
        NotificationCenter.default.post(name: .displaySettingsDidChange, object: nil)
    }

    // MARK: - Actions

    private func testConnection() {
        isTesting = true
        testResult = nil
        if !isOAuth { saveConfig() }

        Task {
            let method: AuthMethod
            if isOAuth, let oauth = KeychainOAuthReader.readClaudeCodeToken() {
                method = .oauth(token: oauth.accessToken)
            } else {
                method = .cookies(sessionKey: sessionKey, orgId: organizationID)
            }
            let result = await ClaudeAPIClient.shared.testConnection(method: method)

            await MainActor.run {
                testResult = result
                isTesting = false

                if result.success {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
    }

    private func connectAutoDetect() {
        isImporting = true
        importMessage = nil

        if let oauth = KeychainOAuthReader.readClaudeCodeToken() {
            Task {
                let result = await ClaudeAPIClient.shared.testConnection(method: .oauth(token: oauth.accessToken))
                await MainActor.run {
                    isImporting = false
                    if result.success {
                        isOAuth = true
                        authMethodLabel = String(localized: "connect.method.oauth")
                        importMessage = String(localized: "connect.oauth.success")
                        importSuccess = true
                        onConfigSaved?()
                    } else {
                        detectAndImportFromBrowser()
                    }
                }
            }
            return
        }

        detectAndImportFromBrowser()
    }

    private func detectAndImportFromBrowser() {
        isImporting = true

        DispatchQueue.global(qos: .userInitiated).async {
            let browsers = BrowserCookieReader.detectBrowsers()

            if browsers.isEmpty {
                DispatchQueue.main.async {
                    isImporting = false
                    importMessage = String(localized: "import.nobroser")
                    importSuccess = false
                }
                return
            }

            if browsers.count > 1 {
                DispatchQueue.main.async {
                    detectedBrowsers = browsers
                    showBrowserPicker = true
                    isImporting = false
                }
                return
            }

            importFromBrowser(browsers[0])
        }
    }

    private func importFromBrowser(_ browser: DetectedBrowser) {
        isImporting = true
        importMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let result = BrowserCookieReader.importCookies(from: browser)

            DispatchQueue.main.async {
                isImporting = false
                switch result {
                case .success(let cookies):
                    sessionKey = cookies.sessionKey
                    organizationID = cookies.organizationID
                    saveConfig()
                    authMethodLabel = String(localized: "connect.method.cookies")
                    isOAuth = false
                    var msg = String(format: String(localized: "import.success"), cookies.browser)
                    if let expires = cookies.sessionKeyExpires {
                        let formatted = expires.formatted(.relative(presentation: .named))
                        msg += " · " + String(format: String(localized: "import.expires"), formatted)
                    }
                    importMessage = msg
                    importSuccess = true
                    showBrowserPicker = false
                case .failure(let error):
                    importMessage = "\(browser.name) : \(error.localizedDescription)"
                    importSuccess = false
                }
            }
        }
    }
}
