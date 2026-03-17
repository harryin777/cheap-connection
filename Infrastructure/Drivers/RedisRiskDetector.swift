//
//  RedisRiskDetector.swift
//  cheap-connection
//
//  Redis 高风险命令检测器
//

import Foundation

/// Redis 风险等级
enum RedisRiskLevel: Sendable, Equatable {
    /// 安全命令
    case safe

    /// 需要确认的中等风险命令
    case medium(String)

    /// 需要确认的高风险命令
    case high(String)

    /// 禁止执行的极高风险命令
    case critical(String)
}

/// Redis 高风险命令检测器
enum RedisRiskDetector {

    /// 检测命令的风险等级
    /// - Parameter command: 命令数组（第一个元素是命令名）
    /// - Returns: 风险等级
    nonisolated static func analyze(_ command: [String]) -> RedisRiskLevel {
        guard let commandName = command.first?.uppercased() else {
            return .safe
        }

        // 极高风险命令
        if isCriticalCommand(commandName) {
            return .critical("命令 \(commandName) 可能导致数据全部丢失")
        }

        // 高风险命令
        if let message = isHighRiskCommand(commandName, command) {
            return .high(message)
        }

        // 中等风险命令
        if let message = isMediumRiskCommand(commandName, command) {
            return .medium(message)
        }

        return .safe
    }

    /// 检测命令字符串的风险等级
    /// - Parameter commandString: 命令字符串
    /// - Returns: 风险等级
    nonisolated static func analyze(_ commandString: String) -> RedisRiskLevel {
        let tokens = parseCommandString(commandString)
        return analyze(tokens)
    }

    // MARK: - Command Classification

    /// 极高风险命令（可能导致全部数据丢失）
    private nonisolated static func isCriticalCommand(_ command: String) -> Bool {
        let criticalCommands = [
            "FLUSHALL",      // 清空所有数据库
            "FLUSHDB",       // 清空当前数据库
            "DEBUG",         // DEBUG RELOAD, DEBUG SEGFAULT 等
            "SHUTDOWN",      // 关闭服务器
            "SYNC",          // 主从同步（可能导致大量数据传输）
        ]

        return criticalCommands.contains(command)
    }

    /// 高风险命令（可能导致大量数据变化）
    private nonisolated static func isHighRiskCommand(_ command: String, _ args: [String]) -> String? {
        switch command {
        case "DEL":
            // 删除多个 key
            if args.count > 5 {
                return "将删除 \(args.count - 1) 个 key"
            }
            return nil

        case "UNLINK":
            // 异步删除多个 key
            if args.count > 5 {
                return "将异步删除 \(args.count - 1) 个 key"
            }
            return nil

        case "RENAME", "RENAMENX":
            // 重命名可能覆盖已存在的 key
            return "重命名操作可能覆盖目标 key"

        case "MIGRATE":
            // 数据迁移
            return "将 key 迁移到其他 Redis 实例"

        case "RESTORE":
            // 恢复 key（可能覆盖）
            return "恢复操作可能覆盖已存在的 key"

        case "SWAPDB":
            // 交换数据库
            return "将交换两个数据库的所有数据"

        case "MULTI":
            // 事务开始，提醒用户需要 EXEC 或 DISCARD
            return "开始事务，请确保使用 EXEC 提交或 DISCARD 取消"

        case "SCRIPT":
            // Lua 脚本相关
            if args.count > 1 && args[1].uppercased() == "FLUSH" {
                return "将清除所有 Lua 脚本缓存"
            }
            return nil

        case "FUNCTION":
            // Redis 7.0+ 函数相关
            if args.count > 1 {
                let subcmd = args[1].uppercased()
                if subcmd == "FLUSH" {
                    return "将清除所有函数"
                }
                if subcmd == "DELETE" {
                    return "将删除函数"
                }
            }
            return nil

        default:
            return nil
        }
    }

    /// 中等风险命令（可能影响性能或需要额外注意）
    private nonisolated static func isMediumRiskCommand(_ command: String, _ args: [String]) -> String? {
        switch command {
        case "KEYS":
            // KEYS 命令可能阻塞
            return "KEYS 命令在大数据集上可能阻塞服务器，建议使用 SCAN"

        case "HGETALL", "LRANGE", "SMEMBERS", "ZRANGE":
            // 可能返回大量数据
            return "此命令可能返回大量数据"

        case "CONFIG":
            // 配置修改
            if args.count > 2 && args[1].uppercased() == "SET" {
                return "将修改 Redis 配置"
            }
            return nil

        case "CLIENT":
            // 客户端管理
            if args.count > 1 {
                let subcmd = args[1].uppercased()
                if ["KILL", "PAUSE", "UNBLOCK"].contains(subcmd) {
                    return "将影响其他客户端连接"
                }
            }
            return nil

        case "SLAVEOF", "REPLICAOF":
            // 主从配置
            return "将修改主从复制配置"

        case "ACL":
            // ACL 管理
            if args.count > 1 {
                let subcmd = args[1].uppercased()
                if ["SETUSER", "DELUSER", "LOAD"].contains(subcmd) {
                    return "将修改 ACL 配置"
                }
            }
            return nil

        case "EVAL", "EVALSHA":
            // Lua 脚本执行
            return "将执行 Lua 脚本"

        default:
            return nil
        }
    }

    // MARK: - Helper

    /// 解析命令字符串为 token 数组
    private nonisolated static func parseCommandString(_ commandString: String) -> [String] {
        // 简单的空格分割，不处理引号
        // 实际应该更复杂，但这里作为基础检测足够
        return commandString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
    }
}
