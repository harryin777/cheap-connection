//
//  RedisStringValueView.swift
//  cheap-connection
//
//  Redis String 值视图
//

import SwiftUI

struct RedisStringValueView: View {
    let value: String?

    @State private var showFullValue = false
    private let previewLimit = 5000

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let value {
                    contentView(value)
                    statisticsView(value)
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

    @ViewBuilder
    private func contentView(_ value: String) -> some View {
        if showFullValue || value.count <= previewLimit {
            previewCard(value)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                previewCard(String(value.prefix(previewLimit)))

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
    }

    private func previewCard(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 12, design: .monospaced))
            .textSelection(.enabled)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)
    }

    private func statisticsView(_ value: String) -> some View {
        HStack(spacing: 16) {
            Label("\(value.count) 字符", systemImage: "textformat")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Label("\(value.utf8.count) 字节", systemImage: "memorychip")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
    }
}
