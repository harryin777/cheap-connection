//
//  ConnectionListRowViews.swift
//  cheap-connection
//
//  ConnectionListView 行组件
//

import SwiftUI

// MARK: - Loading Row

struct ConnectionListLoadingRow: View {
    let leading: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.7)
            Text("加载中")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.leading, leading)
        .padding(.vertical, 4)
    }
}

// MARK: - Info Row

struct ConnectionListInfoRow: View {
    let text: String
    let leading: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .padding(.leading, leading)
            .padding(.vertical, 4)
    }
}
