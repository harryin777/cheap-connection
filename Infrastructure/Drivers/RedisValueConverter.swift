//
//  RedisValueConverter.swift
//  cheap-connection
//
//  Redis值转换工具 - 将 RediStack 的 RESPValue 转换为领域模型
//

import Foundation
@preconcurrency import RediStack
import NIOCore

/// Redis值转换器
enum RedisValueConverter {

    // MARK: - RESPValue to RedisValue

    /// 将 RESPValue 转换为 RedisValue
    nonisolated static func convertRESPValue(_ value: RESPValue) -> RedisValue {
        if value.isNull {
            return .null
        }

        if let stringValue = value.string {
            return .string(stringValue)
        }

        if let intValue = value.int {
            return .int(intValue)
        }

        // 尝试解析 double（从字符串）
        if let stringValue = value.string,
           let doubleValue = Double(stringValue) {
            return .double(doubleValue)
        }

        if let errorValue = value.error {
            return .error(errorValue.message)
        }

        if let arrayValue = value.array {
            let converted = arrayValue.map { convertRESPValue($0) }
            return .array(converted)
        }

        // 尝试作为数据
        if let data = value.data {
            return .data(data)
        }

        return .null
    }

    // MARK: - SCAN Result

    /// 转换 SCAN 命令结果
    nonisolated static func convertScanResult(_ value: RESPValue) throws -> RedisScanResult {
        guard let array = value.array, array.count >= 2 else {
            throw AppError.decodingError("SCAN 结果格式无效")
        }

        // 第一个元素是游标
        let cursor: Int
        if let cursorString = array[0].string {
            cursor = Int(cursorString) ?? 0
        } else if let cursorInt = array[0].int {
            cursor = cursorInt
        } else {
            cursor = 0
        }

        // 第二个元素是 key 列表
        var keys: [String] = []
        if let keyArray = array[1].array {
            keys = keyArray.compactMap { $0.string }
        }

        return RedisScanResult(nextCursor: cursor, keys: keys)
    }

    // MARK: - Hash Result

    /// 转换 HGETALL 命令结果为字典
    nonisolated static func convertHashResult(_ value: RESPValue) -> [String: String] {
        guard let array = value.array else {
            return [:]
        }

        var result: [String: String] = [:]

        // HGETALL 返回的是 [field1, value1, field2, value2, ...] 格式
        var i = 0
        while i + 1 < array.count {
            if let field = array[i].string, let value = array[i + 1].string {
                result[field] = value
            }
            i += 2
        }

        return result
    }

    // MARK: - Array Result

    /// 转换数组结果为字符串数组
    nonisolated static func convertArrayResult(_ value: RESPValue) -> [String] {
        guard let array = value.array else {
            return []
        }

        return array.compactMap { $0.string }
    }

    // MARK: - ZSet Result

    /// 转换 ZRANGE 命令结果（带分数）
    nonisolated static func convertZSetResult(_ value: RESPValue, withScores: Bool) -> [RedisZSetMember] {
        guard let array = value.array else {
            return []
        }

        if withScores {
            // ZRANGE ... WITHSCORES 返回 [member1, score1, member2, score2, ...]
            var result: [RedisZSetMember] = []
            var i = 0
            while i + 1 < array.count {
                if let member = array[i].string,
                   let scoreStr = array[i + 1].string,
                   let score = Double(scoreStr) {
                    result.append(RedisZSetMember(member: member, score: score))
                }
                i += 2
            }
            return result
        } else {
            // 不带分数，只返回成员
            return array.compactMap { item in
                guard let member = item.string else { return nil }
                return RedisZSetMember(member: member, score: 0)
            }
        }
    }

    // MARK: - Key Summary

    /// 从 key 名称列表创建 RedisKeySummary
    nonisolated static func createKeySummaries(
        keys: [String],
        types: [String: RedisValueType]? = nil,
        ttls: [String: Int]? = nil,
        memorySizes: [String: Int]? = nil
    ) -> [RedisKeySummary] {
        return keys.map { key in
            RedisKeySummary(
                key: key,
                type: types?[key] ?? .unknown,
                ttl: ttls?[key],
                memorySize: memorySizes?[key]
            )
        }
    }
}
