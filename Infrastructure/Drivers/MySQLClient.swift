//
//  MySQLClient.swift
//  cheap-connection
//
//  MySQL客户端实现 - 基于MySQLKit
//

import Foundation
import MySQLKit
import MySQLNIO
import NIOCore
import NIOPosix
import Logging

/// MySQL客户端
/// 使用MySQLKit实现MySQLClientProtocol
/// 使用 actor 保证线程安全
actor MySQLClient: MySQLClientProtocol {
    // MARK: - Properties

    var connection: MySQLConnection?
    var eventLoopGroup: EventLoopGroup?

    // MARK: - Lifecycle

    deinit {
        // 注意：actor deinit 中不能调用 async 方法
        // 连接应该通过显式调用 disconnect() 来关闭
    }

    // MARK: - MySQLClientProtocol

    func checkConnected() async -> Bool {
        return connection != nil
    }

    func connect(config: MySQLConnectionConfig) async throws {
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

        // 解析地址 - 使用 POSIX getaddrinfo，支持 IPv4/IPv6 多地址
        let resolvedAddresses: [ResolvedSocketAddress]
        do {
            resolvedAddresses = try MySQLConnectionResolver.resolve(host: config.host, port: config.port)

            if resolvedAddresses.isEmpty {
                throw AppError.connectionFailed("未解析到可用地址: \(config.host)")
            }
        } catch let error as AppError {
            await cleanupEventLoopGroupAfterFailedConnect()
            throw error
        } catch {
            await cleanupEventLoopGroupAfterFailedConnect()
            throw AppError.connectionFailed("地址解析失败: \(config.host):\(config.port) - \(error.localizedDescription)")
        }

        do {
            let initialDatabase = config.database?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            var attemptErrors: [Error] = []

            for resolved in resolvedAddresses {
                do {
                    let conn = try await MySQLConnection.connect(
                        to: resolved.socketAddress,
                        username: config.username,
                        database: initialDatabase,
                        password: config.password,
                        tlsConfiguration: config.sslEnabled ? .makeClientConfiguration() : nil,
                        serverHostname: config.host,
                        logger: Logger(label: "com.yzz.cheap-connection.mysql"),
                        on: eventLoop
                    ).get()

                    self.connection = conn
                    return
                } catch {
                    attemptErrors.append(error)
                }
            }

            throw MySQLConnectionErrorHandler.buildFinalError(
                errors: attemptErrors,
                resolvedAddresses: resolvedAddresses,
                host: config.host,
                port: config.port
            )
        } catch let error as AppError {
            await cleanupEventLoopGroupAfterFailedConnect()
            throw error
        } catch {
            await cleanupEventLoopGroupAfterFailedConnect()
            throw MySQLErrorMapper.map(error)
        }
    }

    func disconnect() async {
        let conn = connection
        connection = nil
        let group = eventLoopGroup
        eventLoopGroup = nil

        if let conn = conn {
            try? await conn.close().get()
        }

        if let group = group {
            try? await group.shutdownGracefully()
        }
    }

    func ping() async throws -> Bool {
        guard let conn = connection else {
            throw AppError.connectionFailed("未连接到MySQL服务器")
        }

        do {
            _ = try await conn.query("SELECT 1").get()
            return true
        } catch {
            throw MySQLErrorMapper.map(error)
        }
    }

    // MARK: - Private Methods

    func cleanupEventLoopGroupAfterFailedConnect() async {
        let group = eventLoopGroup
        eventLoopGroup = nil

        if let group = group {
            try? await group.shutdownGracefully()
        }
    }
}
