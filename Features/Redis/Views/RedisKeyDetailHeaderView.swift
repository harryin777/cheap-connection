//
//  RedisKeyDetailHeaderView.swift
//  cheap-connection
//
//  Redis Key 详情头部视图
//

import SwiftUI

/// Redis Key 详情头部视图
struct RedisKeyDetailHeaderView: View {
    let detail: RedisKeyDetail

    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            Image(systemName: detail.type.iconName)
                .font(.system(size: 16))
                .foregroundStyle(colorForType(detail.type))
                .frame(width: 24)

            // Key 名称
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.key)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 12) {
                    // 类型
                    Label(detail.type.displayName, systemImage: detail.type.iconName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    // 长度/元素数
                    if detail.valueLength != nil {
                        Label(detail.formattedLength, systemImage: "number")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    // 内存大小
                    if let size = detail.memorySize {
                        Label(formatBytes(size), systemImage: "memorychip")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // TTL 信息
            if let ttl = detail.ttl {
                ttlView(ttl)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - TTL View

    @ViewBuilder
    private func ttlView(_ ttl: Int) -> some View {
        let (text, color): (String, Color) = {
            if ttl < 0 {
                return ("已过期", .red)
            } else if ttl == -1 {
                return ("永不过期", .green)
            } else if ttl < 60 {
                return ("\(ttl) 秒后过期", .orange)
            } else if ttl < 3600 {
                return ("\(ttl / 60) 分钟后过期", .yellow)
            } else if ttl < 86400 {
                return ("\(ttl / 3600) 小时后过期", .mint)
            } else {
                return ("\(ttl / 86400) 天后过期", .green)
            }
        }()

        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 10))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(4)
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

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        }
        if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        }
        return String(format: "%.1f MB", Double(bytes) / 1024.0 / 1024.0)
    }
}

#Preview {
    let detail = RedisKeyDetail(
        key: "user:12345:profile",
        type: .hash,
        ttl: 3600,
        memorySize: 2048,
        valueLength: 15
    )

    RedisKeyDetailHeaderView(detail: detail)
        .frame(width: 600)
}
