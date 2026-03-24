//
//  RedisClientKeyCommands.swift
//  cheap-connection
//
//  Redis Key 相关命令
//

import Foundation
import NIOCore
@preconcurrency import RediStack

extension RedisClient {
    func scanKeys(match: String?, count: Int?, cursor: Int) async throws -> RedisScanResult {
        guard let connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            var args: [RESPValue] = [.init(from: String(cursor))]

            if let match {
                args.append(.init(from: "MATCH"))
                args.append(.init(from: match))
            }

            if let count {
                args.append(.init(from: "COUNT"))
                args.append(.init(from: String(count)))
            }

            let result = try await connection.send(command: "SCAN", with: args).get()
            return try RedisValueConverter.convertScanResult(result)
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func searchKeys(pattern: String) async throws -> [String] {
        var allKeys: [String] = []
        var cursor = 0

        repeat {
            let result = try await scanKeys(match: pattern, count: 100, cursor: cursor)
            allKeys.append(contentsOf: result.keys)
            cursor = result.nextCursor

            if allKeys.count > 10000 {
                break
            }
        } while cursor != 0

        return allKeys
    }

    func getKeyType(_ key: String) async throws -> RedisValueType {
        guard let connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await connection.send(command: "TYPE", with: [.init(from: key)]).get()
            return result.string.map(RedisValueType.init(fromResponseType:)) ?? .unknown
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getTTL(_ key: String) async throws -> Int {
        guard let connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await connection.send(command: "TTL", with: [.init(from: key)]).get()
            return result.int ?? -2
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getKeyDetail(_ key: String) async throws -> RedisKeyDetail {
        guard let connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            async let typeResult = connection.send(command: "TYPE", with: [.init(from: key)]).get()
            async let ttlResult = connection.send(command: "TTL", with: [.init(from: key)]).get()
            async let debugResult = connection.send(command: "DEBUG", with: [.init(from: "OBJECT"), .init(from: key)]).get()

            let (typeValue, ttlValue, _) = try await (typeResult, ttlResult, debugResult)
            let type = RedisValueType(fromResponseType: typeValue.string ?? "unknown")
            let ttl = ttlValue.int
            let memoryResult = try? await connection.send(command: "MEMORY", with: [.init(from: "USAGE"), .init(from: key)]).get()
            let encodingResult = try? await connection.send(command: "OBJECT", with: [.init(from: "ENCODING"), .init(from: key)]).get()

            return RedisKeyDetail(
                key: key,
                type: type,
                ttl: ttl,
                memorySize: memoryResult?.int,
                valueLength: try await getValueLength(key: key, type: type),
                encoding: encodingResult?.string
            )
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func deleteKey(_ key: String) async throws -> Bool {
        guard let connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await connection.send(command: "DEL", with: [.init(from: key)]).get()
            return result.int == 1
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    private func getValueLength(key: String, type: RedisValueType) async throws -> Int? {
        guard let connection else { return nil }

        let command: String
        switch type {
        case .string: command = "STRLEN"
        case .hash: command = "HLEN"
        case .list: command = "LLEN"
        case .set: command = "SCARD"
        case .zset: command = "ZCARD"
        case .stream: command = "XLEN"
        default: return nil
        }

        return try await connection.send(command: command, with: [.init(from: key)]).get().int
    }
}
