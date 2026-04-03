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
    let fontSize: CGFloat

    var body: some View {
        let iconSize = max(10, fontSize)
        let chevronSize = max(8, fontSize - 2)
        let horizontalPadding = max(10, fontSize * 0.85)
        let verticalPadding = max(6, fontSize * 0.45)

        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.system(size: fontSize, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)

            Image(systemName: "chevron.down")
                .font(.system(size: chevronSize, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(.controlBackgroundColor).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
        )
    }
}

/// Schema/Database 选择器菜单
struct SQLEditorSchemaMenu: View {
    let databases: [String]
    let selectedDatabase: String?
    let onSelect: (String?) -> Void
    @ObservedObject private var settingsRepo = SettingsRepository.shared

    var body: some View {
        let fontSize = CGFloat(settingsRepo.settings.tabBarFontSize)

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
                title: selectedDatabase ?? "未指定",
                fontSize: fontSize
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .id("schema-\(fontSize)-\(selectedDatabase ?? "none")-\(databases.joined(separator: ","))")
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
    @ObservedObject private var settingsRepo = SettingsRepository.shared

    // 按类型分组的连接
    private var mysqlConnections: [ConnectionConfig] {
        connections.filter { $0.databaseKind == .mysql }
            .sorted { $0.name < $1.name }
    }

    private var redisConnections: [ConnectionConfig] {
        connections.filter { $0.databaseKind == .redis }
            .sorted { $0.name < $1.name }
    }

    // 当前选中连接的类型图标和颜色
    private var selectedConnectionIcon: String {
        guard let conn = connections.first(where: { $0.id == selectedConnectionId }) else {
            return "externaldrive.connected.to.line.below"
        }
        return conn.databaseKind == .mysql ? "cylinder" : "memorybox"
    }

    private var selectedConnectionIconColor: Color {
        guard let conn = connections.first(where: { $0.id == selectedConnectionId }) else {
            return Color(red: 0.17, green: 0.67, blue: 0.95)
        }
        return conn.databaseKind == .mysql
            ? Color(red: 0.17, green: 0.67, blue: 0.95)  // MySQL blue
            : Color(red: 0.85, green: 0.27, blue: 0.22)   // Redis red
    }

    var body: some View {
        let fontSize = CGFloat(settingsRepo.settings.tabBarFontSize)

        Menu {
            // MySQL group
            if !mysqlConnections.isEmpty {
                Section(header: Text("MySQL")) {
                    ForEach(mysqlConnections) { connection in
                        Button {
                            onSelect(connection.id)
                        } label: {
                            HStack {
                                Image(systemName: "cylinder")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(red: 0.17, green: 0.67, blue: 0.95))
                                Text(connection.name)
                                if connection.id == selectedConnectionId {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            // Divider
            if !mysqlConnections.isEmpty && !redisConnections.isEmpty {
                Divider()
            }

            // Redis group
            if !redisConnections.isEmpty {
                Section(header: Text("Redis")) {
                    ForEach(redisConnections) { connection in
                        Button {
                            onSelect(connection.id)
                        } label: {
                            HStack {
                                Image(systemName: "memorybox")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(red: 0.85, green: 0.27, blue: 0.22))
                                Text(connection.name)
                                if connection.id == selectedConnectionId {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            SQLEditorContextSelectorLabel(
                icon: selectedConnectionIcon,
                iconColor: selectedConnectionIconColor,
                title: selectedConnectionName,
                fontSize: fontSize
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .id("connection-\(fontSize)-\(selectedConnectionId.uuidString)-\(selectedConnectionName)")
        .fixedSize()
        .help("Current query connection")
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
