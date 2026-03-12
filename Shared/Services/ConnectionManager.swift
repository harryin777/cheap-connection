//
//  ConnectionManager.swift
//  cheap-connection
//
//  连接管理器 - 统一管理连接配置和状态
//

import Foundation
import SwiftUI

/// 连接管理器
@MainActor
@Observable
final class ConnectionManager {
    // MARK: - State

    /// 所有连接配置
    var connections: [ConnectionConfig] = []

    /// 最近连接记录
    var recentConnections: [RecentConnection] = []

    /// 当前选中的连接 ID
    var selectedConnectionId: UUID?

    /// 当前选中的数据库名（MySQL）
    var selectedDatabaseName: String?

    /// 当前选中的表名（MySQL）
    var selectedTableName: String?

    /// 错误信息
    var errorMessage: String?

    // MARK: - Dependencies

    private let connectionRepository: ConnectionRepositoryProtocol
    private let recentRepository: RecentHistoryRepositoryProtocol
    private let keychainService: KeychainServiceProtocol

    // MARK: - Init

    init(
        connectionRepository: ConnectionRepositoryProtocol = ConnectionRepository.shared,
        recentRepository: RecentHistoryRepositoryProtocol = RecentHistoryRepository.shared,
        keychainService: KeychainServiceProtocol = KeychainService.shared
    ) {
        self.connectionRepository = connectionRepository
        self.recentRepository = recentRepository
        self.keychainService = keychainService
    }

    // MARK: - Public Methods

    /// 加载所有连接配置
    func loadConnections() {
        do {
            connections = try connectionRepository.fetchAll()
            recentConnections = try recentRepository.fetchRecent(limit: 10)
            validateSelection()
            errorMessage = nil
        } catch {
            errorMessage = "加载连接失败: \(error.localizedDescription)"
        }
    }

    /// 创建新连接
    /// - Parameters:
    ///   - config: 连接配置
    ///   - password: 密码（可选）
    func createConnection(_ config: ConnectionConfig, password: String?) throws {
        // 保存密码到 Keychain
        if let password = password, !password.isEmpty {
            try keychainService.savePassword(password, for: config.id)
        }

        // 保存配置
        try connectionRepository.save(config)

        // 刷新列表
        loadConnections()
    }

    /// 更新连接配置
    /// - Parameters:
    ///   - config: 更新后的连接配置
    ///   - password: 新密码（nil 表示不修改，空字符串表示删除密码）
    func updateConnection(_ config: ConnectionConfig, password: String?) throws {
        // 更新密码（如果有新密码）
        if let password = password {
            if password.isEmpty {
                // 删除密码
                try? keychainService.deletePassword(for: config.id)
            } else {
                // 更新密码
                try keychainService.savePassword(password, for: config.id)
            }
        }

        // 更新配置
        try connectionRepository.save(config)

        // 刷新列表
        loadConnections()
    }

    /// 删除连接
    /// - Parameter id: 连接 ID
    func deleteConnection(id: UUID) throws {
        // 删除 Keychain 中的密码
        try? keychainService.deletePassword(for: id)

        // 删除配置
        try connectionRepository.delete(id: id)

        if selectedConnectionId == id {
            selectedConnectionId = nil
            selectedDatabaseName = nil
            selectedTableName = nil
        }

        // 刷新列表
        loadConnections()
    }

    /// 获取连接密码
    /// - Parameter connectionId: 连接 ID
    /// - Returns: 密码（如果存在）
    func getPassword(for connectionId: UUID) throws -> String? {
        return try keychainService.getPassword(for: connectionId)
    }

    /// 记录连接使用
    /// - Parameter connectionId: 连接 ID
    func recordConnectionUsage(_ connectionId: UUID) {
        do {
            try recentRepository.recordConnection(connectionId)
            try connectionRepository.updateLastUsed(id: connectionId)
            recentConnections = try recentRepository.fetchRecent(limit: 10)
        } catch {
            // 记录失败不影响主流程
        }
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    /// 统一更新当前资源选择
    func selectConnection(_ connectionId: UUID?, database: String? = nil, table: String? = nil) {
        selectedConnectionId = connectionId
        selectedDatabaseName = database
        selectedTableName = table
    }

    private func validateSelection() {
        guard let selectedConnectionId else { return }

        if !connections.contains(where: { $0.id == selectedConnectionId }) {
            self.selectedConnectionId = nil
            selectedDatabaseName = nil
            selectedTableName = nil
        }
    }
}
