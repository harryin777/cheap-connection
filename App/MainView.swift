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
        // NOTE: detail 区由 connectionManager.selectedConnectionId 决定
        // 这控制的是左侧资源树高亮连接对应的 workspace 显示
        // Query 执行上下文由 MySQLWorkspaceView 中的 EditorQueryTab 独立管理
        if let selectedId = connectionManager.selectedConnectionId,
           let config = connectionManager.connections.first(where: { $0.id == selectedId }) {
            ConnectionDetailView(config: config)
        } else {
            emptyStateView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("选择一个连接")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("从左侧列表选择一个数据库连接，或创建新连接")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 连接详情视图
struct ConnectionDetailView: View {
    let config: ConnectionConfig

    var body: some View {
        switch config.databaseKind {
        case .mysql:
            MySQLWorkspaceView(connectionConfig: config)
        case .redis:
            RedisWorkspaceView(connectionConfig: config)
        }
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

        let newWidth = sidebarView.bounds.width

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
        .environment(ConnectionManager())
}
