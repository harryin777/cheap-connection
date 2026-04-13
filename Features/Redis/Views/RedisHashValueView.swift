//
//  RedisHashValueView.swift
//  cheap-connection
//
//  Redis Hash 值视图
//

import SwiftUI

struct RedisHashValueView: View {
    let value: [String: String]

    @State private var searchText = ""
    @State private var sortByKey = true

    private var filteredAndSortedFields: [(key: String, value: String)] {
        let items = value.map { entry in
            (key: entry.key, value: entry.value)
        }
        let filtered = searchText.isEmpty
            ? items
            : items.filter { field in
                field.key.localizedCaseInsensitiveContains(searchText)
                    || field.value.localizedCaseInsensitiveContains(searchText)
            }
        return sortByKey ? filtered.sorted(by: { $0.key < $1.key }) : filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbarView
            Divider()

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

    private var toolbarView: some View {
        HStack(spacing: 8) {
            TextField("搜索字段...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)

            Spacer()

            Text("\(value.count) 字段")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button {
                sortByKey.toggle()
            } label: {
                Image(systemName: sortByKey ? "textformat.abc" : "arrow.up.arrow.down")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help(sortByKey ? "按名称排序" : "原始顺序")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func hashFieldRow(key: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(.primary)
                .frame(width: 200, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

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
