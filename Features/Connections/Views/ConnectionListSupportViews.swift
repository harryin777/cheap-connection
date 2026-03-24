//
//  ConnectionListSupportViews.swift
//  cheap-connection
//
//  ConnectionList 共享基础视图
//

import SwiftUI

struct ConnectionListEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.connected.to.line.below")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)

            Text("暂无连接")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text("点击右上角 + 新建连接")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(.top, 80)
    }
}

struct ConnectionListDisclosureIcon: View {
    let isExpanded: Bool
    let isVisible: Bool

    var body: some View {
        Group {
            if isVisible {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Color.clear
            }
        }
        .frame(width: 10, height: 10)
        .contentShape(Rectangle())
    }
}

struct ConnectionListCountBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
    }
}
