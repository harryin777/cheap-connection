//
//  WorkspaceManager.swift
//  cheap-connection
//
//  工作区管理器 - 管理独立的工作区状态，解耦左侧资源树选择与右侧工作区
//

import Foundation

// MARK: - Notification Names

extension Notification.Name {
    /// 工作区即将关闭通知（视图收到后应执行断连）
    static let workspaceWillClose = Notification.Name("workspaceWillClose")
    /// 工作区断连完成通知（视图断连完成后发送）
    static let workspaceDidDisconnect = Notification.Name("workspaceDidDisconnect")
}

// MARK: - WorkspaceKind

/// 工作区类型
enum WorkspaceKind: Equatable {
    case mysql
    case redis
}

// MARK: - WorkspaceSession

/// 工作区会话
struct WorkspaceSession: Identifiable, Equatable {
    let id: UUID
    let connectionId: UUID
    let kind: WorkspaceKind
    let createdAt: Date
    var lastActiveAt: Date
    /// 是否正在关闭（用于防止复用正在关闭的 session）
    var isClosing: Bool = false
}

// MARK: - WorkspaceManager

/// 工作区管理器
/// 负责管理独立的工作区状态，让左侧资源树选择只影响浏览焦点，不直接销毁右侧工作区
@MainActor
@Observable
final class WorkspaceManager {
    // MARK: - State

    /// 当前激活的工作区 ID
    var activeWorkspaceId: UUID?

    /// 所有打开的工作区会话（按 workspaceId 索引）
    var openSessions: [UUID: WorkspaceSession] = [:]

    /// 工作区激活时的回调（用于记录连接使用时间）
    var onWorkspaceActivated: ((UUID) -> Void)?

    /// 等待断连的 continuation（用于 closeWorkspace 等待视图断连完成）
    private var pendingDisconnectContinuations: [UUID: CheckedContinuation<Void, Never>] = [:]

    // MARK: - Computed Properties

    /// 当前激活工作区对应的连接 ID
    var activeConnectionId: UUID? {
        guard let workspaceId = activeWorkspaceId,
              let session = openSessions[workspaceId] else {
            return nil
        }
        return session.connectionId
    }

    /// 当前激活工作区的类型
    var activeKind: WorkspaceKind? {
        guard let workspaceId = activeWorkspaceId,
              let session = openSessions[workspaceId] else {
            return nil
        }
        return session.kind
    }

    /// 当前激活的工作区会话
    var activeSession: WorkspaceSession? {
        guard let workspaceId = activeWorkspaceId else { return nil }
        return openSessions[workspaceId]
    }

    // MARK: - Public Methods

    /// 打开工作区
    /// - Parameters:
    ///   - connectionId: 连接 ID
    ///   - kind: 工作区类型
    /// - Returns: 工作区 ID
    @discardableResult
    func openWorkspace(for connectionId: UUID, kind: WorkspaceKind) -> UUID {
        // 检查是否已有该连接的工作区（跳过正在关闭的）
        if let existingSession = openSessions.values.first(where: { $0.connectionId == connectionId && !$0.isClosing }) {
            // 激活已存在的工作区
            activateWorkspace(existingSession.id)
            return existingSession.id
        }

        // 记录旧工作区 ID，用于后台关闭
        let oldWorkspaceId = activeWorkspaceId

        // 立即创建并激活新工作区（不阻塞等待旧工作区断连）
        let workspaceId = UUID()
        let now = Date()
        let session = WorkspaceSession(
            id: workspaceId,
            connectionId: connectionId,
            kind: kind,
            createdAt: now,
            lastActiveAt: now
        )

        openSessions[workspaceId] = session
        activeWorkspaceId = workspaceId

        // 记录连接使用
        onWorkspaceActivated?(connectionId)

        // 后台异步关闭旧工作区（不阻塞当前操作）
        if let oldId = oldWorkspaceId {
            closeWorkspaceAsync(oldId)
        }

        return workspaceId
    }

