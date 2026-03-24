//
//  LogEntry.swift
//  cheap-connection
//
//  结构化日志条目模型
//

import Foundation

/// 日志级别
enum LogLevel: String, Codable, Comparable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

    /// 级别数值，用于比较
    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.priority < rhs.priority
    }
}

/// 日志分类
enum LogCategory: String, Codable {
    case connection = "CONNECTION"
    case query = "QUERY"
    case command = "COMMAND"
    case cache = "CACHE"
    case storage = "STORAGE"
    case ui = "UI"
    case general = "GENERAL"
}

/// 日志条目
struct LogEntry: Codable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let metadata: [String: String]?
    let file: String?
    let function: String?
    let line: Int?

    init(
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String]? = nil,
        file: String? = nil,
        function: String? = nil,
        line: Int? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.file = file
        self.function = function
        self.line = line
    }

    /// 格式化输出
    var formattedOutput: String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestampStr = dateFormatter.string(from: timestamp)

        var output = "[\(timestampStr)] [\(level.rawValue)] [\(category.rawValue)] \(message)"

        if let metadata = metadata, !metadata.isEmpty {
            let metaStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            output += " | \(metaStr)"
        }

        #if DEBUG
        if let file = file, let function = function, let line = line {
            let fileName = (file as NSString).lastPathComponent
            output += " (\(fileName):\(line) \(function))"
        }
        #endif

        return output
    }
}
