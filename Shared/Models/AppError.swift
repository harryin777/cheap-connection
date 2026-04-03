//
//  AppError.swift
//  cheap-connection
//
//  应用错误类型定义
//

import Foundation
import Combine

/// 应用统一错误类型
enum AppError: Error, Equatable, LocalizedError {
    case connectionFailed(String)
    case authenticationFailed(String)
    case timeout(String)
    case networkError(String)
    case queryError(String)
    case decodingError(String)
    case unsupportedOperation(String)
    case internalError(String)

    var errorDescription: String? {
        localizedDescription
    }

    var localizedDescription: String {
        switch self {
        case .connectionFailed(let msg):
            return "连接失败: \(msg)"
        case .authenticationFailed(let msg):
            return "认证失败: \(msg)"
        case .timeout(let msg):
            return "操作超时: \(msg)"
        case .networkError(let msg):
            return "网络错误: \(msg)"
        case .queryError(let msg):
            return "查询错误: \(msg)"
        case .decodingError(let msg):
            return "数据解析错误: \(msg)"
        case .unsupportedOperation(let msg):
            return "不支持的操作: \(msg)"
        case .internalError(let msg):
            return "内部错误: \(msg)"
        }
    }

    /// 用于日志的错误类别
    var category: String {
        switch self {
        case .connectionFailed:
            return "CONNECTION"
        case .authenticationFailed:
            return "AUTH"
        case .timeout:
            return "TIMEOUT"
        case .networkError:
            return "NETWORK"
        case .queryError:
            return "QUERY"
        case .decodingError:
            return "DECODING"
        case .unsupportedOperation:
            return "UNSUPPORTED"
        case .internalError:
            return "INTERNAL"
        }
    }

    /// 是否可重试
    var isRetryable: Bool {
        switch self {
        case .connectionFailed, .timeout, .networkError:
            return true
        case .authenticationFailed, .queryError, .decodingError,
             .unsupportedOperation, .internalError:
            return false
        }
    }
}

// MARK: - Log Types

/// 日志级别
enum LogLevel: String, Codable, Comparable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

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
struct LogEntry: Identifiable, Codable {
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
}

// MARK: - Simple Log Collector

/// 简单的内存日志收集器 - 用于日志面板
final class SimpleLogCollector: @unchecked Sendable {
    nonisolated(unsafe) static let shared = SimpleLogCollector()

    private var _entries: [LogEntry] = []
    private let lock = NSLock()
    private let maxEntries = 500

    private init() {}

    var entries: [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return _entries
    }

    func add(_ entry: LogEntry) {
        lock.lock()
        defer { lock.unlock() }

        _entries.append(entry)
        if _entries.count > maxEntries {
            _entries.removeFirst(_entries.count - maxEntries)
        }
    }

    func getAll() -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return _entries
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        _entries.removeAll()
    }

    // 便捷日志方法
    func debug(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil) {
        let entry = LogEntry(level: .debug, category: category, message: message, metadata: metadata)
        add(entry)
        print("[DEBUG] [\(category.rawValue)] \(message)")
    }

    func info(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil) {
        let entry = LogEntry(level: .info, category: category, message: message, metadata: metadata)
        add(entry)
        print("[INFO] [\(category.rawValue)] \(message)")
    }

    func warning(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil) {
        let entry = LogEntry(level: .warning, category: category, message: message, metadata: metadata)
        add(entry)
        print("[WARN] [\(category.rawValue)] \(message)")
    }

    func error(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil) {
        let entry = LogEntry(level: .error, category: category, message: message, metadata: metadata)
        add(entry)
        print("[ERROR] [\(category.rawValue)] \(message)")
    }
}

// MARK: - Global Log Functions

/// 全局日志函数 - 同时输出到控制台和日志面板
func appLogDebug(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil) {
    let collector = SimpleLogCollector.shared
    if Thread.isMainThread {
        collector.debug(message, category: category, metadata: metadata)
    } else {
        DispatchQueue.main.async {
            collector.debug(message, category: category, metadata: metadata)
        }
    }
}

func appLogInfo(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil) {
    let collector = SimpleLogCollector.shared
    if Thread.isMainThread {
        collector.info(message, category: category, metadata: metadata)
    } else {
        DispatchQueue.main.async {
            collector.info(message, category: category, metadata: metadata)
        }
    }
}

func appLogWarning(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil) {
    let collector = SimpleLogCollector.shared
    if Thread.isMainThread {
        collector.warning(message, category: category, metadata: metadata)
    } else {
        DispatchQueue.main.async {
            collector.warning(message, category: category, metadata: metadata)
        }
    }
}

func appLogError(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil) {
    let collector = SimpleLogCollector.shared
    if Thread.isMainThread {
        collector.error(message, category: category, metadata: metadata)
    } else {
        DispatchQueue.main.async {
            collector.error(message, category: category, metadata: metadata)
        }
    }
}