    /// 激活工作区
    /// - Parameter workspaceId: 工作区 ID
    /// - Note: 如果当前有其他活跃工作区，会在后台异步关闭它
    func activateWorkspace(_ workspaceId: UUID) {
        guard var session = openSessions[workspaceId] else { return }

        // 如果要激活的是当前已经激活的工作区，直接返回
        if activeWorkspaceId == workspaceId {
            return
        }

        // 记录旧工作区 ID，用于后台关闭
        let oldWorkspaceId = activeWorkspaceId

        // 立即激活新工作区（不阻塞等待旧工作区断连）
        session.lastActiveAt = Date()
        openSessions[workspaceId] = session
        activeWorkspaceId = workspaceId

        // 记录连接使用
        onWorkspaceActivated?(session.connectionId)

        // 后台异步关闭旧工作区（不阻塞当前操作）
        if let oldId = oldWorkspaceId {
            closeWorkspaceAsync(oldId)
        }
    }

    /// 异步关闭工作区（发送关闭通知，不等待完成）
    /// - Parameter workspaceId: 工作区 ID
    private func closeWorkspaceAsync(_ workspaceId: UUID) {
        guard var session = openSessions[workspaceId] else { return }

        // 立即标记为关闭中，防止被复用
        session.isClosing = true
        openSessions[workspaceId] = session

        // 发送关闭通知，让视图执行断连
        // 视图断连完成后会调用 notifyDisconnectComplete，届时再清理 session
        NotificationCenter.default.post(name: .workspaceWillClose, object: workspaceId)
    }

    /// 关闭工作区
    /// - Parameter workspaceId: 工作区 ID
    /// - Note: 此方法会等待视图断连完成后再移除 session，避免 fire-and-forget 问题
    func closeWorkspace(_ workspaceId: UUID) {
        // 检查 session 是否存在
        guard var session = openSessions[workspaceId] else { return }

        // 立即标记为关闭中，防止被复用
        session.isClosing = true
        openSessions[workspaceId] = session

        // 使用 Task 等待断连完成
        Task {
            await withCheckedContinuation { continuation in
                // 存储 continuation，让 workspaceDidDisconnect 通知恢复它
                pendingDisconnectContinuations[workspaceId] = continuation

                // 发送关闭通知，让工作区视图执行断连
                NotificationCenter.default.post(name: .workspaceWillClose, object: workspaceId)
            }

            // 断连完成后，移除会话
            openSessions.removeValue(forKey: workspaceId)

            // 如果关闭的是当前激活的工作区，清除激活状态
            if activeWorkspaceId == workspaceId {
                activeWorkspaceId = nil
            }
        }
    }

    /// 通知工作区断连完成（由视图在断连后调用）
    func notifyDisconnectComplete(_ workspaceId: UUID) {
        // 处理 async closeWorkspace 的 continuation
        if let continuation = pendingDisconnectContinuations.removeValue(forKey: workspaceId) {
            continuation.resume()
        }

        // 清理 session
        openSessions.removeValue(forKey: workspaceId)
    }

    /// 关闭指定连接的所有工作区
    /// - Parameter connectionId: 连接 ID
    func closeWorkspaces(forConnection connectionId: UUID) {
        let workspacesToClose = openSessions.values
            .filter { $0.connectionId == connectionId }
            .map(\.id)

        for workspaceId in workspacesToClose {
            closeWorkspace(workspaceId)
        }
    }

    /// 检查指定连接是否有打开的工作区
    /// - Parameter connectionId: 连接 ID
    /// - Returns: 是否有打开的工作区
    func hasOpenWorkspace(for connectionId: UUID) -> Bool {
        return openSessions.values.contains { $0.connectionId == connectionId && !$0.isClosing }
    }

    /// 获取指定连接的工作区 ID
    /// - Parameter connectionId: 连接 ID
    /// - Returns: 工作区 ID（如果存在）
    func workspaceId(for connectionId: UUID) -> UUID? {
        return openSessions.values.first { $0.connectionId == connectionId && !$0.isClosing }?.id
    }
}
