//
//  RedisWorkspaceContentViews.swift
//  cheap-connection
//
//  Redis 工作区内容视图拆分
//

import SwiftUI

extension RedisWorkspaceView {
    @ViewBuilder
    var connectedView: some View {
        if displayMode == .editorOnly {
            RedisEditorView(
                commandText: $commandText,
                history: service?.session.commandHistory ?? [],
                serverVersion: service?.session.serverVersion,
                selectedDatabase: service?.session.selectedDatabase,
                onExecute: { command in
                    await executeCommand(command)
                },
                isExecuting: isLoadingCommand,
                activeWorkspaceTab: nil,
                onSelectWorkspaceTab: { tab in
                    selectedTab = tab
                    displayMode = .keyDetail(tab)
                }
            )
        } else {
            SplitView(
                topView: AnyView(
                    RedisEditorView(
                        commandText: $commandText,
                        history: service?.session.commandHistory ?? [],
                        serverVersion: service?.session.serverVersion,
                        selectedDatabase: service?.session.selectedDatabase,
                        onExecute: { command in
                            await executeCommand(command)
                        },
                        isExecuting: isLoadingCommand,
                        activeWorkspaceTab: selectedTab,
                        onSelectWorkspaceTab: { tab in
                            selectedTab = tab
                            displayMode = .keyDetail(tab)
                        }
                    )
                ),
                bottomView: AnyView(bottomContentView),
                topHeight: $editorHeight,
                minTopHeight: 120,
                minBottomHeight: 100
            )
        }
    }

    @ViewBuilder
    var bottomContentView: some View {
        switch displayMode {
        case .editorOnly:
            EmptyView()
        case .commandResult:
            commandResultView
        case .keyDetail:
            keyDetailView
        }
    }

    @ViewBuilder
    var commandResultView: some View {
        if isLoadingCommand {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("执行中...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let commandResult {
            RedisCommandResultView(result: commandResult)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "terminal")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)

                Text("命令结果")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("输入命令后点击执行查看结果")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    var keyDetailView: some View {
        switch selectedTab {
        case .keys:
            keyBrowserView
        case .result:
            commandResultView
        }
    }

    @ViewBuilder
    var keyBrowserView: some View {
        HSplitView {
            RedisKeyListView(
                keys: keys,
                selectedKey: selectedKey,
                searchPattern: $searchPattern,
                hasMoreKeys: hasMoreKeys,
                isLoading: isLoadingKeys,
                onSelectKey: { key in selectKey(key) },
                onLoadMore: { await loadMoreKeys() },
                onRefresh: { await refreshKeys() },
                onSearch: { await searchKeys($0) }
            )
            .frame(minWidth: 200, idealWidth: sidebarWidth, maxWidth: 400)

            keyValueDetailView
                .frame(minWidth: 400)
        }
    }

    @ViewBuilder
    var keyValueDetailView: some View {
        if selectedKey != nil {
            VStack(spacing: 0) {
                if let selectedKeyDetail {
                    RedisKeyDetailHeaderView(detail: selectedKeyDetail)
                    Divider()
                }

                valueView
            }
        } else if isLoadingDetail {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("加载中...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)

                Text("选择一个 Key")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("从左侧列表选择一个 key 查看详情")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    var valueView: some View {
        if isLoadingValue {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("加载值...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let selectedKeyDetail {
            switch selectedKeyDetail.type {
            case .string:
                RedisStringValueView(value: stringValue)
            case .hash:
                RedisHashValueView(value: hashValue)
            case .list:
                RedisListValueView(value: listValue)
            case .set:
                RedisSetValueView(value: setValue)
            case .zset:
                RedisZSetValueView(value: zsetValue)
            case .none:
                Text("Key 不存在")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            default:
                Text("不支持的类型: \(selectedKeyDetail.type.displayName)")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            EmptyView()
        }
    }
}
