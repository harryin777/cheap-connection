//
//  cheap_connectionApp.swift
//  cheap-connection
//
//  Created by harry on 2026/3/10.
//

import SwiftUI
import Combine

@main
struct cheap_connectionApp: App {
    @State private var connectionManager = ConnectionManager.shared
    @State private var windowState = WindowStateRepository.shared.load()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(connectionManager)
                .frame(
                    minWidth: 800,
                    idealWidth: windowState.windowWidth ?? 1100,
                    minHeight: 500,
                    idealHeight: windowState.windowHeight ?? 700
                )
                .background(WindowPositionObserver(
                    windowX: Binding(
                        get: { windowState.windowX },
                        set: { windowState.windowX = $0 }
                    ),
                    windowY: Binding(
                        get: { windowState.windowY },
                        set: { windowState.windowY = $0 }
                    ),
                    windowWidth: Binding(
                        get: { windowState.windowWidth },
                        set: { windowState.windowWidth = $0 }
                    ),
                    windowHeight: Binding(
                        get: { windowState.windowHeight },
                        set: { windowState.windowHeight = $0 }
                    )
                ))
        }
        .defaultSize(
            width: windowState.windowWidth ?? 1100,
            height: windowState.windowHeight ?? 700
        )
        .commands {
            // File 菜单
            CommandGroup(replacing: .newItem) {
                Button("新建连接...") {
                    KeyboardShortcutNotifier.notifyCreateConnection()
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("打开 SQL 文件...") {
                    KeyboardShortcutNotifier.notifyOpenSQLFile()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("保存 SQL 文件...") {
                    KeyboardShortcutNotifier.notifySaveSQLFile()
                }
                .keyboardShortcut("s", modifiers: .command)
            }

            // View 菜单 - 添加查询相关命令
            CommandGroup(after: .toolbar) {
                Button("执行 SQL") {
                    KeyboardShortcutNotifier.notifyExecuteSQL()
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button("刷新数据") {
                    KeyboardShortcutNotifier.notifyRefreshData()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("清空编辑器") {
                    KeyboardShortcutNotifier.notifyClearEditor()
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("切换历史面板") {
                    KeyboardShortcutNotifier.notifyToggleHistory()
                }
                .keyboardShortcut("h", modifiers: .command)
            }
        }
        .onChange(of: windowState) { _, newState in
            WindowStateRepository.shared.save(newState)
        }

        // 设置窗口
        Settings {
            SettingsView()
        }
    }
}

// MARK: - Window Position Observer

/// 窗口位置/大小观察器 - 使用 NSViewRepresentable 监听窗口变化
struct WindowPositionObserver: NSViewRepresentable {
    @Binding var windowX: CGFloat?
    @Binding var windowY: CGFloat?
    @Binding var windowWidth: CGFloat?
    @Binding var windowHeight: CGFloat?

    func makeNSView(context: Context) -> NSView {
        let view = WindowObserverView()
        let coordinator = context.coordinator
        view.onWindowChange = { frame in
            DispatchQueue.main.async {
                // 只在值真正变化时更新，避免循环
                if coordinator.lastFrame != frame {
                    coordinator.lastFrame = frame
                    self.windowX = frame.origin.x
                    self.windowY = frame.origin.y
                    self.windowWidth = frame.size.width
                    self.windowHeight = frame.size.height
                }
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let observerView = nsView as? WindowObserverView {
            let coordinator = context.coordinator
            observerView.onWindowChange = { frame in
                DispatchQueue.main.async {
                    if coordinator.lastFrame != frame {
                        coordinator.lastFrame = frame
                        self.windowX = frame.origin.x
                        self.windowY = frame.origin.y
                        self.windowWidth = frame.size.width
                        self.windowHeight = frame.size.height
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var lastFrame: CGRect?
    }
}

/// 自定义 NSView 用于监听窗口变化
class WindowObserverView: NSView {
    var onWindowChange: ((CGRect) -> Void)?
    private var debounceTimer: Timer?
    private var lastNotifiedFrame: CGRect?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)

        guard let window = window else { return }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: window
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: window
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }

    @objc private func windowDidResize(_ notification: Notification) {
        notifyWindowChange()
    }

    @objc private func windowDidMove(_ notification: Notification) {
        notifyWindowChange()
    }

    @objc private func windowWillClose(_ notification: Notification) {
        // 窗口关闭时立即保存
        debounceTimer?.invalidate()
        if let window = window {
            _ = window.frame
            onWindowChange?(window.frame)
        }
    }

    private func notifyWindowChange() {
        guard window != nil else { return }

        // 防抖 - 避免频繁保存
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self = self, let window = self.window else { return }
            let currentFrame = window.frame

            // 只在 frame 真正变化时通知
            if self.lastNotifiedFrame != currentFrame {
                self.lastNotifiedFrame = currentFrame
                self.onWindowChange?(currentFrame)
            }
        }
    }

    deinit {
        debounceTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - App Settings

/// 应用设置
struct AppSettings: Codable, Equatable {
    var defaultRowLimit: Int
    var connectionTimeout: Int
    var queryTimeout: Int
    var dataViewFontSize: Int
    var editorFontSize: Int
    var connectionTreeFontSize: Int
    var redisConsoleFontSize: Int
    var tabBarFontSize: Int
    var loggingEnabled: Bool
    var minimumLogLevel: Int

    static let `default` = AppSettings(
        defaultRowLimit: 500,
        connectionTimeout: 30,
        queryTimeout: 60,
        dataViewFontSize: 12,
        editorFontSize: 13,
        connectionTreeFontSize: 13,
        redisConsoleFontSize: 12,
        tabBarFontSize: 11,
        loggingEnabled: true,
        minimumLogLevel: 1
    )
}

// MARK: - Settings Repository

/// 设置存储仓库
final class SettingsRepository: ObservableObject, @unchecked Sendable {
    static let shared = SettingsRepository()

    @Published var settings: AppSettings
    private let fileName = "settings.json"
    private let fileManager = FileManager.default
    private var saveTask: Task<Void, Never>?

    private var storageDirectory: URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory())
        }
        let bundleId = Bundle.main.bundleIdentifier ?? "com.yzz.cheap-connection"
        return appSupport.appendingPathComponent(bundleId)
    }

    private var storageFile: URL {
        storageDirectory.appendingPathComponent(fileName)
    }

    private init() {
        self.settings = Self.loadFromFile() ?? .default
        ensureDirectoryExists()
    }

    func update(_ newSettings: AppSettings) {
        settings = newSettings
        scheduleSave()
    }

    func saveSync() {
        writeSettings(settings)
    }

    private static func loadFromFile() -> AppSettings? {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let bundleId = Bundle.main.bundleIdentifier ?? "com.yzz.cheap-connection"
        let fileURL = appSupport.appendingPathComponent(bundleId).appendingPathComponent("settings.json")

        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return nil
        }
    }

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                writeSettings(settings)
            }
        }
    }

    private func writeSettings(_ settings: AppSettings) {
        ensureDirectoryExists()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(settings)
            try data.write(to: storageFile, options: .atomic)
        } catch { }
    }
}

