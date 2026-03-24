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
        .frame(width: 480, height: 400)
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
        Form {
            Section("日志设置") {
                Toggle("启用日志", isOn: $settings.loggingEnabled)

                Picker("日志级别", selection: $settings.minimumLogLevel) {
                    Text("Debug").tag(0)
                    Text("Info").tag(1)
                    Text("Warning").tag(2)
                    Text("Error").tag(3)
                }
                .disabled(!settings.loggingEnabled)
            }

            Section {
                Text("Debug 模式下会输出详细日志，包括文件名和行号。\n生产环境建议使用 Info 或以上级别。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
