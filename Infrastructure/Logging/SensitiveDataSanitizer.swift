//
//  SensitiveDataSanitizer.swift
//  cheap-connection
//
//  敏感信息脱敏处理
//

import Foundation

/// 敏感信息脱敏器
struct SensitiveDataSanitizer {

    // MARK: - 敏感关键词

    /// 需要脱敏的关键词列表
    private static let sensitiveKeywords = [
        "password",
        "passwd",
        "pwd",
        "secret",
        "token",
        "key",
        "credential",
        "auth",
        "api_key",
        "apikey",
        "access_token",
        "refresh_token"
    ]

    // MARK: - 脱敏方法

    /// 脱敏字符串中的敏感信息
    static func sanitize(_ text: String) -> String {
        var result = text

        // 脱敏 key=value 格式
        for keyword in sensitiveKeywords {
            // 匹配 key=value 或 key": "value" 格式
            let patterns = [
                "(\\b\(keyword)\\s*[=:]\\s*)[\"']?([^\"'\\s,}\\]]+)[\"']?",
                "(\\b\(keyword)\\s*[=:]\\s*)[\"']([^\"']*)[\"']"
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let range = NSRange(result.startIndex..., in: result)
                    result = regex.stringByReplacingMatches(
                        in: result,
                        options: [],
                        range: range,
                        withTemplate: "$1***REDACTED***"
                    )
                }
            }
        }

        // 脱敏 MySQL 连接字符串中的密码
        if let regex = try? NSRegularExpression(
            pattern: "(mysql://[^:]+:)([^@]+)(@)",
            options: [.caseInsensitive]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "$1***REDACTED***$3"
            )
        }

        // 脱敏 Redis 连接字符串中的密码
        if let regex = try? NSRegularExpression(
            pattern: "(redis://[^:]+:)([^@]+)(@)",
            options: [.caseInsensitive]
        ) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "$1***REDACTED***$3"
            )
        }

        return result
    }

    /// 脱敏字典中的敏感信息
    static func sanitize(_ dict: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]

        for (key, value) in dict {
            let sanitizedKey = sanitize(key)
            let valueStr = String(describing: value)
            let sanitizedValue = isSensitiveKey(key) ? "***REDACTED***" : sanitize(valueStr)
            result[sanitizedKey] = sanitizedValue
        }

        return result
    }

    /// 检查是否为敏感键名
    private static func isSensitiveKey(_ key: String) -> Bool {
        let lowercasedKey = key.lowercased()
        return sensitiveKeywords.contains { lowercasedKey.contains($0) }
    }

    /// 脱敏主机名（只保留首尾字符）
    static func sanitizeHostname(_ hostname: String) -> String {
        guard hostname.count > 4 else {
            return hostname
        }
        let first = String(hostname.prefix(2))
        let last = String(hostname.suffix(2))
        return "\(first)***\(last)"
    }

    /// 脱敏 IP 地址（保留前两段）
    static func sanitizeIPAddress(_ ip: String) -> String {
        let components = ip.split(separator: ".")
        guard components.count == 4 else {
            return "***.***.***.***"
        }
        return "\(components[0]).\(components[1]).***.***"
    }
}
