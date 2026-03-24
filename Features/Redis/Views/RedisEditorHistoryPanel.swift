//
//  RedisEditorHistoryPanel.swift
//  cheap-connection
//
//  Redis 编辑器历史面板
//

import SwiftUI

extension RedisEditorView {
    var historyPanel: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if history.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 24))
                            .foregroundStyle(.tertiary)

                        Text("暂无历史命令")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 40)
                } else {
                    ForEach(history.indices.reversed(), id: \.self) { index in
                        historyRow(history[index], index: index)
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    func historyRow(_ command: String, index: Int) -> some View {
        HStack {
            Text("\(history.count - index)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 30, alignment: .trailing)

            Text(command)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
                .textSelection(.enabled)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(index % 2 == 0 ? Color.clear : Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }
}
