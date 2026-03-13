//
//  SQLEditorContextSelector.swift
//  cheap-connection
//
//  SQL 编辑器上下文选择器组件
//

import SwiftUI

/// DataGrip 风格的上下文选择器标签
struct SQLEditorContextSelectorLabel: View {
    let icon: String
    let iconColor: Color
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)

            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(.controlBackgroundColor).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }
}

/// Schema/Database 选择器菜单
struct SQLEditorSchemaMenu: View {
    let databases: [String]
    let selectedDatabase: String?
    let onSelect: (String?) -> Void

    var body: some View {
        Menu {
            Button {
                onSelect(nil)
            } label: {
                HStack {
                    Text("未指定")
                    if selectedDatabase == nil {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            ForEach(databases, id: \.self) { database in
                Button {
                    onSelect(database)
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 10))
                        Text(database)
                        if selectedDatabase == database {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            SQLEditorContextSelectorLabel(
                icon: "square.grid.2x2",
                iconColor: .secondary,
                title: selectedDatabase ?? "未指定"
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .id(databases)  // Force refresh when databases change
        .fixedSize()
        .help("当前 Query 执行数据库")
    }
}

/// Connection 选择器菜单
struct SQLEditorConnectionMenu: View {
    let connections: [ConnectionConfig]
    let selectedConnectionId: UUID
    let selectedConnectionName: String
    let onSelect: (UUID) -> Void

    var body: some View {
        Menu {
            ForEach(connections) { connection in
                Button {
                    onSelect(connection.id)
                } label: {
                    HStack {
                        Image(systemName: "externaldrive.connected.to.line.below")
                            .font(.system(size: 10))
                        Text(connection.name)
                        if connection.id == selectedConnectionId {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            SQLEditorContextSelectorLabel(
                icon: "externaldrive.connected.to.line.below",
                iconColor: Color(red: 0.17, green: 0.67, blue: 0.95),
                title: selectedConnectionName
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .id(selectedConnectionId)  // Force rebuild when connection changes to avoid Menu label caching
        .fixedSize()
        .help("当前 Query 连接")
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var selectedDb: String? = "test_db"
        @State var selectedConnId: UUID?

        let previewConnection = ConnectionConfig(
            name: "local-mysql",
            databaseKind: .mysql,
            host: "localhost",
            port: 3306,
            username: "root",
            defaultDatabase: "test_db"
        )

        var body: some View {
            HStack(spacing: 12) {
                SQLEditorSchemaMenu(
                    databases: ["test_db", "mysql", "information_schema"],
                    selectedDatabase: selectedDb,
                    onSelect: { selectedDb = $0 }
                )

                SQLEditorConnectionMenu(
                    connections: [previewConnection],
                    selectedConnectionId: previewConnection.id,
                    selectedConnectionName: previewConnection.name,
                    onSelect: { _ in }
                )
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
