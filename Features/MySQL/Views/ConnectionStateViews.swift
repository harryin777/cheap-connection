//
//  ConnectionStateViews.swift
//  cheap-connection
//
//  连接状态视图组件
//

import SwiftUI

/// 连接中视图
struct ConnectingView: View {
    let connectionName: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text("正在连接...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(connectionName)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 未连接视图
struct DisconnectedView: View {
    let connectionName: String
    let onConnect: () async -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("未连接")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("点击连接按钮建立连接")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Button("连接") {
                Task {
                    await onConnect()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// SQL 加载中视图
struct LoadingSQLView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("执行中...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
