//
//  RedisClientValueCommands.swift
//  cheap-connection
//
//  Redis 值读取命令
//

import Foundation
import NIOCore
@preconcurrency import RediStack

extension RedisClient {
    func getString(_ key: String) async throws -> String? {
        guard let connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await connection.send(command: "GET", with: [.init(from: key)]).get()
            return result.isNull ? nil : result.string
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getHash(_ key: String) async throws -> [String: String] {
        guard let connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await connection.send(command: "HGETALL", with: [.init(from: key)]).get()
            return RedisValueConverter.convertHashResult(result)
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getList(_ key: String, start: Int, stop: Int) async throws -> [String] {
        guard let connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await connection.send(
                command: "LRANGE",
                with: [.init(from: key), .init(from: String(start)), .init(from: String(stop))]
            ).get()
            return RedisValueConverter.convertArrayResult(result)
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getSet(_ key: String) async throws -> [String] {
        guard let connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            let result = try await connection.send(command: "SMEMBERS", with: [.init(from: key)]).get()
            return RedisValueConverter.convertArrayResult(result)
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    func getZSet(_ key: String, start: Int, stop: Int, withScores: Bool) async throws -> [RedisZSetMember] {
        guard let connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        do {
            var args: [RESPValue] = [.init(from: key), .init(from: String(start)), .init(from: String(stop))]
            if withScores {
                args.append(.init(from: "WITHSCORES"))
            }

            let result = try await connection.send(command: "ZRANGE", with: args).get()
            return RedisValueConverter.convertZSetResult(result, withScores: withScores)
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }
}
