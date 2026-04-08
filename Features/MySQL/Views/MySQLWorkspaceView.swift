//
//  MySQLWorkspaceView.swift
//  cheap-connection
//
//  MySQL工作区视图 - 始终存在的统一工作区壳
//

import SwiftUI

// MARK: - MySQLWorkspaceView

/// MySQL工作区视图
/// 始终存在的统一工作区壳，连接上下文是可选执行上下文
struct MySQLWorkspaceView: View {
    let workspaceId: UUID
    @Environment(ConnectionManager.self) var connectionManager

    var body: some View {
        MySQLRightPanelView(
            workspaceId: workspaceId
        )
        .onDisappear {
            // 清理：面板关闭时取消所有挂起任务
        }
        .alert("错误", isPresented: .constant(false)) {
            Button("确定", role: .cancel) { }
        }
    }
}

#Preview {
    MySQLWorkspaceView(workspaceId: UUID()).frame(width: 900, height: 600)
}
