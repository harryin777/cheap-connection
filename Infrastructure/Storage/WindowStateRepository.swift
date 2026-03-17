//
//  WindowStateRepository.swift
//  cheap-connection
//
//  窗口状态仓储 - 持久化窗口位置/大小/分割比例
//

import Foundation
import AppKit

/// 窗口状态
struct WindowState: Codable, Equatable {
    var windowX: CGFloat?
    var windowY: CGFloat?
    var windowWidth: CGFloat?
    var windowHeight: CGFloat?
    var sidebarWidth: CGFloat?
    var editorHeight: CGFloat?

    /// 默认状态
    static let `default` = WindowState(
        windowX: nil,
        windowY: nil,
        windowWidth: 1100,
        windowHeight: 700,
        sidebarWidth: 280,
        editorHeight: 200
    )
}

/// 窗口状态仓储
final class WindowStateRepository: Sendable {
    static let shared = WindowStateRepository()

    /// 存储文件名
    private let fileName = "windowState.json"

    /// 文件管理器
    private let fileManager = FileManager.default

    /// 缓存的状态
    private var cachedState: WindowState?

    /// 保存防抖任务
    private var saveTask: Task<Void, Never>?

    /// 存储目录
    private var storageDirectory: URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return URL(fileURLWithPath: NSTemporaryDirectory())
        }
        let bundleId = Bundle.main.bundleIdentifier ?? "com.yzz.cheap-connection"
        return appSupport.appendingPathComponent(bundleId)
    }

    /// 存储文件路径
    private var storageFile: URL {
        storageDirectory.appendingPathComponent(fileName)
    }

    private init() {
        ensureDirectoryExists()
    }

    // MARK: - Public API

    /// 加载窗口状态
    func load() -> WindowState {
        if let cached = cachedState {
            return cached
        }

        guard fileManager.fileExists(atPath: storageFile.path) else {
            cachedState = .default
            return .default
        }

        do {
            let data = try Data(contentsOf: storageFile)
            let decoder = JSONDecoder()
            let state = try decoder.decode(WindowState.self, from: data)
            cachedState = state
            return state
        } catch {
            cachedState = .default
            return .default
        }
    }

    /// 保存窗口状态（带防抖）
    func save(_ state: WindowState) {
        cachedState = state

        // 取消之前的保存任务
        saveTask?.cancel()

        // 延迟保存，避免频繁写入
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

            if !Task.isCancelled {
                await saveImmediately(state)
            }
        }
    }

    /// 立即保存（用于应用退出时）
    func saveSync(_ state: WindowState) {
        cachedState = state
        writeState(state)
    }

    // MARK: - Private

    private func ensureDirectoryExists() {
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }

    private func saveImmediately(_ state: WindowState) async {
        await withCheckedContinuation { continuation in
            writeState(state)
            continuation.resume()
        }
    }

    private func writeState(_ state: WindowState) {
        ensureDirectoryExists()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(state)
            try data.write(to: storageFile, options: .atomic)
        } catch {
            // 静默失败，窗口状态丢失不影响核心功能
        }
    }
}
