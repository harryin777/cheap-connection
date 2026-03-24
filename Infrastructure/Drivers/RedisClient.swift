//
//  RedisClient.swift
//  cheap-connection
//
//  Redis客户端实现 - 基于 RediStack
//

import Foundation
@preconcurrency import RediStack
import NIOCore
import NIOPosix
import Logging

/// Redis客户端
/// 使用RediStack实现RedisClientProtocol
/// 使用 actor 保证线程安全
actor RedisClient: RedisClientProtocol {
    // MARK: - Properties

    var connection: RedisConnection?
    var eventLoopGroup: EventLoopGroup?
    var currentDatabase: Int = 0

    // MARK: - Lifecycle

    deinit {
        // 注意：actor deinit 中不能调用 async 方法
        // 连接应该通过显式调用 disconnect() 来关闭
    }

    // MARK: - RedisClientProtocol

    func checkConnected() async -> Bool {
        return connection != nil && connection?.isConnected == true
    }

    func connect(config: RedisConnectionConfig) async throws {
        // 如果已连接，先断开
        if connection != nil {
            await disconnect()
        }

        // 创建EventLoopGroup
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        guard let eventLoopGroup = eventLoopGroup else {
            throw AppError.internalError("无法创建EventLoopGroup")
        }

        let eventLoop = eventLoopGroup.next()

        // 解析地址 - 使用 MySQLConnectionResolver（通用 TCP 地址解析）
        let resolvedAddresses: [ResolvedSocketAddress]
        do {
            resolvedAddresses = try MySQLConnectionResolver.resolve(host: config.host, port: config.port)

            if resolvedAddresses.isEmpty {
                throw AppError.connectionFailed("未解析到可用地址: \(config.host)")
            }
        } catch let error as AppError {
            await cleanupAfterFailedConnect()
            throw error
        } catch {
            await cleanupAfterFailedConnect()
            throw AppError.connectionFailed("地址解析失败: \(config.host):\(config.port) - \(error.localizedDescription)")
        }

        do {
            var attemptErrors: [Error] = []

            for resolved in resolvedAddresses {
                do {
                    let conn = try await makeConnection(
                        to: resolved.socketAddress,
                        config: config,
                        eventLoop: eventLoop
                    )

                    self.connection = conn
                    self.currentDatabase = config.database ?? 0

                    // 如果指定了数据库，执行 SELECT
                    if let db = config.database, db > 0 {
                        try await selectDatabase(db)
                    }

                    return
                } catch {
                    attemptErrors.append(error)
                }
            }

            throw RedisConnectionErrorHandler.buildFinalError(
                errors: attemptErrors,
                resolvedAddresses: resolvedAddresses,
                host: config.host,
                port: config.port
            )
        } catch let error as AppError {
            await cleanupAfterFailedConnect()
            throw error
        } catch {
            await cleanupAfterFailedConnect()
            throw RedisErrorMapper.map(error)
        }
    }

    func disconnect() async {
        let conn = connection
        connection = nil
        let group = eventLoopGroup
        eventLoopGroup = nil
        currentDatabase = 0

        if let conn = conn {
            try? await conn.close().get()
        }

        if let group = group {
            try? await group.shutdownGracefully()
        }
    }

    func ping() async throws -> TimeInterval {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到Redis服务器")
        }

        let start = Date()
        do {
            _ = try await conn.send(command: "PING", with: []).get()
            return Date().timeIntervalSince(start)
        } catch {
            throw RedisErrorMapper.map(error)
        }
    }

    // MARK: - Private Methods

    private func makeConnection(
        to socketAddress: SocketAddress,
        config: RedisConnectionConfig,
        eventLoop: EventLoop
    ) async throws -> RedisConnection {
        let logger = Logger(label: "com.yzz.cheap-connection.redis")

        // 构建连接配置
        let password: String? = config.password
        let username: String? = config.username

        // 创建 RediStack 配置
        // 注意：RediStack 的 Configuration 使用 initialDatabase 而不是 database
        let redisConfig = try RedisConnection.Configuration(
            address: socketAddress,
            username: username,
            password: password,
            initialDatabase: config.database,
            defaultLogger: logger
        )

        // 使用 RedisConnection.make 创建连接
        return try await RedisConnection.make(
            configuration: redisConfig,
            boundEventLoop: eventLoop
        ).get()
    }

    func cleanupAfterFailedConnect() async {
        let group = eventLoopGroup
        eventLoopGroup = nil

        if let group = group {
            try? await group.shutdownGracefully()
        }
    }
}

/// Redis 连接错误处理器
enum RedisConnectionErrorHandler {
    /// 构建最终错误
    nonisolated static func buildFinalError(
        errors: [Error],
        resolvedAddresses: [ResolvedSocketAddress],
        host: String,
        port: Int
    ) -> AppError {
        // 如果所有尝试都失败，返回第一个有意义的错误
        for error in errors {
            let mapped = RedisErrorMapper.map(error)
            // 返回第一个非内部错误
            switch mapped {
            case .authenticationFailed, .connectionFailed, .timeout, .networkError:
                return mapped
            default:
                continue
            }
        }

        // 如果都是内部错误，返回第一个映射结果
        if let firstError = errors.first {
            return RedisErrorMapper.map(firstError)
        }

        return .connectionFailed("无法连接到 Redis: \(host):\(port)")
    }
}
