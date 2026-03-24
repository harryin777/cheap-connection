//
//  RedisClientServerInfo.swift
//  cheap-connection
//
//  Redis 服务端信息与数据库选择
//

import Foundation
import NIOCore
@preconcurrency import RediStack

extension RedisClient {
    func getServerInfo(section: String?) async throws -> [String: String] {
        guard let connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            var args: [RESPValue] = []
            if let section {
                args.append(.init(from: section))
            }

            let result = try await connection.send(command: "INFO", with: args).get()
            guard let infoString = result.string else { return [:] }
            return parseInfoString(infoString)
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getCurrentDatabase() async throws -> Int {
        currentDatabase
    }

    func selectDatabase(_ index: Int) async throws {
        guard let connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        guard (0...15).contains(index) else {
            throw AppError.queryError("数据库索引必须在 0-15 范围内")
        }

        do {
            _ = try await connection.send(command: "SELECT", with: [.init(from: String(index))]).get()
            currentDatabase = index
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    nonisolated func parseInfoString(_ info: String) -> [String: String] {
        var result: [String: String] = [:]

        for line in info.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                result[key] = value
            }
        }

        return result
    }
}
