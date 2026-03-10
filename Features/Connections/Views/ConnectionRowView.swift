//
//  ConnectionRowView.swift
//  cheap-connection
//
//  连接列表行视图
//

import SwiftUI

/// 连接列表行视图
struct ConnectionRowView: View {
    let config: ConnectionConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: config.databaseKind.iconName)
                .font(.title3)
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 24)

            // 连接信息
            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(config.connectionDescription)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("编辑", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

#Preview {
    VStack {
        ConnectionRowView(
            config: ConnectionConfig(
                name: "本地 MySQL",
                databaseKind: .mysql,
                host: "localhost",
                port: 3306
            ),
            isSelected: false,
            onSelect: {},
            onEdit: {},
            onDelete: {}
        )

        ConnectionRowView(
            config: ConnectionConfig(
                name: "生产 Redis",
                databaseKind: .redis,
                host: "192.168.1.100",
                port: 6379
            ),
            isSelected: true,
            onSelect: {},
            onEdit: {},
            onDelete: {}
        )
    }
    .padding()
    .frame(width: 250)
}
