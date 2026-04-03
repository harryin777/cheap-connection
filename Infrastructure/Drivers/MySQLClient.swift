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

            // 输出解析结果
            logConnectionInfo("MySQL 地址解析成功", config: config, extra: [
                "resolvedCount": "\(resolvedAddresses.count)",
                "addresses": resolvedAddresses.map { "\($0.socketAddress.description)" }.joined(separator: ", ")
            ])
        } catch let error as AppError {
            await cleanupEventLoopGroupAfterFailedConnect()
            throw error
        } catch {
            await cleanupEventLoopGroupAfterFailedConnect()

            // 输出详细错误日志
            logConnectionError("MySQL 地址解析失败", config: config, error: error, extra: [
                "rawErrorType": String(describing: type(of: error)),
                "rawErrorDescription": error.localizedDescription
            ])

            throw AppError.connectionFailed("地址解析失败: \(config.host):\(config.port) - \(error.localizedDescription)")
        }

        do {
            let initialDatabase = config.database?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            var attemptErrors: [Error] = []

            for (index, resolved) in resolvedAddresses.enumerated() {
                do {
                    logConnectionInfo("MySQL 尝试连接地址 #\(index + 1)", config: config, extra: [
                        "address": resolved.socketAddress.description,
                        "family": resolved.socketAddress.description.contains(":") ? "IPv6" : "IPv4"
                    ])

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

                    logConnectionInfo("MySQL 连接成功", config: config, extra: [
                        "address": resolved.socketAddress.description
                    ])
                    return
                } catch {
                    attemptErrors.append(error)
                    logConnectionError("MySQL 地址 #\(index + 1) 连接失败", config: config, error: error, extra: [
                        "address": resolved.socketAddress.description,
                        "rawErrorType": String(describing: type(of: error))
                    ])
                }
            }

            // 所有地址都失败
            logConnectionError("MySQL 所有地址尝试失败", config: config, errors: attemptErrors, extra: [
                "attemptedCount": "\(resolvedAddresses.count)"
            ])

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

            logConnectionError("MySQL 连接最终失败", config: config, error: error, extra: [
                "rawErrorType": String(describing: type(of: error)),
                "rawErrorDescription": error.localizedDescription
            ])

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

    // MARK: - 日志辅助方法

    private nonisolated func logConnectionInfo(_ message: String, config: MySQLConnectionConfig, extra: [String: String] = [:]) {
        var metadata: [String: String] = [
            "host": config.host,
            "port": "\(config.port)",
            "username": config.username,
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "nil",
            "executablePath": Bundle.main.executablePath ?? "nil"
        ]
        metadata.merge(extra) { (_, new) in new }
        let metaStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        appLogInfo("\(message) | \(metaStr)", category: .connection)
    }

    private nonisolated func logConnectionError(_ message: String, config: MySQLConnectionConfig, error: Error? = nil, errors: [Error]? = nil, extra: [String: String] = [:]) {
        var metadata: [String: String] = [
            "host": config.host,
            "port": "\(config.port)",
            "username": config.username,
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "nil",
            "executablePath": Bundle.main.executablePath ?? "nil"
        ]
        if let error = error {
            metadata["error"] = error.localizedDescription
            metadata["errorType"] = String(describing: type(of: error))
        }
        if let errors = errors, !errors.isEmpty {
            metadata["errorsCount"] = "\(errors.count)"
            metadata["errorTypes"] = errors.map { String(describing: type(of: $0)) }.joined(separator: ", ")
        }
        metadata.merge(extra) { (_, new) in new }
        let metaStr = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        appLogError("\(message) | \(metaStr)", category: .connection)
    }
}
