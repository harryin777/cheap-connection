//
//  RedisCommandResultView.swift
//  cheap-connection
//
//  Redis 命令结果展示
//

import SwiftUI

struct RedisCommandResultView: View {
    let result: RedisCommandResult

    @State private var showFullValue: Bool = false
    private let previewLimit: Int = 10000

    var body: some View {
        VStack(spacing: 0) {
            resultHeader
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if result.success {
                        successContent
                    } else {
                        errorContent
                    }
                }
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private var resultHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(result.success ? .green : .red)

            Text(result.success ? "执行成功" : "执行失败")
                .font(.system(size: 11, weight: .medium))

            Spacer()

            Label(result.formattedDuration, systemImage: "clock")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            if let affected = result.affectedKeys {
                Label("\(affected) 个 key", systemImage: "key")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private var successContent: some View {
        if let value = result.value {
            switch value {
            case .null:
                Text("(nil)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
            case .string(let string):
                stringView(string)
            case .int(let integer):
                styledScalarView("(integer) \(integer)", color: .blue)
            case .double(let number):
                styledScalarView("(double) \(String(format: "%.6g", number))", color: .purple)
            case .status(let status):
                styledScalarView(status, color: .green)
            case .error(let message):
                styledScalarView("(error) \(message)", color: .red)
            case .array(let array):
                arrayView(array)
            case .data(let data):
                dataView(data)
            case .map(let dictionary):
                mapView(dictionary)
            }
        } else {
            Text("OK")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func styledScalarView(_ text: String, color: Color) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .foregroundStyle(color)
            Spacer()
        }
    }

    @ViewBuilder
    private func stringView(_ string: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if showFullValue || string.count <= previewLimit {
                textPreview(string)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    textPreview(String(string.prefix(previewLimit)))

                    HStack {
                        Text("已截断显示，共 \(string.count) 字符")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Button("显示完整内容") {
                            showFullValue = true
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                    }
                }
            }

            HStack(spacing: 16) {
                Label("\(string.count) 字符", systemImage: "textformat")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Label("\(string.utf8.count) 字节", systemImage: "memorychip")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func textPreview(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .textSelection(.enabled)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)
    }

    @ViewBuilder
    private func arrayView(_ array: [RedisValue]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(array.count) 个元素")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            ForEach(array.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .frame(width: 30, alignment: .trailing)

                    arrayElementView(array[index])
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func arrayElementView(_ value: RedisValue) -> some View {
        switch value {
        case .null:
            Text("(nil)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        case .string(let string):
            Text(string.count > 200 ? String(string.prefix(200)) + "..." : string)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
        case .int(let integer):
            styledScalarView("(integer) \(integer)", color: .blue)
        case .double(let number):
            styledScalarView("(double) \(String(format: "%.6g", number))", color: .purple)
        case .status(let status):
            styledScalarView(status, color: .green)
        case .error(let message):
            styledScalarView("(error) \(message)", color: .red)
        case .data(let data):
            Text("<\(data.count) 字节数据>")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        case .array(let array):
            Text("[\(array.count) 个元素]")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        case .map(let dictionary):
            Text("{\(dictionary.count) 个字段}")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func dataView(_ data: Data) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("<\(data.count) 字节数据>")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)

            if data.count <= 1024 {
                let hex = data.map { String(format: "%02x", $0) }.joined(separator: " ")
                textPreview(hex)
                    .font(.system(size: 10, design: .monospaced))
            }
        }
    }

    @ViewBuilder
    private func mapView(_ dictionary: [String: RedisValue]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(dictionary.count) 个字段")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            let sortedKeys = dictionary.keys.sorted()
            ForEach(sortedKeys, id: \.self) { key in
                HStack(alignment: .top, spacing: 0) {
                    Text(key)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(width: 150, alignment: .leading)
                        .padding(.trailing, 12)

                    if let value = dictionary[key] {
                        arrayElementView(value)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var errorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)

                Text("执行出错")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let message = result.errorMessage {
                Text(message)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }
}
