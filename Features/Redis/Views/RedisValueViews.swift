//
//  RedisValueViews.swift
//  cheap-connection
//
//  Redis 各种类型的值展示视图
//

import SwiftUI

// MARK: - String Value View

/// String 类型值展示
struct RedisStringValueView: View {
    let value: String?

    @State private var showFullValue: Bool = false

    private let previewLimit: Int = 5000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let value = value {
                    // 预览或完整值
                    if showFullValue || value.count <= previewLimit {
                        Text(value)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(6)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(value.prefix(previewLimit)))
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(6)

                            HStack {
                                Text("已截断显示，共 \(value.count) 字符")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)

                                Button("显示完整内容") {
                                    showFullValue = true
                                }
                                .buttonStyle(.link)
                                .font(.system(size: 11))
                            }
                            .padding(.horizontal, 12)
                        }
                    }

                    // 统计信息
                    HStack(spacing: 16) {
                        Label("\(value.count) 字符", systemImage: "textformat")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)

                        Label("\(value.utf8.count) 字节", systemImage: "memorychip")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                } else {
                    Text("(nil)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(12)
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Hash Value View

/// Hash 类型值展示
struct RedisHashValueView: View {
    let value: [String: String]

    @State private var searchText: String = ""
    @State private var sortKey: Bool = true

    private var filteredAndSortedFields: [(key: String, value: String)] {
        let items: [(key: String, value: String)] = value.map { ($0.key, $0.value) }
        let filtered: [(key: String, value: String)] = searchText.isEmpty
            ? items
            : items.filter { $0.key.localizedCaseInsensitiveContains(searchText) || $0.value.localizedCaseInsensitiveContains(searchText) }
        return sortKey
            ? filtered.sorted(by: { $0.key < $1.key })
            : filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack(spacing: 8) {
                TextField("搜索字段...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                Spacer()

                Text("\(value.count) 字段")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Button {
                    sortKey.toggle()
                } label: {
                    Image(systemName: sortKey ? "textformat.abc" : "arrow.up.arrow.down")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help(sortKey ? "按名称排序" : "原始顺序")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 内容表格
            if value.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredAndSortedFields, id: \.key) { field in
                            hashFieldRow(key: field.key, value: field.value)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func hashFieldRow(key: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Key 列
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 200, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // Value 列
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("Hash 为空")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - List Value View

/// List 类型值展示
struct RedisListValueView: View {
    let value: [String]

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Spacer()
                Text("\(value.count) 元素")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 内容列表
            if value.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(value.enumerated()), id: \.offset) { index, item in
                            listItemRow(index: index, value: item)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func listItemRow(index: Int, value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // 索引列
            Text("\(index)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

            Divider()

            // 值列
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("List 为空")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Set Value View

/// Set 类型值展示
struct RedisSetValueView: View {
    let value: [String]

    @State private var searchText: String = ""
    @State private var sortOrder: Bool = true

    private var filteredAndSorted: [String] {
        let filtered = searchText.isEmpty
            ? value
            : value.filter { $0.localizedCaseInsensitiveContains(searchText) }
        return sortOrder ? filtered.sorted() : filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack(spacing: 8) {
                TextField("搜索成员...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                Spacer()

                Text("\(value.count) 成员")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Button {
                    sortOrder.toggle()
                } label: {
                    Image(systemName: sortOrder ? "textformat.abc" : "arrow.up.arrow.down")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 内容列表
            if value.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredAndSorted, id: \.self) { member in
                            setMemberRow(value: member)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func setMemberRow(value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "circle.dotted")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("Set 为空")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ZSet Value View

/// ZSet 类型值展示
struct RedisZSetValueView: View {
    let value: [RedisZSetMember]

    @State private var searchText: String = ""
    @State private var sortDescending: Bool = true

    private var filteredAndSorted: [RedisZSetMember] {
        let filtered = searchText.isEmpty
            ? value
            : value.filter { $0.member.localizedCaseInsensitiveContains(searchText) }
        return sortDescending
            ? filtered.sorted { $0.score > $1.score }
            : filtered.sorted { $0.score < $1.score }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack(spacing: 8) {
                TextField("搜索成员...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                Spacer()

                Text("\(value.count) 成员")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Button {
                    sortDescending.toggle()
                } label: {
                    Image(systemName: sortDescending ? "arrow.down.to.line" : "arrow.up.to.line")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help(sortDescending ? "分数从高到低" : "分数从低到高")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 内容表格
            if value.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredAndSorted, id: \.member) { member in
                            zsetMemberRow(member: member)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func zsetMemberRow(member: RedisZSetMember) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // 分数列
            Text(formatScore(member.score))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.blue)
                .frame(width: 100, alignment: .trailing)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // 成员列
            Text(member.member)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.number")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("ZSet 为空")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatScore(_ score: Double) -> String {
        if score == floor(score) {
            return String(format: "%.0f", score)
        } else {
            return String(format: "%.2f", score)
        }
    }
}

// MARK: - Previews

#Preview("String") {
    RedisStringValueView(value: "Hello, World! 这是一个测试字符串。")
        .frame(width: 600, height: 400)
}

#Preview("Hash") {
    RedisHashValueView(value: [
        "name": "John Doe",
        "email": "john@example.com",
        "age": "30",
        "created_at": "2024-01-15T10:30:00Z"
    ])
    .frame(width: 600, height: 400)
}

#Preview("List") {
    RedisListValueView(value: ["item1", "item2", "item3", "item4", "item5"])
        .frame(width: 600, height: 400)
}

#Preview("Set") {
    RedisSetValueView(value: ["member1", "member2", "member3", "alpha", "beta"])
        .frame(width: 600, height: 400)
}

#Preview("ZSet") {
    RedisZSetValueView(value: [
        RedisZSetMember(member: "player1", score: 100),
        RedisZSetMember(member: "player2", score: 250),
        RedisZSetMember(member: "player3", score: 175)
    ])
    .frame(width: 600, height: 400)
}
