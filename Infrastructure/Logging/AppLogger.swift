//
//  AppLogger.swift
//  cheap-connection
//
//  结构化日志系统核心
//

import Foundation
import OSLog

/// 应用日志器
final class AppLogger: @unchecked Sendable {
    static let shared = AppLogger()

    /// 系统日志
    private let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.yzz.cheap-connection", category: "App")

    /// 最小日志级别（低于此级别的日志不会输出）
    var minimumLevel: LogLevel = {
        #if DEBUG
        return .debug
        #else
        return .info
        #endif
    }()

    /// 是否启用日志（Debug 模式开关）
    var isEnabled: Bool = true

    /// 日志缓存（用于调试查看）
    private var cachedEntries: [LogEntry] = []
    private let cacheLock = NSLock()
    private let maxCacheSize = 500

    private init() {}

    // MARK: - 日志方法

    /// 记录 Debug 日志
    func debug(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// 记录 Info 日志
    func info(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// 记录 Warning 日志
    func warning(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .warning, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// 记录 Error 日志
    func error(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .error, message: message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    // MARK: - 便捷方法

    /// 记录连接相关日志
    func connection(
        _ message: String,
        level: LogLevel = .info,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: level, message: message, category: .connection, metadata: metadata, file: file, function: function, line: line)
    }

    /// 记录查询相关日志
    func query(
        _ message: String,
        level: LogLevel = .info,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: level, message: message, category: .query, metadata: metadata, file: file, function: function, line: line)
    }

    /// 记录 Redis 命令相关日志
    func command(
        _ message: String,
        level: LogLevel = .info,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: level, message: message, category: .command, metadata: metadata, file: file, function: function, line: line)
    }

    /// 记录慢操作
    func slowOperation(
        _ operation: String,
        duration: TimeInterval,
        category: LogCategory = .general,
        threshold: TimeInterval = 1.0,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        if duration >= threshold {
            let message = "Slow operation: \(operation) took \(String(format: "%.3f", duration))s"
            warning(message, category: category, metadata: ["duration": "\(duration)"], file: file, function: function, line: line)
        }
    }

    // MARK: - 核心方法

    private func log(
        level: LogLevel,
        message: String,
        category: LogCategory,
        metadata: [String: String]?,
        file: String?,
        function: String?,
        line: Int?
    ) {
        guard isEnabled, level >= minimumLevel else { return }

        // 脱敏处理
        let sanitizedMessage = SensitiveDataSanitizer.sanitize(message)
        let sanitizedMetadata = metadata.map { SensitiveDataSanitizer.sanitize($0) }

        let entry = LogEntry(
            level: level,
            category: category,
            message: sanitizedMessage,
            metadata: sanitizedMetadata,
            file: file,
            function: function,
            line: line
        )

        // 输出到控制台
        print(entry.formattedOutput)

        // 输出到系统日志
        logToOSLog(entry: entry)

        // 缓存日志
        cacheEntry(entry)
    }

    private func logToOSLog(entry: LogEntry) {
        switch entry.level {
        case .debug:
            os_log("%{public}@", log: osLog, type: .debug, entry.formattedOutput)
        case .info:
            os_log("%{public}@", log: osLog, type: .info, entry.formattedOutput)
        case .warning:
            os_log("%{public}@", log: osLog, type: .default, entry.formattedOutput)
        case .error:
            os_log("%{public}@", log: osLog, type: .error, entry.formattedOutput)
        }
    }

    private func cacheEntry(_ entry: LogEntry) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        cachedEntries.append(entry)

        // 超出限制时移除旧日志
        if cachedEntries.count > maxCacheSize {
            cachedEntries.removeFirst(cachedEntries.count - maxCacheSize)
        }
    }

    // MARK: - 缓存访问

    /// 获取缓存的日志条目
    func getCachedEntries() -> [LogEntry] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cachedEntries
    }

    /// 清空日志缓存
    func clearCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cachedEntries.removeAll()
    }
}

// MARK: - 便捷日志函数

/// 全局日志器快捷访问
func logDebug(
    _ message: String,
    category: LogCategory = .general,
    metadata: [String: String]? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    AppLogger.shared.debug(message, category: category, metadata: metadata, file: file, function: function, line: line)
}

func logInfo(
    _ message: String,
    category: LogCategory = .general,
    metadata: [String: String]? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    AppLogger.shared.info(message, category: category, metadata: metadata, file: file, function: function, line: line)
}

func logWarning(
    _ message: String,
    category: LogCategory = .general,
    metadata: [String: String]? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    AppLogger.shared.warning(message, category: category, metadata: metadata, file: file, function: function, line: line)
}

func logError(
    _ message: String,
    category: LogCategory = .general,
    metadata: [String: String]? = nil,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    AppLogger.shared.error(message, category: category, metadata: metadata, file: file, function: function, line: line)
}
