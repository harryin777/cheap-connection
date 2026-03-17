//
//  cheap_connectionApp.swift
//  cheap-connection
//
//  Created by harry on 2026/3/10.
//

import SwiftUI

@main
struct cheap_connectionApp: App {
    @State private var connectionManager = ConnectionManager()
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
        guard let window = window else { return }
        let frame = window.frame

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
