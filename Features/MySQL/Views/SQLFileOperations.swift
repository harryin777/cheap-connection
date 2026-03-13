//
//  SQLFileOperations.swift
//  cheap-connection
//
//  SQL 文件操作工具
//

import Foundation
import AppKit
import UniformTypeIdentifiers

/// SQL 文件操作工具
@MainActor
enum SQLFileOperations {

    /// 打开 SQL 文件并返回内容
    static func openSQLFile() async -> (url: URL, content: String)? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.init(filenameExtension: "sql")!]
        panel.message = "选择要打开的 SQL 文件"

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            return (url, content)
        } catch {
            return nil
        }
    }

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
            return nil
        }

        return url
    }

    /// 读取文件内容
    static func readFileContents(url: URL) throws -> String {
        return try String(contentsOf: url, encoding: .utf8)
    }
}
