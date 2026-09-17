import SwiftUI
import UIKit

/// Redesigned main screen: one active profile (Yandex Docs / VOLGA / Mail.ru /
/// MAX), a single power control that brings up the system VPN for it, an
/// availability check, and a collapsible log console. Settings / add-edit /
/// about live in bottom sheets.
///
/// All persisted keys are unchanged from the previous UI (`docURL`,
/// `docURL2`, `volgaURL`, `mailURL`, `maxToken`, `maxUid`, `socksPort`,
/// `dnsPreset`, `dnsCustom`, `tunnelUDP`) so existing settings survive the
/// redesign. `TunnelController`/`VPNController`/the Go bridge are untouched —
/// this view only calls the same public methods they already exposed.
struct ContentView: View {
    @StateObject private var tunnel = TunnelController()
    @StateObject private var vpn = VPNController()

    @AppStorage("docURL") private var docURL: String = ""
    @AppStorage("docURL2") private var docURL2: String = ""
    @AppStorage("volgaURL") private var volgaURL: String = ""
    @AppStorage("mailURL") private var mailURL: String = ""
    @AppStorage("maxToken") private var maxToken: String = ""
    @AppStorage("maxUid") private var maxUid: String = ""
    @AppStorage("socksPort") private var socksPort: String = "10808"
    @AppStorage("dnsPreset") private var dnsPreset: String = "default"
    @AppStorage("dnsCustom") private var dnsCustom: String = ""
    @AppStorage("tunnelUDP") private var tunnelUDP: Bool = false

    /// Which of the four transports is selected in the profile switcher.
    @AppStorage("activeTransport") private var activeRaw: String = TransportKind.mail.rawValue

    @State private var showProfileSwitcher = false
    @State private var showSettings = false
    @State private var showAddEdit = false
    @State private var showInfo = false
    @State private var consoleOpen = false
    /// Placeholder for now — the reference design's "подробно" toggle gates
    /// extra detail in each log line; wire it up if/when that's wanted.
    @State private var verbose = false
    @State private var logs: [LogLine] = []
    @State private var ringPulse = false

    @State private var availState: CheckState = .idle
    @State private var availMessage = ""

    /// nil = "add" sheet (auto-detect target from the pasted link).
    /// non-nil = "edit" sheet for that specific profile (opened via pencil).
    @State private var editTarget: TransportKind?
    @State private var addLinkInput = ""
    @State private var addLinkInput2 = ""
    @State private var addToken = ""
    @State private var addUserId = ""
    @State private var addTestState: CheckState = .idle
    @State private var addTestMessage = ""

    private enum CheckState { case idle, pending, ok, fail }

    private struct LogLine: Identifiable {
        let id = UUID()
        let time: String
        let text: String
        let kind: Kind
        enum Kind { case info, ok, fail }
    }

