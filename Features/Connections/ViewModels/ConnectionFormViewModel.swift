//
//  ConnectionFormViewModel.swift
//  cheap-connection
//
//  连接表单视图模型
//

import Foundation
import SwiftUI

/// 连接表单视图模型
@MainActor
@Observable
final class ConnectionFormViewModel {
    // MARK: - State

    /// 表单数据
    var formData: ConnectionFormData

    /// 是否处于编辑模式
    let isEditing: Bool

    /// 正在编辑的连接 ID（编辑模式下使用）
    let editingConnectionId: UUID?

    /// 错误信息
    var errorMessage: String?

    /// 是否正在保存
    var isSaving: Bool = false

    // MARK: - Callbacks

    /// 保存成功后的回调
    var onSave: ((ConnectionConfig, String?) -> Void)?

    // MARK: - Init

    /// 新建模式
    init() {
        self.formData = ConnectionFormData()
        self.isEditing = false
        self.editingConnectionId = nil
    }

    /// 编辑模式
    init(config: ConnectionConfig) {
        self.formData = ConnectionFormData(config: config)
        self.isEditing = true
        self.editingConnectionId = config.id
    }

    // MARK: - Actions

    /// 当数据库类型变化时
    func onDatabaseKindChange() {
        formData.updatePortForDatabaseKind()
    }

    /// 保存连接
    func save(using connectionManager: ConnectionManager) {
        // 验证
        if let error = formData.validate() {
            errorMessage = error
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let config = formData.toConfig(id: editingConnectionId)

            // 判断是新密码还是保持原密码
            let password: String?
            if isEditing && formData.password.isEmpty {
                // 编辑模式下，如果密码为空，保持原密码（传 nil）
                password = nil
            } else {
                // 否则使用新密码（可能是空字符串，表示删除密码）
                password = formData.password
            }

            if isEditing {
                try connectionManager.updateConnection(config, password: password)
            } else {
                try connectionManager.createConnection(config, password: password)
            }

            onSave?(config, password)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
