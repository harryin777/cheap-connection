//
//  MySQLValueConverter.swift
//  cheap-connection
//
//  MySQL值转换工具
//

import Foundation
import MySQLKit
import MySQLNIO
import NIOCore

/// MySQL行值转换器
enum MySQLValueConverter {
    /// 将 MySQLData 转换为 MySQLRowValue
    static func convertRowValue(_ data: MySQLData?) -> MySQLRowValue {
        guard let data = data else { return .null }

        // 检查是否为 null (buffer 为 nil)
        if data.buffer == nil {
            return .null
        }

        // 日期时间类按 MySQL 原始字段格式输出
        if let mysqlTime = data.time {
            return .string(formatMySQLTime(mysqlTime, type: data.type))
        }

        if let stringValue = data.string {
            return .string(stringValue)
        }

        if let intValue = data.int {
            return .int(intValue)
        }

        if let doubleValue = data.double {
            return .double(doubleValue)
        }

        if let dateValue = data.date {
            return .date(dateValue)
        }

        // 对于 binary data，尝试获取 buffer
        if let buffer = data.buffer {
            let bytes = buffer.readableBytesView
            return .data(Data(bytes))
        }

        return .null
    }

    /// 格式化 MySQL 时间类型
    static func formatMySQLTime(_ value: MySQLTime, type: MySQLProtocol.DataType) -> String {
        let year = value.year.map(Int.init)
        let month = value.month.map(Int.init)
        let day = value.day.map(Int.init)
        let hour = value.hour.map(Int.init)
        let minute = value.minute.map(Int.init)
        let second = value.second.map(Int.init)
        let microsecond = value.microsecond.map(Int.init) ?? 0

        let hasDate = year != nil && month != nil && day != nil
        let hasTime = hour != nil && minute != nil && second != nil

        let microsecondPart: String = {
            guard microsecond > 0 else { return "" }
            return String(format: ".%06d", microsecond)
        }()

        switch type {
        case .date:
            if hasDate {
                return String(format: "%04d-%02d-%02d", year!, month!, day!)
            }
        case .time:
            if hasTime {
                return String(format: "%02d:%02d:%02d%@", hour!, minute!, second!, microsecondPart)
            }
        case .datetime, .timestamp:
            if hasDate && hasTime {
                return String(
                    format: "%04d-%02d-%02d %02d:%02d:%02d%@",
                    year!, month!, day!, hour!, minute!, second!, microsecondPart
                )
            }
        default:
            break
        }

        if hasDate && hasTime {
            return String(
                format: "%04d-%02d-%02d %02d:%02d:%02d%@",
                year!, month!, day!, hour!, minute!, second!, microsecondPart
            )
        }
        if hasDate {
            return String(format: "%04d-%02d-%02d", year!, month!, day!)
        }
        if hasTime {
            return String(format: "%02d:%02d:%02d%@", hour!, minute!, second!, microsecondPart)
        }

        return ""
    }
}
