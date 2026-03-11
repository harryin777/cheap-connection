//
//  RedisWorkspaceView.swift
//  cheap-connection
//
//  Redis工作区视图 - 管理Redis连接和操作界面
//

import SwiftUI

/// Redis工作区视图
struct RedisWorkspaceView: View {
    let connectionConfig: ConnectionConfig

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Redis 功能开发中")
                .font(.title)
                .foregroundStyle(.secondary)

            Text("Redis 连接: \(connectionConfig.host):\(connectionConfig.port)")
                .font(.body)
                .foregroundStyle(.tertiary)

            Text("请等待后续版本更新")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    RedisWorkspaceView(connectionConfig: config)
        .frame(width: 800, height: 600)
}
