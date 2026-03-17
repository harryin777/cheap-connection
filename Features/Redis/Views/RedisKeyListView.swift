//
//  RedisKeyListView.swift
//  cheap-connection
//
//  Redis Key 列表视图
//

import SwiftUI

/// Redis Key 列表视图
struct RedisKeyListView: View {
    let keys: [RedisKeySummary]
    let selectedKey: String?
    @Binding var searchPattern: String
    let hasMoreKeys: Bool
    let isLoading: Bool

    let onSelectKey: (String) -> Void
    let onLoadMore: () async -> Void
    let onRefresh: () async -> Void
    let onSearch: (String) async -> Void

    @State private var isSearching: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbarView

            Divider()

            // 搜索框
            searchField

            Divider()

            // Key 列表
            keyListView
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbarView: some View {
        HStack(spacing: 8) {
            Text("Keys")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.6)
            }

            Button {
                Task { await onRefresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("刷新")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Search Field

    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            TextField("搜索 Key (支持通配符 *)", text: $searchPattern)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .onSubmit {
                    Task { await onSearch(searchPattern) }
                }

            if !searchPattern.isEmpty {
                Button {
                    searchPattern = ""
                    Task { await onSearch("") }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Key List

    @ViewBuilder
    private var keyListView: some View {
        if keys.isEmpty && !isLoading {
            emptyStateView
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(keys) { key in
                        keyRow(key)
                    }

                    // 加载更多
                    if hasMoreKeys {
                        loadMoreButton
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyRow(_ key: RedisKeySummary) -> some View {
        HStack(spacing: 8) {
            // 类型图标
            Image(systemName: key.type.iconName)
                .font(.system(size: 11))
                .foregroundStyle(colorForType(key.type))
                .frame(width: 16)

            // Key 名称
            Text(key.key)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // TTL 指示器
            if let ttl = key.ttl {
                ttlBadge(ttl)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(selectedKey == key.key ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectKey(key.key)
        }
    }

    @ViewBuilder
    private func ttlBadge(_ ttl: Int) -> some View {
        let color: Color = {
            if ttl < 0 { return .red }
            if ttl < 60 { return .orange }
            if ttl < 3600 { return .yellow }
            return .green
        }()

        Text(formatTTL(ttl))
            .font(.system(size: 9))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15))
            .cornerRadius(3)
    }

    @ViewBuilder
    private var loadMoreButton: some View {
        Button {
            Task { await onLoadMore() }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.6)
                } else {
                    Text("加载更多")
                        .font(.system(size: 11))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.slash")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text(searchPattern.isEmpty ? "暂无 Key" : "未找到匹配的 Key")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if !searchPattern.isEmpty {
                Button("清除搜索") {
                    searchPattern = ""
                    Task { await onSearch("") }
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Helpers

    private func colorForType(_ type: RedisValueType) -> Color {
        switch type {
        case .string: return .blue
        case .hash: return .purple
        case .list: return .green
        case .set: return .orange
        case .zset: return .red
        case .stream: return .cyan
        default: return .gray
        }
    }

    private func formatTTL(_ ttl: Int) -> String {
        if ttl < 0 { return "过期" }
        if ttl < 60 { return "\(ttl)s" }
        if ttl < 3600 { return "\(ttl / 60)m" }
        if ttl < 86400 { return "\(ttl / 3600)h" }
        return "\(ttl / 86400)d"
    }
}

#Preview {
    let keys = [
        RedisKeySummary(key: "user:1", type: .string, ttl: 3600),
        RedisKeySummary(key: "session:abc", type: .hash, ttl: 60),
        RedisKeySummary(key: "queue:tasks", type: .list, ttl: nil),
        RedisKeySummary(key: "tags:all", type: .set, ttl: 86400),
        RedisKeySummary(key: "leaderboard", type: .zset, ttl: -1)
    ]

    RedisKeyListView(
        keys: keys,
        selectedKey: "user:1",
        searchPattern: .constant(""),
        hasMoreKeys: true,
        isLoading: false,
        onSelectKey: { _ in },
        onLoadMore: { },
        onRefresh: { },
        onSearch: { _ in }
    )
    .frame(width: 280, height: 400)
}
