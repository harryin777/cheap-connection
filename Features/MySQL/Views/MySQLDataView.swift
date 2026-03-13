//
//  MySQLDataView.swift
//  cheap-connection
//
//  MySQL数据浏览视图 - DataGrip风格工具栏和紧凑表格
//

import SwiftUI

/// MySQL数据浏览视图 - DataGrip风格
struct MySQLDataView: View {
    let result: MySQLQueryResult?
    @Binding var pagination: PaginationState
    let isLoading: Bool
    let onLoadPage: (Int) async -> Void
    let onRefresh: () async -> Void
    var onCellEdit: ((Int, Int, String) async -> Void)? = nil  // rowIndex, columnIndex, newValue

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbarView

            Divider()

            // 内容区域
            Group {
                if isLoading {
                    loadingView
                } else if let result = result {
                    if result.hasResults {
                        MySQLResultView(result: result, onCellEdit: onCellEdit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = result.error {
                        errorView(error: error)
                    } else {
                        emptyResultView
                    }
                } else {
                    noDataView
                }
            }
        }
    }

    // MARK: - Subviews

    private var toolbarView: some View {
        HStack(spacing: 8) {
            // 刷新按钮
            Button {
                Task {
                    await onRefresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("刷新数据")
            .disabled(isLoading)

            Divider()
                .frame(height: 16)

            // 分页控制
            if let result = result, result.hasResults {
                paginationControls(result: result)
            }

            Spacer()

            // 加载指示器
            if isLoading {
                ProgressView()
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor))
    }

    @ViewBuilder
    private func paginationControls(result: MySQLQueryResult) -> some View {
        HStack(spacing: 4) {
            // 上一页
            Button {
                Task {
                    let newOffset = max(0, pagination.offset - pagination.pageSize)
                    await onLoadPage(newOffset)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .disabled(!pagination.hasPrevious)

            // 行范围显示
            Text("\(pagination.startRow)-\(pagination.startRow + result.rowCount - 1)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(minWidth: 50)

            // 下一页
            Button {
                Task {
                    let newOffset = pagination.offset + pagination.pageSize
                    await onLoadPage(newOffset)
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .disabled(!pagination.hasNext)

            // 行数信息
            Text("共 \(pagination.totalCount ?? result.rowCount) 行")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.regular)

            Text("加载数据中...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(error: AppError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("查询错误")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("重试") {
                Task {
                    await onRefresh()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyResultView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("查询成功，无数据")
                .font(.headline)

            Text("执行成功但未返回数据行")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tablecells")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("请选择表查看数据")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("从左侧选择一个表以浏览数据")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    let result = MySQLQueryResult(
        columns: ["id", "name", "email", "created_at"],
        rows: [MySQLRowValue.previewRow],
        executionInfo: MySQLExecutionInfo(executedAt: Date(), duration: 0.0234, affectedRows: nil, isQuery: true),
        error: nil
    )

    MySQLDataView(
        result: result,
        pagination: .constant(PaginationState()),
        isLoading: false,
        onLoadPage: { _ in },
        onRefresh: {}
    )
    .frame(width: 600, height: 400)
}
