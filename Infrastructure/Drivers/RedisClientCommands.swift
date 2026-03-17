//
//  RedisClientCommands.swift
//  cheap-connection
//
//  Redis客户端命令实现 - RedisClient 的命令扩展
//

import Foundation
@preconcurrency import RediStack
import NIOCore
import Logging

// MARK: - Key Operations

extension RedisClient {

    func scanKeys(match: String?, count: Int?, cursor: Int) async throws -> RedisScanResult {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            var args: [RESPValue] = [.init(from: String(cursor))]

            if let match = match {
                args.append(.init(from: "MATCH"))
                args.append(.init(from: match))
            }

            if let count = count {
                args.append(.init(from: "COUNT"))
                args.append(.init(from: String(count)))
            }

            let result = try await conn.send(command: "SCAN", with: args).get()

            return try RedisValueConverter.convertScanResult(result)
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func searchKeys(pattern: String) async throws -> [String] {
        // 使用 SCAN 增量搜索，避免 KEYS 阻塞
        var allKeys: [String] = []
        var cursor = 0

        repeat {
            let result = try await scanKeys(match: pattern, count: 100, cursor: cursor)
            allKeys.append(contentsOf: result.keys)
            cursor = result.nextCursor

            // 限制最大返回数量
            if allKeys.count > 10000 {
                break
            }
        } while cursor != 0

        return allKeys
    }

    func getKeyType(_ key: String) async throws -> RedisValueType {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await conn.send(command: "TYPE", with: [.init(from: key)]).get()

            if let typeString = result.string {
                return RedisValueType(fromResponseType: typeString)
            }

            return .unknown
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getTTL(_ key: String) async throws -> Int {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await conn.send(command: "TTL", with: [.init(from: key)]).get()

            if let ttl = result.int {
                return ttl
            }

            return -2 // key 不存在
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getKeyDetail(_ key: String) async throws -> RedisKeyDetail {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            // 并行获取类型、TTL、内存信息
            async let typeResult = conn.send(command: "TYPE", with: [.init(from: key)]).get()
            async let ttlResult = conn.send(command: "TTL", with: [.init(from: key)]).get()
            async let debugResult = conn.send(command: "DEBUG", with: [.init(from: "OBJECT"), .init(from: key)]).get()

            let (typeValue, ttlValue, _) = try await (typeResult, ttlResult, debugResult)

            let type = RedisValueType(fromResponseType: typeValue.string ?? "unknown")
            let ttl = ttlValue.int

            // 获取内存大小
            let memoryResult = try? await conn.send(command: "MEMORY", with: [.init(from: "USAGE"), .init(from: key)]).get()
            let memorySize = memoryResult?.int

            // 获取值长度
            let valueLength = try await getValueLength(key: key, type: type)

            // 获取编码信息
            let encodingResult = try? await conn.send(
                command: "OBJECT",
                with: [.init(from: "ENCODING"), .init(from: key)]
            ).get()
            let encoding = encodingResult?.string

            return RedisKeyDetail(
                key: key,
                type: type,
                ttl: ttl,
                memorySize: memorySize,
                valueLength: valueLength,
                encoding: encoding
            )
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func deleteKey(_ key: String) async throws -> Bool {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await conn.send(command: "DEL", with: [.init(from: key)]).get()
            return result.int == 1
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    // MARK: - Private Helpers

    private func getValueLength(key: String, type: RedisValueType) async throws -> Int? {
        guard let conn = connection else { return nil }

        switch type {
        case .string:
            let result = try await conn.send(command: "STRLEN", with: [.init(from: key)]).get()
            return result.int

        case .hash:
            let result = try await conn.send(command: "HLEN", with: [.init(from: key)]).get()
            return result.int

        case .list:
            let result = try await conn.send(command: "LLEN", with: [.init(from: key)]).get()
            return result.int

        case .set:
            let result = try await conn.send(command: "SCARD", with: [.init(from: key)]).get()
            return result.int

        case .zset:
            let result = try await conn.send(command: "ZCARD", with: [.init(from: key)]).get()
            return result.int

        case .stream:
            let result = try await conn.send(command: "XLEN", with: [.init(from: key)]).get()
            return result.int

        default:
            return nil
        }
    }
}

// MARK: - Value Operations

extension RedisClient {

    func getString(_ key: String) async throws -> String? {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await conn.send(command: "GET", with: [.init(from: key)]).get()

            if result.isNull {
                return nil
            }

            return result.string
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getHash(_ key: String) async throws -> [String: String] {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await conn.send(command: "HGETALL", with: [.init(from: key)]).get()

            return RedisValueConverter.convertHashResult(result)
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getList(_ key: String, start: Int, stop: Int) async throws -> [String] {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await conn.send(
                command: "LRANGE",
                with: [
                    .init(from: key),
                    .init(from: String(start)),
                    .init(from: String(stop))
                ]
            ).get()

            return RedisValueConverter.convertArrayResult(result)
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getSet(_ key: String) async throws -> [String] {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await conn.send(command: "SMEMBERS", with: [.init(from: key)]).get()

            return RedisValueConverter.convertArrayResult(result)
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getZSet(_ key: String, start: Int, stop: Int, withScores: Bool) async throws -> [RedisZSetMember] {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            var args: [RESPValue] = [
                .init(from: key),
                .init(from: String(start)),
                .init(from: String(stop))
            ]

            if withScores {
                args.append(.init(from: "WITHSCORES"))
            }

            let result = try await conn.send(command: "ZRANGE", with: args).get()

            return RedisValueConverter.convertZSetResult(result, withScores: withScores)
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }
}

// MARK: - Command Execution

extension RedisClient {

    func executeCommand(_ command: [String]) async throws -> RedisCommandResult {
        guard !command.isEmpty else {
            return .error("命令不能为空")
        }

        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        let start = Date()
        let commandName = command[0].uppercased()

        // 检测高风险命令
        let riskLevel = RedisRiskDetector.analyze(command)
        switch riskLevel {
        case .critical(let message):
            return .error("禁止执行高风险命令: \(message)")
        case .high(let message), .medium(let message):
            // 在实际应用中，这里应该让 UI 层处理确认
            // 驱动层只记录日志，不阻止执行
            Logger(label: "com.yzz.cheap-connection.redis")
                .warning("执行风险命令: \(commandName) - \(message)")
        case .safe:
            break
        }

        do {
            let args = command.dropFirst().map { RESPValue(from: $0) }
            let result = try await conn.send(command: commandName, with: args).get()

            let duration = Date().timeIntervalSince(start)
            let value = RedisValueConverter.convertRESPValue(result)

            return RedisCommandResult(success: true, value: value, duration: duration)
        } catch {
            let duration = Date().timeIntervalSince(start)
            return RedisCommandResult(
                success: false,
                errorMessage: error.localizedDescription,
                duration: duration
            )
        }
    }

    func executeCommandString(_ commandString: String) async throws -> RedisCommandResult {
        let tokens = parseCommandString(commandString)
        return try await executeCommand(tokens)
    }

    private nonisolated func parseCommandString(_ commandString: String) -> [String] {
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

// MARK: - Server Info

extension RedisClient {

    func getServerInfo(section: String?) async throws -> [String: String] {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            var args: [RESPValue] = []
            if let section = section {
                args.append(.init(from: section))
            }

            let result = try await conn.send(command: "INFO", with: args).get()

            guard let infoString = result.string else {
                return [:]
            }

            return parseInfoString(infoString)
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getCurrentDatabase() async throws -> Int {
        return currentDatabase
    }

    func selectDatabase(_ index: Int) async throws {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        guard index >= 0 && index <= 15 else {
            throw AppError.queryError("数据库索引必须在 0-15 范围内")
        }

        do {
            _ = try await conn.send(command: "SELECT", with: [.init(from: String(index))]).get()
            currentDatabase = index
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    // MARK: - Private Helpers

    private nonisolated func parseInfoString(_ info: String) -> [String: String] {
        var result: [String: String] = [:]

        for line in info.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 跳过注释和空行
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // 解析 key:value
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                result[key] = value
            }
        }

        return result
    }
}
