//
//  MySQLWorkspaceFileTabs.swift
//  cheap-connection
//
//  MySQL 工作区文件导入与编辑器标签管理
//

import Foundation

extension MySQLWorkspaceView {
    func openSQLFile() async {
        guard let openedFile = await SQLFileOperations.openSQLFile() else { return }

        let url = openedFile.url
        let content = openedFile.content

        if let existingTab = editorTabs.first(where: { $0.fileURL == url }) {
            activeEditorTabId = existingTab.id
            sqlText = existingTab.content
        } else {
            let newTab = EditorQueryTab(
                fileURL: url,
                content: content,
                defaultConnectionId: currentQueryConnectionId,
                defaultConnectionName: currentQueryConnectionName,
                defaultDatabase: currentQueryDatabase
            )
            editorTabs.append(newTab)
            activeEditorTabId = newTab.id
            sqlText = content
        }

        displayMode = .editorOnly
    }

    func importSQLFile() async {
        guard let url = await SQLFileOperations.selectSQLFileForImport() else { return }

        do {
            let content = try SQLFileOperations.readFileContents(url: url)
            let statements = SQLFileOperations.parseStatements(from: content)
            await executeSQLStatements(statements)
        } catch {
            errorMessage = "读取文件失败: \(error.localizedDescription)"
            showError = true
        }
    }

    func executeSQLStatements(_ statements: [String]) async {
        showImportProgress = true
        importProgress = 0
        importStatus = "准备执行..."

        let startTime = Date()
        var successCount = 0
        var failedCount = 0
        var errors: [String] = []

        let queryServiceHandle: (service: MySQLService, shouldDisconnect: Bool)
        do {
            queryServiceHandle = try await serviceForQueryConnection(currentQueryConnectionId)
        } catch {
            showImportProgress = false
            errorMessage = error.localizedDescription
            showError = true
            return
        }

        defer {
            if queryServiceHandle.shouldDisconnect {
                Task {
                    await queryServiceHandle.service.disconnect()
                }
            }
        }

        for (index, sql) in statements.enumerated() {
            importProgress = Double(index + 1) / Double(statements.count)
            importStatus = "执行中... (\(index + 1)/\(statements.count))"

            do {
                var processedSQL = sql
                if let currentQueryDatabase {
                    processedSQL = SQLPreprocessor.preprocessSQL(sql, database: currentQueryDatabase)
                }

                let result = try await queryServiceHandle.service.executeSQL(processedSQL)
                if let error = result.error {
                    failedCount += 1
                    errors.append("语句 \(index + 1): \(error.localizedDescription)")
                } else {
                    successCount += 1
                }
            } catch {
                failedCount += 1
                errors.append("语句 \(index + 1): \(error.localizedDescription)")
            }
        }

        showImportProgress = false
        importResult = SQLImportResult(
            success: failedCount == 0,
            totalStatements: statements.count,
            successStatements: successCount,
            failedStatements: failedCount,
            errors: errors,
            duration: Date().timeIntervalSince(startTime)
        )
        showImportResult = true
    }

    func selectEditorTab(_ tabId: UUID) {
        guard let tab = editorTabs.first(where: { $0.id == tabId }) else { return }
        activeEditorTabId = tabId
        sqlText = tab.content
    }

    func closeEditorTab(_ tabId: UUID) {
        guard let index = editorTabs.firstIndex(where: { $0.id == tabId }) else { return }
        syncSQLTextToActiveTab()
        let closingTab = editorTabs[index]
        editorTabs.remove(at: index)

        if activeEditorTabId == tabId {
            if editorTabs.isEmpty {
                activeEditorTabId = nil
                scratchQueryConnectionId = closingTab.queryConnectionId
                scratchQueryConnectionName = closingTab.queryConnectionName
                scratchQueryDatabaseName = closingTab.queryDatabaseName
                sqlText = ""
                sqlResult = nil
                displayMode = .editorOnly
            } else {
                let newIndex = min(index, editorTabs.count - 1)
                let newTab = editorTabs[newIndex]
                activeEditorTabId = newTab.id
                sqlText = newTab.content
            }
        }
    }

    func closeActiveEditorTab() {
        guard let activeEditorTabId else {
            sqlResult = nil
            return
        }

        closeEditorTab(activeEditorTabId)
    }

    func syncSQLTextToActiveTab() {
        guard let activeEditorTabId,
              let index = editorTabs.firstIndex(where: { $0.id == activeEditorTabId }) else { return }
        editorTabs[index].content = sqlText
    }
}
