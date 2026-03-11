//
//  PaginationState.swift
//  cheap-connection
//
//  分页状态模型
//

import Foundation

/// 分页状态
struct PaginationState: Equatable {
    var page: Int
    var pageSize: Int
    var totalCount: Int?
    var hasMore: Bool

    init(
        page: Int = 1,
        pageSize: Int = 100,
        totalCount: Int? = nil,
        hasMore: Bool = false
    ) {
        self.page = page
        self.pageSize = pageSize
        self.totalCount = totalCount
        self.hasMore = hasMore
    }

    /// 计算偏移量
    var offset: Int {
        (page - 1) * pageSize
    }

    /// 当前页的起始行号（从1开始）
    var startRow: Int {
        offset + 1
    }

    /// 当前页的结束行号
    var endRow: Int {
        offset + pageSize
    }

    /// 总页数（如果知道总数）
    var totalPages: Int? {
        guard let total = totalCount else { return nil }
        return (total + pageSize - 1) / pageSize
    }

    /// 是否有上一页
    var hasPrevious: Bool {
        page > 1
    }

    /// 是否有下一页
    var hasNext: Bool {
        hasMore
    }

    /// 下一页
    mutating func nextPage() {
        page += 1
    }

    /// 上一页
    mutating func previousPage() {
        if page > 1 {
            page -= 1
        }
    }

    /// 重置到首页
    mutating func reset() {
        page = 1
        hasMore = false
        totalCount = nil
    }

    /// 跳转到指定页
    mutating func goTo(page: Int) {
        self.page = max(1, page)
    }

    /// 更新分页状态
    mutating func update(hasMore: Bool, totalCount: Int? = nil) {
        self.hasMore = hasMore
        self.totalCount = totalCount
    }
}
