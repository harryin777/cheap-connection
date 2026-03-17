//
//  MySQLConnectionErrorHandler.swift
//  cheap-connection
//
//  MySQL连接错误处理器
//

import Foundation
import NIOCore

/// MySQL连接错误处理器
enum MySQLConnectionErrorHandler {
    /// 构建最终的连接错误信息
    /// - Parameters:
    ///   - errors: 所有尝试产生的错误
    ///   - resolvedAddresses: 解析到的地址列表
    ///   - host: 原始主机名
    ///   - port: 端口号
    /// - Returns: 适合显示给用户的错误信息
    nonisolated static func buildFinalError(
        errors: [Error],
        resolvedAddresses: [ResolvedSocketAddress],
        host: String,
        port: Int
    ) -> AppError {
        if errors.isEmpty {
            return .connectionFailed("连接失败: 未获取到底层错误")
        }

        // 检查是否所有错误都是超时
        if errors.allSatisfy({ isConnectTimeout($0) }) {
            let ipList = resolvedAddresses.map(\.ipAddress).joined(separator: ", ")
            let allPrivate = resolvedAddresses.allSatisfy { isPrivateIPAddress($0.ipAddress) }

            if allPrivate {
                return .timeout("连接超时，\(host):\(port) 解析为私网地址（\(ipList)），请确认已接入对应 VPC/VPN 或使用公网地址")
            }

            return .timeout("连接超时，目标 \(host):\(port)，解析地址：\(ipList)")
        }

        // 返回最后一个错误
        if let lastError = errors.last {
            return MySQLErrorMapper.map(lastError)
        }

        return .connectionFailed("连接失败: 未获取到底层错误")
    }

    /// 检查错误是否为连接超时
    nonisolated static func isConnectTimeout(_ error: Error) -> Bool {
        // 检查 NIO ChannelError.connectTimeout
        if let channelError = error as? ChannelError, case .connectTimeout = channelError {
            return true
        }
        // 回退到字符串匹配
        return String(describing: error).lowercased().contains("connecttimeout")
    }

    /// 检查IP地址是否为私网地址
    nonisolated static func isPrivateIPAddress(_ ipAddress: String) -> Bool {
        if ipAddress.contains(".") {
            return isPrivateIPv4(ipAddress)
        }
        return isPrivateIPv6(ipAddress)
    }

    /// 检查IPv4地址是否为私网地址
    private nonisolated static func isPrivateIPv4(_ ipAddress: String) -> Bool {
        let parts = ipAddress.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else {
            return false
        }

        let first = parts[0]
        let second = parts[1]

        // 10.0.0.0/8
        if first == 10 {
            return true
        }
        // 127.0.0.0/8 (loopback)
        if first == 127 {
            return true
        }
        // 169.254.0.0/16 (link-local)
        if first == 169 && second == 254 {
            return true
        }
        // 192.168.0.0/16
        if first == 192 && second == 168 {
            return true
        }
        // 172.16.0.0/12
        if first == 172 && (16...31).contains(second) {
            return true
        }

        return false
    }

    /// 检查IPv6地址是否为私网地址
    private nonisolated static func isPrivateIPv6(_ ipAddress: String) -> Bool {
        let normalized = ipAddress.lowercased()

        // ::1 (loopback)
        if normalized == "::1" {
            return true
        }
        // fc00::/7, fd00::/8 (unique local)
        if normalized.hasPrefix("fc") || normalized.hasPrefix("fd") {
            return true
        }
        // fe80::/10 (link-local)
        if normalized.hasPrefix("fe8") ||
            normalized.hasPrefix("fe9") ||
            normalized.hasPrefix("fea") ||
            normalized.hasPrefix("feb") {
            return true
        }

        return false
    }
}