    private var active: TransportKind { TransportKind(rawValue: activeRaw) ?? .mail }
    private var powerRingPulsing: Bool { vpn.status == "Connecting…" || vpn.status == "Reasserting…" }

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 22) {
                        hero
                        availabilityCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                }
                logDock
            }
        }
        .onChange(of: powerRingPulsing) { pulsing in ringPulse = pulsing }
        .onChange(of: vpn.status) { status in
            if status == "Connected" { appendLog("System VPN подключён через \(active.title)", kind: .ok) }
            if status.hasPrefix("Error") { appendLog(status, kind: .fail) }
        }
        .sheet(isPresented: $showSettings) { settingsSheet }
        .sheet(isPresented: $showAddEdit) { addEditSheet }
        .sheet(isPresented: $showProfileSwitcher) { profileSwitcherSheet }
        .onAppear {
            if logs.isEmpty { appendLog("OpenFlux готов") }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button { showSettings = true } label: { iconBox(systemName: "gearshape.fill") }
                .accessibilityLabel("Настройки подключения")
            Spacer()
            Text("OpenFlux").font(.ui(.headline, weight: .semibold)).foregroundColor(Theme.ink)
            Spacer()
            Button { editTarget = nil; showAddEdit = true } label: {
                iconBox(systemName: "plus", accent: true)
            }
            .accessibilityLabel("Добавить ссылку конфигурации")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private func iconBox(systemName: String, accent: Bool = false) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(accent ? Theme.accentInk : Theme.ink)
            .frame(width: 38, height: 38)
            .background(accent ? Theme.accent : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accent ? Theme.accent : Theme.border)
            )
    }

    // MARK: - Hero (power control + profile switcher)

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(Theme.accent, lineWidth: 2)
                    .frame(width: 140, height: 140)
                    .scaleEffect(ringPulse ? 1.28 : 0.86)
                    .opacity(ringPulse ? 0 : 0.55)
                    .animation(
                        powerRingPulsing ? .easeOut(duration: 1.6).repeatForever(autoreverses: false) : .default,
                        value: ringPulse
                    )

                Button(action: togglePower) {
                    Image(systemName: "power")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(powerIconColor)
                        .frame(width: 120, height: 120)
                        .background(Circle().fill(powerFillColor))
                        .overlay(Circle().stroke(Theme.border, lineWidth: vpn.active ? 0 : 1.5))
                }
                .buttonStyle(.plain)
                .disabled(!isConfigured(active) && !vpn.active)
            }

            HStack(spacing: 7) {
                Circle().fill(dotColor).frame(width: 8, height: 8)
                Text(statusRu(vpn.status)).font(.ui(.headline, weight: .semibold)).foregroundColor(Theme.ink)
            }

            profileSwitcherTrigger
        }
        .padding(.top, 8)
    }

    private var powerFillColor: Color {
        if vpn.status == "Connected" { return Theme.accent }
        if powerRingPulsing { return Theme.accentWash }
        return Theme.surface2
    }
    private var powerIconColor: Color {
        if vpn.status == "Connected" { return Theme.accentInk }
        if powerRingPulsing { return Theme.accent }
        return Theme.inkFaint
    }
    private var dotColor: Color {
        switch vpn.status {
        case "Connected": return Theme.success
        case "Connecting…", "Reasserting…", "Disconnecting…": return Theme.warning
        default: return Theme.inkFaint
        }
    }

    private func statusRu(_ status: String) -> String {
        switch status {
        case "Connected": return "Подключено"
        case "Connecting…": return "Подключение…"
        case "Disconnecting…": return "Отключение…"
        case "Reasserting…": return "Переустановка…"
        default: return status.hasPrefix("Error") ? status : "Отключено"
        }
    }

    private func togglePower() {
        if vpn.active {
            vpn.stop()
            appendLog("System VPN отключён")
        } else {
            guard isConfigured(active) else { return }
            // Defensive: the in-app SOCKS core and the system VPN can't run
            // together (both use client IP 10.10.10.2) — stop it if a
            // leftover session is somehow still up.
            tunnel.stop()
            appendLog("Поднимаем System VPN через \(active.title)…")
            vpn.start(transport: active.rawValue, url: effectiveURL(for: active),
                      maxToken: maxToken, maxUid: maxUid, dns: dnsSpec, tunnelUDP: tunnelUDP)
        }
    }

    private var profileSwitcherTrigger: some View {
        Button { showProfileSwitcher = true } label: {
            HStack(spacing: 10) {
                avatarChip(active)
                VStack(alignment: .leading, spacing: 2) {
                    Text(active.title).font(.ui(.subheadline, weight: .semibold)).foregroundColor(Theme.ink)
                    HStack(spacing: 5) {
                        Circle().fill(vpn.active ? Theme.success : Theme.inkFaint).frame(width: 6, height: 6)
                        Text(summary(active) + (vpn.active ? " · подключено" : ""))
                            .font(.mono(.footnote)).foregroundColor(Theme.inkMuted).lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.inkFaint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
        }
        .buttonStyle(.plain)
        .disabled(vpn.active)
    }

    private func avatarChip(_ kind: TransportKind) -> some View {
        Text(initials(for: kind))
            .font(.mono(.footnote, weight: .semibold))
            .foregroundColor(Theme.ink)
            .frame(width: 32, height: 32)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    // MARK: - Availability card

    private var availabilityCard: some View {
        VStack(spacing: 10) {
            Button(action: checkAvailability) {
                HStack {
                    Image(systemName: "wifi")
                    Text("Проверить доступность")
                }
                .font(.ui(.subheadline, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundColor(Theme.ink)
            .background(Theme.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))

            if availState != .idle {
                HStack(spacing: 7) {
                    if availState == .pending { ProgressView().scaleEffect(0.7) }
                    Text(availMessage).font(.mono(.footnote))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(availBg)
                .foregroundColor(availFg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
    }

    private var availBg: Color { availState == .ok ? Theme.successWash : availState == .fail ? Theme.dangerWash : Theme.surface2 }
    private var availFg: Color { availState == .ok ? Theme.success : availState == .fail ? Theme.danger : Theme.inkMuted }

    /// Lightweight reachability check (plain HTTPS request to the profile's
    /// own link, or a format check for MAX credentials) — pure Swift/UI
    /// side, does not start the tunnel or touch the Go core.
    private func checkAvailability() {
        let kind = active
        availState = .pending
        availMessage = "проверка ссылки и доступности сервера…"

        if kind == .max {
            let ok = !maxToken.isEmpty && !maxUid.isEmpty && maxUid.allSatisfy(\.isNumber)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                availState = ok ? .ok : .fail
                availMessage = ok ? "OK — токен и ID заполнены корректно" : "Ошибка — заполните токен и числовой ID"
                appendLog(ok ? "проверка MAX прошла успешно" : "проверка MAX не пройдена", kind: ok ? .ok : .fail)
            }
            return
        }

        let firstLink = effectiveURL(for: kind).split(separator: ",").first.map(String.init) ?? ""
        guard let url = URL(string: firstLink), url.scheme?.hasPrefix("http") == true else {
            availState = .fail
            availMessage = "Ошибка — ссылка не является корректным URL"
            appendLog("проверка \(kind.title) не пройдена: некорректная ссылка", kind: .fail)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, error == nil {
                    availState = .ok
                    availMessage = "OK — сервер отвечает (HTTP \(http.statusCode))"
                    appendLog("проверка \(kind.title) прошла успешно (HTTP \(http.statusCode))", kind: .ok)
                } else {
                    availState = .fail
                    availMessage = "Ошибка — сервер недоступен: \(error?.localizedDescription ?? "нет ответа")"
                    appendLog("проверка \(kind.title) не пройдена", kind: .fail)
                }
            }
        }.resume()
    }

    // MARK: - Log dock

    private var logDock: some View {
        VStack(spacing: 0) {
            if consoleOpen {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(logs) { line in
                                (Text(line.time).bold() + Text(" " + line.text))
                                    .font(.mono(.footnote))
                                    .foregroundColor(logColor(line.kind))
                            }
                            .id("logbottom")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: logs.count) { _ in
                        withAnimation { proxy.scrollTo("logbottom", anchor: .bottom) }
                    }
                }
                .frame(height: 190)
                .background(Theme.surface2)
            }
            Button {
                withAnimation { consoleOpen.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(consoleOpen ? 180 : 0))
                        .font(.system(size: 12, weight: .semibold))
                    Text("Лог").font(.ui(.footnote, weight: .semibold))
                    Text(logs.last?.text ?? "приложение готово")
                        .font(.mono(.footnote)).lineLimit(1).truncationMode(.tail)
                    Spacer()
                    Text("подробно").font(.ui(.caption)).foregroundColor(Theme.inkMuted)
                    Toggle("", isOn: $verbose)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                        .scaleEffect(0.8)
                }
                .foregroundColor(Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private func logColor(_ kind: LogLine.Kind) -> Color {
        switch kind {
        case .ok: return Theme.success
        case .fail: return Theme.danger
        case .info: return Theme.inkMuted
        }
    }

    private func appendLog(_ text: String, kind: LogLine.Kind = .info) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        logs.append(LogLine(time: f.string(from: Date()), text: text, kind: kind))
        if logs.count > 200 { logs.removeFirst(logs.count - 200) }
    }

    // MARK: - Settings sheet

    private var dnsSpec: String {
        switch dnsPreset {
        case "cloudflare": return "1.1.1.1@cloudflare-dns.com"
        case "google":     return "8.8.8.8@dns.google"
        case "quad9":      return "9.9.9.9@dns.quad9.net"
        case "adguard":    return "94.140.14.14@dns.adguard-dns.com"
        case "custom":     return dnsCustom.trimmingCharacters(in: .whitespaces)
        default:           return ""
        }
    }

    private var settingsSheet: some View {
        NavigationView {
            Form {
                Section("Общие для всех профилей") {
                    HStack {
                        Text("Локальный порт SOCKS5")
                        Spacer()
                        TextField("10808", text: $socksPort)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    Picker("DNS (DNS-over-TLS)", selection: $dnsPreset) {
                        Text("По умолчанию").tag("default")
                        Text("Cloudflare").tag("cloudflare")
                        Text("Google").tag("google")
                        Text("Quad9").tag("quad9")
                        Text("AdGuard").tag("adguard")
                        Text("Свой…").tag("custom")
                    }
                    if dnsPreset == "custom" {
                        TextField("1.1.1.1@cloudflare-dns.com", text: $dnsCustom)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(.mono(.body))
                    }
                    Toggle("Туннелировать UDP / QUIC", isOn: $tunnelUDP)
                    Text("Выкл — QUIC идёт через TCP (работает везде). Вкл — нужен узел с поддержкой UDP.")
                        .font(.caption).foregroundColor(.secondary)
                }
                Section {
                    Button("О приложении") { showInfo = true }
                }
            }
            .navigationTitle("Настройки подключения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { showSettings = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showInfo) { InfoView() }
    }

    // MARK: - Profile switcher sheet

    private var profileSwitcherSheet: some View {
        // Hand-rolled rows (matching the card style used everywhere else in
        // this screen) instead of a system List — a plain List keeps its own
        // white background/system row chrome no matter what colors you feed
        // its rows, which stood out against the rest of the themed UI.
        VStack(spacing: 0) {
            Text("Профили")
                .font(.ui(.headline, weight: .semibold))
                .foregroundColor(Theme.ink)
                .padding(.top, 18)
                .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(TransportKind.allCases) { kind in
                        // Two SIBLING buttons, not one nested inside the
                        // other's label — nested Buttons inside the same row
                        // don't reliably receive independent taps in SwiftUI.
                        HStack(spacing: 10) {
                            Button {
                                activeRaw = kind.rawValue
                                showProfileSwitcher = false
                                appendLog("выбран профиль: \(kind.title)")
                            } label: {
                                HStack(spacing: 10) {
                                    avatarChip(kind)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(kind.title).font(.ui(.subheadline, weight: .semibold)).foregroundColor(Theme.ink)
                                        Text(summary(kind)).font(.mono(.footnote)).foregroundColor(Theme.inkMuted)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                editTarget = kind
                                showProfileSwitcher = false
                                showAddEdit = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundColor(Theme.inkMuted)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(kind == active ? Theme.accentWash : Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.ground)
        .presentationDetents([.height(360), .medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Add / edit sheet

    private var isCredentialsMode: Bool { editTarget == .max }
    private var detectedAutoKind: TransportKind? { editTarget == nil ? detectProfile(for: addLinkInput) : nil }
    private var yandexFieldsVisible: Bool { (editTarget ?? detectedAutoKind) == .yandex }

    private var detectionChip: (text: String, ok: Bool)? {
        if isCredentialsMode { return ("Профиль: MAX", true) }
        let trimmed = addLinkInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let valid = URL(string: trimmed)?.scheme?.hasPrefix("http") == true
        if let target = editTarget {
            return valid ? ("Профиль: \(target.title)", true) : ("Некорректная ссылка", false)
        }
        if !valid { return ("Некорректная ссылка", false) }
        if let d = detectedAutoKind { return ("Определён профиль: \(d.title)", true) }
        return ("Домен не распознан — профиль не будет назначен автоматически", false)
    }

    private var canTestAdd: Bool {
        isCredentialsMode
            ? !addToken.isEmpty && !addUserId.isEmpty
            : URL(string: addLinkInput.trimmingCharacters(in: .whitespaces))?.scheme?.hasPrefix("http") == true
    }
    private var canSaveAdd: Bool {
        if isCredentialsMode { return !addToken.isEmpty && !addUserId.isEmpty && addUserId.allSatisfy(\.isNumber) }
        guard URL(string: addLinkInput.trimmingCharacters(in: .whitespaces))?.scheme?.hasPrefix("http") == true else { return false }
        return editTarget != nil || detectedAutoKind != nil
    }

    private var addEditSheet: some View {
        NavigationView {
            Form {
                if isCredentialsMode {
                    Section {
                        TextField("auth token", text: $addToken)
                            .textInputAutocapitalization(.never).autocorrectionDisabled(true)
                            .font(.mono(.body))
                        TextField("numeric id", text: $addUserId)
                            .keyboardType(.numberPad)
                            .font(.mono(.body))
                    }
                } else {
                    Section {
                        TextField("https://…", text: $addLinkInput)
                            .textInputAutocapitalization(.never).autocorrectionDisabled(true)
                            .keyboardType(.URL)
                            .font(.mono(.body))
                        Button {
                            addLinkInput = UIPasteboard.general.string ?? addLinkInput
                        } label: {
                            Label("Вставить из буфера", systemImage: "doc.on.clipboard")
                        }
                    }
                    if yandexFieldsVisible {
                        Section {
                            TextField("второй документ (опционально)", text: $addLinkInput2)
                                .textInputAutocapitalization(.never).autocorrectionDisabled(true)
                                .font(.mono(.body))
                            Text("Два документа работают параллельно для скорости и отказоустойчивости. Exit-node должен обслуживать оба.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

                if let chip = detectionChip {
                    Section {
                        Label(chip.text, systemImage: chip.ok ? "checkmark.circle.fill" : "questionmark.circle.fill")
                            .foregroundColor(chip.ok ? Theme.accent : Theme.warning)
                    }
                }

                if addTestState != .idle {
                    Section {
                        HStack(spacing: 7) {
                            if addTestState == .pending { ProgressView().scaleEffect(0.7) }
                            Text(addTestMessage).font(.mono(.footnote))
                        }
                    }
                }

                Section {
                    Button("Тест соединения") { runAddSheetTest() }.disabled(!canTestAdd)
                    Button(editTarget == nil ? "Сохранить" : "Обновить профиль") { saveAddSheet() }
                        .disabled(!canSaveAdd)
                }
            }
            .navigationTitle(editTarget == nil ? "Добавить ссылку" : "Изменить — \(editTarget!.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { showAddEdit = false }
                }
            }
            .onAppear(perform: prefillAddSheet)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func prefillAddSheet() {
        addTestState = .idle
        addTestMessage = ""
        if let target = editTarget {
            if target == .max {
                addToken = maxToken
                addUserId = maxUid
            } else {
                addLinkInput = linkBinding(for: target).wrappedValue
                addLinkInput2 = target == .yandex ? docURL2 : ""
            }
        } else {
            addLinkInput = ""
            addLinkInput2 = ""
        }
    }

    private func runAddSheetTest() {
        addTestState = .pending
        addTestMessage = "проверка токена и доступности сервера…"
        if isCredentialsMode {
            let ok = !addToken.isEmpty && !addUserId.isEmpty && addUserId.allSatisfy(\.isNumber)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                addTestState = ok ? .ok : .fail
                addTestMessage = ok ? "OK — токен и ID заполнены корректно" : "Ошибка — заполните токен и числовой ID"
            }
            return
        }
        guard let url = URL(string: addLinkInput.trimmingCharacters(in: .whitespaces)) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, error == nil {
                    addTestState = .ok
                    addTestMessage = "OK — сервер доступен (HTTP \(http.statusCode))"
                } else {
                    addTestState = .fail
                    addTestMessage = "Ошибка — сервер недоступен"
                }
            }
        }.resume()
    }

    private func saveAddSheet() {
        if isCredentialsMode {
            maxToken = addToken
            maxUid = addUserId
            appendLog("данные MAX обновлены")
        } else if let target = editTarget {
            linkBinding(for: target).wrappedValue = addLinkInput.trimmingCharacters(in: .whitespaces)
            if target == .yandex { docURL2 = addLinkInput2.trimmingCharacters(in: .whitespaces) }
            appendLog("ссылка обновлена для \(target.title)")
        } else if let target = detectedAutoKind {
            linkBinding(for: target).wrappedValue = addLinkInput.trimmingCharacters(in: .whitespaces)
            if target == .yandex { docURL2 = addLinkInput2.trimmingCharacters(in: .whitespaces) }
            activeRaw = target.rawValue
            appendLog("добавлена ссылка для \(target.title)")
        }
        showAddEdit = false
    }

    // MARK: - Per-profile helpers

    private func linkBinding(for kind: TransportKind) -> Binding<String> {
        switch kind {
        case .yandex: return $docURL
        case .volga:  return $volgaURL
        case .mail:   return $mailURL
        case .max:    return .constant("")
        }
    }

    private func initials(for kind: TransportKind) -> String {
        switch kind {
        case .yandex: return "Я"
        case .volga:  return "V"
        case .mail:   return "M"
        case .max:    return "X"
        }
    }

    private func domains(for kind: TransportKind) -> [String] {
        switch kind {
        case .yandex: return ["docs.yandex.ru", "docs.yandex.net"]
        case .volga:  return ["disk.yandex.ru"]
        case .mail:   return ["cloud.mail.ru", "mail.ru"]
        case .max:    return []
        }
    }

    private func isConfigured(_ kind: TransportKind) -> Bool {
        switch kind {
        case .yandex: return !docURL.trimmingCharacters(in: .whitespaces).isEmpty
        case .volga:  return !volgaURL.trimmingCharacters(in: .whitespaces).isEmpty
        case .mail:   return !mailURL.trimmingCharacters(in: .whitespaces).isEmpty
        case .max:    return !maxToken.isEmpty && !maxUid.isEmpty
        }
    }

    private func summary(_ kind: TransportKind) -> String {
        if kind == .max {
            return maxUid.isEmpty ? "не настроено" : "ID •••\(maxUid.suffix(4))"
        }
        let link = linkBinding(for: kind).wrappedValue.trimmingCharacters(in: .whitespaces)
        guard !link.isEmpty, let host = URL(string: link)?.host else { return "не настроено" }
        return host
    }

    /// Document URL(s) handed to the Go core — Yandex may join a second
    /// parallel document with a comma, same convention the bridge already
    /// expects (see `TunnelController`/`PacketTunnelProvider`).
    private func effectiveURL(for kind: TransportKind) -> String {
        switch kind {
        case .yandex:
            let a = docURL.trimmingCharacters(in: .whitespaces)
            let b = docURL2.trimmingCharacters(in: .whitespaces)
            return b.isEmpty ? a : "\(a),\(b)"
        case .volga: return volgaURL.trimmingCharacters(in: .whitespaces)
        case .mail:  return mailURL.trimmingCharacters(in: .whitespaces)
        case .max:   return ""
        }
    }

    private func detectProfile(for link: String) -> TransportKind? {
        guard let host = URL(string: link.trimmingCharacters(in: .whitespaces))?.host?.lowercased() else { return nil }
        for kind in [TransportKind.yandex, .volga, .mail] {
            if domains(for: kind).contains(where: { host == $0 || host.hasSuffix(".\($0)") }) {
                return kind
            }
        }
        return nil
    }
}

#Preview {
    ContentView()
}
