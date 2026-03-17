//
//  RedisClientProtocol.swift
//  cheap-connection
//
//  Redis客户端协议 - 驱动层抽象接口
//

import Foundation

/// Redis SCAN 命令结果
struct RedisScanResult: Sendable {
    /// 下一次扫描使用的游标，0 表示结束
    let nextCursor: Int
    /// 本次扫描返回的 key 列表
    let keys: [String]
}

/// Redis ZSet 成员
struct RedisZSetMember: Sendable, Equatable {
    let member: String
    let score: Double
}

/// Redis客户端协议
/// 所有Redis驱动实现都必须遵循此协议
protocol RedisClientProtocol: Sendable {
    // MARK: - Connection Management

    /// 检查是否已连接
    func checkConnected() async -> Bool

    /// 连接到Redis服务器
    /// - Parameter config: Redis连接配置
    func connect(config: RedisConnectionConfig) async throws

    /// 断开连接
    func disconnect() async

    /// Ping服务器
    /// - Returns: 响应时间（秒）
    func ping() async throws -> TimeInterval

    // MARK: - Key Operations

    /// 扫描 key（增量式，使用 SCAN 命令）
    /// - Parameters:
    ///   - match: 匹配模式（如 "user:*"），nil 表示匹配所有
    ///   - count: 每次扫描建议返回的数量
    ///   - cursor: 游标，0 表示开始新扫描
    /// - Returns: 扫描结果
    func scanKeys(match: String?, count: Int?, cursor: Int) async throws -> RedisScanResult

    /// 搜索 key（注意：使用 SCAN 实现，非阻塞）
    /// - Parameter pattern: 匹配模式
    /// - Returns: 匹配的 key 列表
    func searchKeys(pattern: String) async throws -> [String]

    /// 获取 key 类型
    /// - Parameter key: key 名称
    /// - Returns: Redis 值类型
    func getKeyType(_ key: String) async throws -> RedisValueType

    /// 获取 key 的 TTL（秒）
    /// - Parameter key: key 名称
    /// - Returns: TTL 秒数，-1 表示无过期时间，-2 表示 key 不存在
    func getTTL(_ key: String) async throws -> Int

    /// 获取 key 详情（类型、TTL、内存大小）
    /// - Parameter key: key 名称
    /// - Returns: Key 详情
    func getKeyDetail(_ key: String) async throws -> RedisKeyDetail

    /// 删除 key
    /// - Parameter key: key 名称
    /// - Returns: 是否成功删除
    func deleteKey(_ key: String) async throws -> Bool

    // MARK: - Value Operations

    /// 获取 String 类型的值
    /// - Parameter key: key 名称
    /// - Returns: 字符串值，nil 表示 key 不存在或类型不匹配
    func getString(_ key: String) async throws -> String?

    /// 获取 Hash 类型的所有字段和值
    /// - Parameter key: key 名称
    /// - Returns: 字段-值映射
    func getHash(_ key: String) async throws -> [String: String]

    /// 获取 List 类型的元素（分页）
    /// - Parameters:
    ///   - key: key 名称
    ///   - start: 起始索引（0-based）
    ///   - stop: 结束索引（-1 表示到最后）
    /// - Returns: 元素列表
    func getList(_ key: String, start: Int, stop: Int) async throws -> [String]

    /// 获取 Set 类型的所有成员
    /// - Parameter key: key 名称
    /// - Returns: 成员列表
    func getSet(_ key: String) async throws -> [String]

    /// 获取 ZSet 类型的成员（分页）
    /// - Parameters:
    ///   - key: key 名称
    ///   - start: 起始索引（0-based）
    ///   - stop: 结束索引（-1 表示到最后）
    ///   - withScores: 是否包含分数
    /// - Returns: 成员列表
    func getZSet(_ key: String, start: Int, stop: Int, withScores: Bool) async throws -> [RedisZSetMember]

    // MARK: - Command Execution

    /// 执行原始命令（数组形式）
    /// - Parameter command: 命令及参数数组
    /// - Returns: 命令执行结果
    func executeCommand(_ command: [String]) async throws -> RedisCommandResult

    /// 执行原始命令（字符串形式）
    /// - Parameter commandString: 命令字符串
    /// - Returns: 命令执行结果
    func executeCommandString(_ commandString: String) async throws -> RedisCommandResult

    // MARK: - Server Info

    /// 获取服务器信息
    /// - Parameter section: 信息分区（如 "server", "memory"），nil 表示全部
    /// - Returns: 信息键值对
    func getServerInfo(section: String?) async throws -> [String: String]

    /// 获取当前数据库索引
    /// - Returns: 数据库索引（0-15）
    func getCurrentDatabase() async throws -> Int

    /// 切换数据库
    /// - Parameter index: 数据库索引
    func selectDatabase(_ index: Int) async throws
}
