//
//  RedisCommandSupport.swift
//  cheap-connection
//
//  Redis 命令视图共享辅助
//

import Foundation

enum RedisCommandSupport {
    static func confirmationMessage(for riskLevel: RedisRiskLevel) -> String {
        switch riskLevel {
        case .safe:
            return ""
        case .medium(let message):
            return "\(message)\n\n确定要继续吗？"
        case .high(let message):
            return "⚠️ 高风险操作\n\(message)\n\n确定要继续吗？"
        case .critical(let message):
            return "🚨 极高风险操作\n\(message)\n\n此命令可能造成不可逆的数据损失，确定要继续吗？"
        }
    }
}