// MARK: - Theme Palette

/// 统一主题调色板。
/// 当前先提供一套接近 DataGrip Dark 的配色，后续如需支持多主题，只需要在这里新增 palette 并切换 current。
struct AppThemePalette {
    let sqlKeywordNSColor: NSColor
    let sqlCommentNSColor: NSColor
    let sqlStringNSColor: NSColor
    let resultHeaderColor: Color

    static let dataGripDark = AppThemePalette(
        sqlKeywordNSColor: NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.32, alpha: 1.0),
        sqlCommentNSColor: NSColor(calibratedRed: 0.42, green: 0.62, blue: 0.46, alpha: 1.0),
        sqlStringNSColor: NSColor(calibratedRed: 0.47, green: 0.72, blue: 0.80, alpha: 1.0),
        resultHeaderColor: Color(red: 0.42, green: 0.74, blue: 0.95)
    )
}

enum AppTheme {
    static var current: AppThemePalette { .dataGripDark }
}

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var repository = SettingsRepository.shared
    @State private var settings: AppSettings

    init() {
        _settings = State(initialValue: SettingsRepository.shared.settings)
    }

    var body: some View {
        TabView {
            GeneralSettingsTab(settings: $settings)
                .tabItem { Label("通用", systemImage: "gearshape") }

            AppearanceSettingsTab(settings: $settings)
                .tabItem { Label("外观", systemImage: "paintbrush") }

            LoggingSettingsTab(settings: $settings)
                .tabItem { Label("日志", systemImage: "doc.text") }
        }
        .frame(width: 750, height: 500)
        .onChange(of: settings) { _, newSettings in
            repository.update(newSettings)
        }
    }
}

