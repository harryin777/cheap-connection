//
//  KeyboardShortcuts.swift
//  cheap-connection
//
//  全局快捷键通知定义
//

import Foundation

// MARK: - Notification Names

extension Notification.Name {
    /// 新建连接 (Cmd+N)
    static let showCreateConnection = Notification.Name("showCreateConnection")

    /// 打开 SQL 文件 (Cmd+O)
    static let openSQLFile = Notification.Name("openSQLFile")

    /// 执行 SQL (Cmd+Enter)
    static let executeSQL = Notification.Name("executeSQL")

    /// 刷新数据 (Cmd+R)
    static let refreshData = Notification.Name("refreshData")

    /// 保存 SQL 文件 (Cmd+S)
    static let saveSQLFile = Notification.Name("saveSQLFile")

    /// 清空编辑器 (Cmd+K)
    static let clearEditor = Notification.Name("clearEditor")

    /// 切换历史面板 (Cmd+H)
    static let toggleHistory = Notification.Name("toggleHistory")
}

// MARK: - Notification Helpers

enum KeyboardShortcutNotifier {
    /// 发送新建连接通知
    static func notifyCreateConnection() {
        NotificationCenter.default.post(name: .showCreateConnection, object: nil)
    }

    /// 发送打开 SQL 文件通知
    static func notifyOpenSQLFile() {
        NotificationCenter.default.post(name: .openSQLFile, object: nil)
    }

    /// 发送执行 SQL 通知
    static func notifyExecuteSQL() {
        NotificationCenter.default.post(name: .executeSQL, object: nil)
    }

    /// 发送刷新数据通知
    static func notifyRefreshData() {
        NotificationCenter.default.post(name: .refreshData, object: nil)
    }

    /// 发送保存 SQL 文件通知
    static func notifySaveSQLFile() {
        NotificationCenter.default.post(name: .saveSQLFile, object: nil)
    }

    /// 发送清空编辑器通知
    static func notifyClearEditor() {
        NotificationCenter.default.post(name: .clearEditor, object: nil)
    }

    /// 发送切换历史面板通知
    static func notifyToggleHistory() {
        NotificationCenter.default.post(name: .toggleHistory, object: nil)
    }
}

// MARK: - Notification Publisher Convenience

extension NotificationCenter {
    /// 发布通知的便捷方法
    func post(name: Notification.Name) {
        post(name: name, object: nil)
    }
}
