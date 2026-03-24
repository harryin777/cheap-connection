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
            // GPT TODO: 这里左右翻页按钮“很难按中”的直接原因不是分页逻辑，而是交互热区太小。
            // 当前 plain button 的 label 只有一个 11pt 的 chevron，没有额外 padding、min frame 或 contentShape，
            // 实际可点击区域几乎就贴着图标本身。glm5 修这个问题时不能只把图标字号从 11 改到 12/13，
            // 那样命中率提升非常有限；应该显式给按钮增加最小点击尺寸（例如 20~24pt 高宽）和稳定 hit area。
            .buttonStyle(.plain)
            .disabled(!pagination.hasPrevious)
            // GPT NOTE: 这里还要注意保持视觉紧凑和交互热区分离：
            // 可以让图标看起来仍然小，但外层 frame/contentShape 更大。否则会在密集工具栏里继续出现
            // “视觉上像按钮、实际上很难点中”的问题。

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
            // GPT TODO: 右翻页按钮和左翻页按钮是同一类问题，不能只修左边。
            // 这里同样缺少 padding / min frame / contentShape，导致用户必须非常精准地点到小 chevron 图标。
            // glm5 需要把左右两个翻页按钮抽成同一套 hit area 规则，避免一边修了另一边继续难点。
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
        error: nil,
        totalCount: 1000
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
