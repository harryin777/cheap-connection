//
//  MainView.swift
//  cheap-connection
//
//  主视图 - 应用主界面
//

import SwiftUI
import AppKit

/// 主视图
struct MainView: View {
    @Environment(ConnectionManager.self) private var connectionManager
    @State private var sidebarWidth: CGFloat
    @State private var fixedWorkspaceConnectionId: UUID?
    @State private var fixedWorkspaceId = UUID()

    init() {
        let savedWidth = WindowStateRepository.shared.load().sidebarWidth ?? 280
        _sidebarWidth = State(initialValue: savedWidth)
    }

    var body: some View {
        NavigationSplitView {
            ConnectionListView()
                .frame(minWidth: 220, idealWidth: sidebarWidth, maxWidth: 400)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .alert("错误", isPresented: .init(
            get: { connectionManager.errorMessage != nil },
            set: { if !$0 { connectionManager.clearError() } }
        )) {
            Button("确定", role: .cancel) {
                connectionManager.clearError()
            }
        } message: {
            if let error = connectionManager.errorMessage {
                Text(error)
            }
        }
        .onChange(of: sidebarWidth) { _, newWidth in
            saveSidebarWidth(newWidth)
        }
        .task {
            syncFixedWorkspaceConnection()
        }
        .onChange(of: connectionManager.connections.map(\.id)) { _, _ in
            syncFixedWorkspaceConnection()
        }
        .background(SidebarWidthObserver(width: $sidebarWidth))
    }

    private func saveSidebarWidth(_ width: CGFloat) {
        var state = WindowStateRepository.shared.load()
        state.sidebarWidth = width
        WindowStateRepository.shared.save(state)
    }

    // MARK: - Private

    @ViewBuilder
    private var detailView: some View {
        if let connectionConfig = fixedMySQLWorkspaceConnection {
            MySQLWorkspaceView(
                connectionConfig: connectionConfig,
                workspaceId: fixedWorkspaceId
            )
            .id(fixedWorkspaceId)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            emptyStateView
        }
    }

    private var fixedMySQLWorkspaceConnection: ConnectionConfig? {
        guard let fixedWorkspaceConnectionId else { return nil }
        return connectionManager.connections.first {
            $0.id == fixedWorkspaceConnectionId && $0.databaseKind == .mysql
        }
    }

    private func syncFixedWorkspaceConnection() {
        if let fixedWorkspaceConnectionId,
           connectionManager.connections.contains(where: {
               $0.id == fixedWorkspaceConnectionId && $0.databaseKind == .mysql
           }) {
            return
        }

        fixedWorkspaceConnectionId = connectionManager.connections
            .first(where: { $0.databaseKind == .mysql })?
            .id
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("暂无 MySQL 工作区")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("请先创建至少一个 MySQL 连接。右侧固定工作区只使用 MySQL 面板。")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sidebar Width Observer

/// 侧边栏宽度观察器 - 使用 NSSplitView 监听侧边栏宽度变化
struct SidebarWidthObserver: NSViewRepresentable {
    @Binding var width: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = SidebarObserverNSView()
        view.onWidthChange = { newWidth in
            DispatchQueue.main.async {
                if abs(self.width - newWidth) > 1 {
                    self.width = newWidth
                }
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let observerView = nsView as? SidebarObserverNSView {
            observerView.onWidthChange = { newWidth in
                DispatchQueue.main.async {
                    if abs(self.width - newWidth) > 1 {
                        self.width = newWidth
                    }
                }
            }
        }
    }
}

/// 自定义 NSView 用于监听 NavigationSplitView 侧边栏宽度变化
class SidebarObserverNSView: NSView {
    var onWidthChange: ((CGFloat) -> Void)?
    private var debounceTimer: Timer?
    private var lastWidth: CGFloat?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupSplitViewObserver()
    }

    private func setupSplitViewObserver() {
        // 查找父视图中的 NSSplitView
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.findAndObserveSplitView(in: self?.window?.contentView)
        }
    }

    private func findAndObserveSplitView(in view: NSView?) {
        guard let view = view else { return }

        for subview in view.subviews {
            if let splitView = subview as? NSSplitView {
                observeSplitView(splitView)
                return
            }
            findAndObserveSplitView(in: subview)
        }
    }

    private func observeSplitView(_ splitView: NSSplitView) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(splitViewDidResize(_:)),
            name: NSSplitView.didResizeSubviewsNotification,
            object: splitView
        )
    }

    @objc private func splitViewDidResize(_ notification: Notification) {
        guard let splitView = notification.object as? NSSplitView else { return }
        guard let sidebarView = splitView.arrangedSubviews.first else { return }

        let _ = sidebarView.bounds.width  // 触发 resize 事件

        // 防抖
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
            guard let self = self,
                  let contentView = self.window?.contentView,
                  let splitView = contentView.findSplitView(),
                  let sidebarView = splitView.arrangedSubviews.first else { return }

            let currentWidth = sidebarView.bounds.width
            if self.lastWidth != currentWidth {
                self.lastWidth = currentWidth
                self.onWidthChange?(currentWidth)
            }
        }
    }

    deinit {
        debounceTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - NSView Extension

private extension NSView {
    func findSplitView() -> NSSplitView? {
        for subview in subviews {
            if let splitView = subview as? NSSplitView {
                return splitView
            }
            if let found = subview.findSplitView() {
                return found
            }
        }
        return nil
    }
}

#Preview {
    MainView()
        .environment(ConnectionManager.shared)
}