struct GeneralSettingsTab: View {
    @Binding var settings: AppSettings

    var body: some View {
        Form {
            Section("数据设置") {
                HStack {
                    Text("默认行数限制")
                    Spacer()
                    TextField("", value: $settings.defaultRowLimit, formatter: NumberFormatter())
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Stepper("", value: $settings.defaultRowLimit, in: 100...5000, step: 100)
                        .labelsHidden()
                }

                HStack {
                    Text("连接超时（秒）")
                    Spacer()
                    TextField("", value: $settings.connectionTimeout, formatter: NumberFormatter())
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Stepper("", value: $settings.connectionTimeout, in: 5...120, step: 5)
                        .labelsHidden()
                }

                HStack {
                    Text("查询超时（秒）")
                    Spacer()
                    TextField("", value: $settings.queryTimeout, formatter: NumberFormatter())
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    Stepper("", value: $settings.queryTimeout, in: 10...300, step: 10)
                        .labelsHidden()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AppearanceSettingsTab: View {
    @Binding var settings: AppSettings

    var body: some View {
        Form {
            Section("字体大小") {
                FontSizeRow(title: "数据返回区", size: $settings.dataViewFontSize)
                FontSizeRow(title: "SQL 编辑区", size: $settings.editorFontSize)
                FontSizeRow(title: "连接树", size: $settings.connectionTreeFontSize)
                FontSizeRow(title: "Redis 控制台", size: $settings.redisConsoleFontSize)
                FontSizeRow(title: "标签栏/状态栏", size: $settings.tabBarFontSize)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct FontSizeRow: View {
    let title: String
    @Binding var size: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", value: $size, formatter: NumberFormatter())
                .frame(width: 50)
                .multilineTextAlignment(.trailing)
            Stepper("", value: $size, in: 8...24, step: 1)
                .labelsHidden()
            Text("pt")
                .foregroundStyle(.secondary)
        }
    }
}

struct LoggingSettingsTab: View {
    @Binding var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            // 日志设置区域
            HStack(spacing: 16) {
                Toggle("启用日志", isOn: $settings.loggingEnabled)

                Picker("最小日志级别", selection: $settings.minimumLogLevel) {
                    Text("Debug").tag(0)
                    Text("Info").tag(1)
                    Text("Warning").tag(2)
                    Text("Error").tag(3)
                }
                .frame(width: 100)
                .disabled(!settings.loggingEnabled)

                Spacer()

                Text("Debug 模式下会输出详细日志，包括文件名和行号")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 日志面板
            LogPanelView()
        }
    }
}

// MARK: - Log Panel View

/// 日志面板视图 - 显示运行时日志，支持过滤和搜索
struct LogPanelView: View {
    @State private var entries: [LogEntry] = []
    @State private var searchText = ""
    @State private var selectedLevel: LogLevel?
    @State private var selectedCategory: LogCategory?
    @State private var isAutoRefresh = true
    @State private var refreshTimer: Timer?

    private var filteredEntries: [LogEntry] {
        var result = entries

        // 按级别过滤
        if let level = selectedLevel {
            result = result.filter { $0.level == level }
        }

        // 按分类过滤
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // 按搜索文本过滤
        if !searchText.isEmpty {
            result = result.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                (entry.metadata?.values.contains { $0.localizedCaseInsensitiveContains(searchText) } ?? false)
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbarView
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 日志列表
            if filteredEntries.isEmpty {
                emptyStateView
            } else {
                logListView
            }
        }
        .onAppear {
            refreshLogs()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: 12) {
            // 搜索框
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索日志...", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 150)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(4)

            // 级别过滤
            Picker("级别", selection: $selectedLevel) {
                Text("全部").tag(nil as LogLevel?)
                Text("Debug").tag(LogLevel?.some(.debug))
                Text("Info").tag(LogLevel?.some(.info))
                Text("Warning").tag(LogLevel?.some(.warning))
                Text("Error").tag(LogLevel?.some(.error))
            }
            .frame(width: 100)
            .labelsHidden()

            // 分类过滤
            Picker("分类", selection: $selectedCategory) {
                Text("全部").tag(nil as LogCategory?)
                Text("连接").tag(LogCategory?.some(.connection))
                Text("查询").tag(LogCategory?.some(.query))
                Text("命令").tag(LogCategory?.some(.command))
                Text("缓存").tag(LogCategory?.some(.cache))
                Text("存储").tag(LogCategory?.some(.storage))
                Text("UI").tag(LogCategory?.some(.ui))
                Text("通用").tag(LogCategory?.some(.general))
            }
            .frame(width: 90)
            .labelsHidden()

            Spacer()

            // 自动刷新开关
            Toggle("自动刷新", isOn: $isAutoRefresh)
                .toggleStyle(.checkbox)
                .onChange(of: isAutoRefresh) { _, newValue in
                    if newValue {
                        startAutoRefresh()
                    } else {
                        stopAutoRefresh()
                    }
                }

            // 刷新按钮
            Button(action: refreshLogs) {
                Image(systemName: "arrow.clockwise")
            }
            .help("刷新日志")

            // 清空按钮
            Button(action: clearLogs) {
                Image(systemName: "trash")
            }
            .help("清空日志")
        }
    }

    // MARK: - Log List

    private var logListView: some View {
        Table(filteredEntries) {
            TableColumn("时间") { entry in
                Text(formatTimestamp(entry.timestamp))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 85, max: 100)

            TableColumn("级别") { entry in
                levelBadge(entry.level)
            }
            .width(min: 60, max: 70)

            TableColumn("分类") { entry in
                Text(entry.category.rawValue)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, max: 90)

            TableColumn("消息") { entry in
                LogMessageCell(entry: entry)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(entries.isEmpty ? "暂无日志" : "没有匹配的日志")
                .font(.headline)
                .foregroundStyle(.secondary)

            if !entries.isEmpty {
                Button("清除过滤条件") {
                    searchText = ""
                    selectedLevel = nil
                    selectedCategory = nil
                }
                .buttonStyle(.link)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Level Badge

    @ViewBuilder
    private func levelBadge(_ level: LogLevel) -> some View {
        Text(level.rawValue)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(levelColor(level))
            .foregroundColor(.white)
            .cornerRadius(3)
    }

    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .debug:
            return .gray
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    // MARK: - Helpers

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    private func refreshLogs() {
        entries = SimpleLogCollector.shared.getAll()
    }

    private func clearLogs() {
        SimpleLogCollector.shared.clear()
        entries = []
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                refreshLogs()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Log Message Cell

struct LogMessageCell: View {
    let entry: LogEntry
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 主消息
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(isExpanded ? nil : 2)
                .textSelection(.enabled)

            // 元数据
            if let metadata = entry.metadata, !metadata.isEmpty {
                if isExpanded || isHovered {
                    metadataView(metadata)
                }
            }

            // 源文件信息 (仅 Debug 模式)
            #if DEBUG
            if isExpanded {
                if let file = entry.file, let line = entry.line {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 9))
                        Text("\(URL(fileURLWithPath: file).lastPathComponent):\(line)")
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundStyle(.tertiary)
                }
            }
            #endif
        }
        .padding(.vertical, 2)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(count: 2) {
            isExpanded.toggle()
        }
    }

    private func metadataView(_ metadata: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack(spacing: 4) {
                    Text(key + ":")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.top, 2)
    }
}
