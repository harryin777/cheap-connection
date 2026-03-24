//
//  RedisClientExecution.swift
//  cheap-connection
//
//  Redis 命令执行与字符串解析
//

import Foundation
import Logging
import NIOCore
@preconcurrency import RediStack

extension RedisClient {
    func executeCommand(_ command: [String]) async throws -> RedisCommandResult {
        guard !command.isEmpty else {
            return .error("命令不能为空")
        }

        guard let connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        let start = Date()
        let commandName = command[0].uppercased()
        let riskLevel = RedisRiskDetector.analyze(command)

        switch riskLevel {
        case .critical(let message):
            return .error("禁止执行高风险命令: \(message)")
        case .high(let message), .medium(let message):
            Logger(label: "com.yzz.cheap-connection.redis")
                .warning("执行风险命令: \(commandName) - \(message)")
        case .safe:
            break
        }

        do {
            let args = command.dropFirst().map(RESPValue.init(from:))
            let result = try await connection.send(command: commandName, with: args).get()
            return RedisCommandResult(
                success: true,
                value: RedisValueConverter.convertRESPValue(result),
                duration: Date().timeIntervalSince(start)
            )
        } catch {
            return RedisCommandResult(
                success: false,
                errorMessage: error.localizedDescription,
                duration: Date().timeIntervalSince(start)
            )
        }
    }

    func executeCommandString(_ commandString: String) async throws -> RedisCommandResult {
        try await executeCommand(parseCommandString(commandString))
    }

    nonisolated func parseCommandString(_ commandString: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character?

        for char in commandString {
            if char == "\"" || char == "\'" {
                if inQuotes {
                    if char == quoteChar {
                        inQuotes = false
                        quoteChar = nil
                        tokens.append(current)
                        current = ""
                    } else {
                        current.append(char)
                    }
                } else {
                    inQuotes = true
                    quoteChar = char
                }
            } else if char == " " && !inQuotes {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }
}
