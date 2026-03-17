//
//  SQLFileOperations.swift
//  cheap-connection
//
//  SQL 文件操作工具
//

import Foundation
import AppKit
import UniformTypeIdentifiers
import os.log

/// SQL 文件操作工具
@MainActor
enum SQLFileOperations {

    private static let logger = Logger(subsystem: "com.cheap-connection", category: "SQLFileOperations")

    /// Debug 构建下打印日志到控制台（os.Logger 默认不显示在 Xcode 控制台）
    private static func debugLog(_ message: String) {
        #if DEBUG
        print("[SQLFileOperations] \(message)")
        #endif
    }

    // MARK: - 打开文件

    /// 打开 SQL 文件并返回内容
    /// - Returns: 成功时返回 (url, content)，用户取消或失败时返回 nil
    static func openSQLFile() async -> (url: URL, content: String)? {
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                let result = openSQLFileSync()
                continuation.resume(returning: result)
            }
        }
    }

    /// 打开 SQL 文件（同步版本）
    /// - Returns: 成功时返回 (url, content)，用户取消或失败时返回 nil
    static func openSQLFileSync() -> (url: URL, content: String)? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.init(filenameExtension: "sql")!]
        panel.message = "选择要打开的 SQL 文件"

        guard panel.runModal() == .OK, let url = panel.url else {
            logger.info("用户取消打开文件")
            debugLog("ℹ️ 用户取消打开文件")
            return nil
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            logger.info("成功打开文件: \(url.path)")
            debugLog("✅ 成功打开文件: \(url.path)")
            return (url, content)
        } catch {
            logger.error("打开文件失败: \(url.path) - \(error.localizedDescription)")
            debugLog("❌ 打开文件失败: \(url.path) - \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 保存文件

    /// 直接保存内容到指定 URL（已有文件时使用）
    /// - Parameters:
    ///   - url: 目标文件 URL
    ///   - content: SQL 内容
    /// - Returns: 是否成功
    @discardableResult
    static func saveToURL(_ url: URL, content: String) -> Bool {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            logger.info("文件保存成功: \(url.path)")
            debugLog("✅ 文件保存成功: \(url.path)")
            return true
        } catch {
            logger.error("保存文件失败: \(url.path) - \(error.localizedDescription)")
            debugLog("❌ 保存文件失败: \(url.path) - \(error.localizedDescription)")
            return false
        }
    }

    /// 使用 window sheet 保存文件（首次保存或另存为时使用）
    /// - Parameters:
    ///   - content: SQL 内容
    ///   - window: 绑定的 NSWindow，sheet 将显示在此窗口上
    ///   - completion: 保存完成回调，返回保存的 URL（用户取消或失败时为 nil）
    static func saveWithSheet(
        content: String,
        window: NSWindow,
        completion: @escaping (URL?) -> Void
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "sql")!]
        panel.canCreateDirectories = true
        panel.message = "保存 SQL 文件"
        panel.nameFieldStringValue = "query.sql"

        // 使用 beginSheetModal 而不是 runModal，避免 app-modal 断言
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else {
                logger.info("用户取消保存")
                debugLog("ℹ️ 用户取消保存")
                completion(nil)
                return
            }

            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                logger.info("文件保存成功: \(url.path)")
                debugLog("✅ 文件保存成功: \(url.path)")
                completion(url)
            } catch {
                logger.error("保存文件失败: \(url.path) - \(error.localizedDescription)")
                debugLog("❌ 保存文件失败: \(url.path) - \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    /// 同步保存（fallback，没有关键窗口时使用）
    /// 注意：此方法使用 runModal，可能触发 AppKit 断言，仅在无法获取窗口时作为 fallback
    /// - Parameter content: SQL 内容
    /// - Returns: 保存的 URL（用户取消或失败时为 nil）
    @discardableResult
    static func saveSQLFileSync(content: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "sql")!]
        panel.canCreateDirectories = true
        panel.message = "保存 SQL 文件"
        panel.nameFieldStringValue = "query.sql"

        guard panel.runModal() == .OK, let url = panel.url else {
            logger.info("用户取消保存")
            debugLog("ℹ️ 用户取消保存")
            return nil
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            logger.info("文件保存成功: \(url.path)")
            debugLog("✅ 文件保存成功: \(url.path)")
            return url
        } catch {
            logger.error("保存文件失败: \(url.path) - \(error.localizedDescription)")
            debugLog("❌ 保存文件失败: \(url.path) - \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 辅助方法

    /// 解析 SQL 语句（按分号分割，处理多行语句）
    static func parseStatements(from content: String) -> [String] {
        var statements: [String] = []
        var currentStatement = ""
        var inString = false
        var stringDelimiter: Character?

        for char in content {
            // 处理字符串
            if char == "'" || char == "\"" {
                if !inString {
                    inString = true
                    stringDelimiter = char
                } else if char == stringDelimiter {
                    inString = false
                    stringDelimiter = nil
                }
                currentStatement.append(char)
                continue
            }

            // 在字符串内，跳过分号检查
            if inString {
                currentStatement.append(char)
                continue
            }

            // 遇到分号，结束当前语句
            if char == ";" {
                let trimmed = currentStatement.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    statements.append(trimmed)
                }
                currentStatement = ""
            } else {
                currentStatement.append(char)
            }
        }

        // 处理最后一条语句（可能没有分号结尾）
        let trimmed = currentStatement.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            statements.append(trimmed)
        }

        return statements
    }

    /// 选择 SQL 文件用于导入
    static func selectSQLFileForImport() async -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.init(filenameExtension: "sql")!]
        panel.message = "选择要导入的 SQL 文件"

        guard panel.runModal() == .OK, let url = panel.url else {
            logger.info("用户取消选择导入文件")
            debugLog("ℹ️ 用户取消选择导入文件")
            return nil
        }

        logger.info("选择了导入文件: \(url.path)")
        debugLog("✅ 选择了导入文件: \(url.path)")
        return url
    }

    /// 读取文件内容
    static func readFileContents(url: URL) throws -> String {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            logger.info("成功读取文件: \(url.path)")
            debugLog("✅ 成功读取文件: \(url.path)")
            return content
        } catch {
            logger.error("读取文件失败: \(url.path) - \(error.localizedDescription)")
            debugLog("❌ 读取文件失败: \(url.path) - \(error.localizedDescription)")
            throw error
        }
    }
}
