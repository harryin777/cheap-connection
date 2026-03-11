//
//  MySQLStructureView.swift
//  cheap-connection
//
//  MySQL表结构视图 - DataGrip风格紧凑表格
//

import SwiftUI

/// MySQL表结构视图 - DataGrip风格紧凑表格
struct MySQLStructureView: View {
    let columns: [MySQLColumnDefinition]
    let isLoading: Bool

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if columns.isEmpty {
                emptyStateView
            } else {
                structureTableView
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.regular)

            Text("加载表结构...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tablecells")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("请选择一个表查看结构")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var structureTableView: some View {
        Table(columns, selection: Binding<String?>.constant(nil)) {
            // 列名
            TableColumn("列名") { (column: MySQLColumnDefinition) in
                HStack(spacing: 4) {
                    if column.isPrimaryKey {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 10))
                    }

                    Text(column.name)
                        .font(.system(size: 12, design: .monospaced))
                        .fontWeight(column.isPrimaryKey ? .semibold : .regular)
                }
            }
            .width(min: 80, ideal: 120)

            // 类型
            TableColumn("类型") { (column: MySQLColumnDefinition) in
                Text(column.type)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 100)

            // 可空
            TableColumn("可空") { (column: MySQLColumnDefinition) in
                Text(column.isNullable ? "YES" : "NO")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(column.isNullable ? .secondary : Color.orange)
            }
            .width(50)

            // 键
            TableColumn("键") { (column: MySQLColumnDefinition) in
                if column.isPrimaryKey {
                    Text("PRI")
                        .font(.system(size: 9, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(3)
                }
            }
            .width(50)

            // 默认值
            TableColumn("默认值") { (column: MySQLColumnDefinition) in
                if let defaultValue = column.defaultValue, !defaultValue.isEmpty {
                    Text(defaultValue)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(column.defaultValueDescription)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .italic(column.isNullable)
                }
            }
            .width(min: 60, ideal: 100)

            // 额外
            TableColumn("额外") { (column: MySQLColumnDefinition) in
                if let extra = column.extra, !extra.isEmpty {
                    Text(extra)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.blue)
                }
            }
            .width(min: 60, ideal: 100)

            // 注释
            TableColumn("注释") { (column: MySQLColumnDefinition) in
                if let comment = column.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .width(min: 80, ideal: 150)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }
}

// MARK: - Preview

#Preview {
    let columns = [
        MySQLColumnDefinition(
            name: "id",
            type: "int(11)",
            isNullable: false,
            isPrimaryKey: true,
            defaultValue: nil,
            extra: "auto_increment",
            comment: "主键ID",
            charset: nil,
            collation: nil
        ),
        MySQLColumnDefinition(
            name: "username",
            type: "varchar(50)",
            isNullable: false,
            isPrimaryKey: false,
            defaultValue: nil,
            extra: nil,
            comment: "用户名",
            charset: "utf8mb4",
            collation: "utf8mb4_unicode_ci"
        ),
        MySQLColumnDefinition(
            name: "email",
            type: "varchar(100)",
            isNullable: true,
            isPrimaryKey: false,
            defaultValue: nil,
            extra: nil,
            comment: nil,
            charset: "utf8mb4",
            collation: "utf8mb4_unicode_ci"
        ),
        MySQLColumnDefinition(
            name: "created_at",
            type: "timestamp",
            isNullable: false,
            isPrimaryKey: false,
            defaultValue: "CURRENT_TIMESTAMP",
            extra: nil,
            comment: "创建时间",
            charset: nil,
            collation: nil
        )
    ]

    MySQLStructureView(columns: columns, isLoading: false)
        .frame(width: 700, height: 300)
}
