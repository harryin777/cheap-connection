//
//  RedisCollectionValueViews.swift
//  cheap-connection
//
//  Redis List / Set / ZSet 值视图
//

import SwiftUI

struct RedisListValueView: View {
    let value: [String]

    var body: some View {
        VStack(spacing: 0) {
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

            if value.isEmpty {
                collectionEmptyState(icon: "list.bullet", text: "List 为空")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(value.enumerated()), id: \.offset) { index, item in
                            HStack(alignment: .top, spacing: 0) {
                                Text("\(index)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .trailing)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

                                Divider()

                                Text(item)
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct RedisSetValueView: View {
    let value: [String]

    @State private var searchText = ""
    @State private var sortOrder = true

    private var filteredAndSorted: [String] {
        let filtered = searchText.isEmpty ? value : value.filter { $0.localizedCaseInsensitiveContains(searchText) }
        return sortOrder ? filtered.sorted() : filtered
    }

    var body: some View {
        VStack(spacing: 0) {
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

            if value.isEmpty {
                collectionEmptyState(icon: "circle.dotted", text: "Set 为空")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredAndSorted, id: \.self) { member in
                            HStack(spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 4))
                                    .foregroundStyle(.secondary)

                                Text(member)
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                        }
                    }
                }
            }
        }
    }
}

struct RedisZSetValueView: View {
    let value: [RedisZSetMember]

    @State private var searchText = ""
    @State private var sortDescending = true

    private var filteredAndSorted: [RedisZSetMember] {
        let filtered = searchText.isEmpty ? value : value.filter { $0.member.localizedCaseInsensitiveContains(searchText) }
        return sortDescending ? filtered.sorted { $0.score > $1.score } : filtered.sorted { $0.score < $1.score }
    }

    var body: some View {
        VStack(spacing: 0) {
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

            if value.isEmpty {
                collectionEmptyState(icon: "list.number", text: "ZSet 为空")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredAndSorted, id: \.member) { member in
                            HStack(alignment: .top, spacing: 0) {
                                Text(formatScore(member.score))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.blue)
                                    .frame(width: 100, alignment: .trailing)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                                Divider()

                                Text(member.member)
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
    }

    private func formatScore(_ score: Double) -> String {
        if score == floor(score) {
            return String(format: "%.0f", score)
        }
        return String(format: "%.2f", score)
    }
}

private func collectionEmptyState(icon: String, text: String) -> some View {
    VStack(spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 32))
            .foregroundStyle(.tertiary)

        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
