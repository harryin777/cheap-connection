//
//  RedisWorkspaceView.swift
//  cheap-connection
//
//  Redis 工作区视图 - DataGrip 风格布局（与 MySQL 一致）
//

import SwiftUI
import AppKit

/// Redis 工作区视图
struct RedisWorkspaceView: View {
    let connectionConfig: ConnectionConfig
    let workspaceId: UUID
    @Environment(ConnectionManager.self) var connectionManager

    // State - Service
    @State var service: RedisService?

    // State - Key List
    @State var keys: [RedisKeySummary] = []
    @State var searchPattern: String = ""
    @State var scanCursor: Int = 0
    @State var hasMoreKeys: Bool = false
    @State var isLoadingKeys: Bool = false

    // State - Key Detail
    @State var selectedKey: String?
    @State var selectedKeyDetail: RedisKeyDetail?
    @State var isLoadingDetail: Bool = false

    // State - Value
    @State var stringValue: String?
    @State var hashValue: [String: String] = [:]
    @State var listValue: [String] = []
    @State var setValue: [String] = []
    @State var zsetValue: [RedisZSetMember] = []
    @State var isLoadingValue: Bool = false

    // State - Command
    @State var commandText = ""
    @State var commandResult: RedisCommandResult?
    @State var isLoadingCommand = false

    // State - Connection
    @State var isConnecting: Bool = false

    // State - Display Mode
    @State var displayMode: RedisDisplayMode = .editorOnly
    @State var selectedTab: RedisDetailTab = .keys

    // State - Splitter
    @State var editorHeight: CGFloat = WindowStateRepository.shared.load().editorHeight ?? 200

    // State - Error
    @State var showError: Bool = false
    @State var errorMessage: String = ""

    // State - Sidebar Width (for key browser)
    @State var sidebarWidth: CGFloat = 280

    var body: some View {
        Group {
            if let service, service.session.connectionState.isConnected {
                connectedView
            } else if isConnecting {
                ConnectingView(connectionName: connectionConfig.name)
            } else {
                DisconnectedView(connectionName: connectionConfig.name) {
                    await connect()
                }
            }
        }
        .onAppear {
            Task { await connectIfNeeded() }
        }
        // 监听工作区关闭通知
        .onReceive(NotificationCenter.default.publisher(for: .workspaceWillClose)) { notification in
            guard let closingWorkspaceId = notification.object as? UUID,
                  closingWorkspaceId == workspaceId else { return }
            Task {
                await disconnect()
                await MainActor.run {
                    connectionManager.workspaceManager.notifyDisconnectComplete(workspaceId)
                }
            }
        }
        .onChange(of: editorHeight) { _, newHeight in
            var state = WindowStateRepository.shared.load()
            state.editorHeight = newHeight
            WindowStateRepository.shared.save(state)
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

}

#Preview {
    let config = ConnectionConfig(
        name: "Test Redis",
        databaseKind: .redis,
        host: "localhost",
        port: 6379,
        username: "",
        defaultDatabase: nil
    )

    RedisWorkspaceView(connectionConfig: config, workspaceId: UUID())
        .frame(width: 900, height: 600)
}
