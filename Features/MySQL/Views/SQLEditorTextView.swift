//
//  SQLEditorTextView.swift
//  cheap-connection
//
//  SQL 编辑器 TextView - 支持选中范围和光标位置追踪
//

import SwiftUI
import AppKit

/// 光标在编辑器中的位置信息
struct CursorRectInfo {
    let x: CGFloat      // 相对于编辑器左边缘的 X 坐标
    let y: CGFloat      // 相对于编辑器顶边缘的 Y 坐标
    let height: CGFloat // 行高
    let lineNumber: Int // 行号（从 1 开始）
}

/// SQL 编辑器 TextView - 支持选中范围和光标位置追踪
struct SQLEditorTextView: NSViewRepresentable {
    @Binding var text: String
    var onSelectionChange: ((NSRange, String) -> Void)?
    var onCursorPositionChange: ((Int) -> Void)?
    var onCursorRectChange: ((CursorRectInfo) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.insertionPointColor = NSColor.labelColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.lineFragmentPadding = 0

        // 设置初始文本
        textView.string = text

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // 只在文本真正改变时更新
        if textView.string != text {
            // 保存当前选中范围
            let selectedRange = textView.selectedRange()

            textView.string = text

            // 尝试恢复选中范围（如果有效）
            if selectedRange.location + selectedRange.length <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }

        // 只在选区/光标真正变化时才回调，避免 resize 期间重复触发 SwiftUI setState
        let selectedRange = textView.selectedRange()

        // 选中范围变化时才回调（使用 coordinator 级别的缓存去重）
        if selectedRange.length > 0 {
            if context.coordinator.lastReportedSelection != selectedRange {
                context.coordinator.lastReportedSelection = selectedRange
                let startIndex = text.index(text.startIndex, offsetBy: selectedRange.location)
                let endIndex = text.index(startIndex, offsetBy: min(selectedRange.length, text.count - selectedRange.location))
                let selectedText = String(text[startIndex..<endIndex])
                context.coordinator.parent?.onSelectionChange?(selectedRange, selectedText)
            }
        }

        // 光标位置变化时才回调
        let cursorPosition = selectedRange.location
        if context.coordinator.lastReportedCursor != cursorPosition {
            context.coordinator.lastReportedCursor = cursorPosition
            context.coordinator.parent?.onCursorPositionChange?(cursorPosition)

            // 同时更新光标矩形
            if let cursorRect = getCursorRect(textView: textView, position: cursorPosition) {
                context.coordinator.parent?.onCursorRectChange?(cursorRect)
            }
        }
    }

    /// 获取光标在编辑器中的位置信息
    private func getCursorRect(textView: NSTextView, position: Int) -> CursorRectInfo? {
        guard position >= 0 && position <= textView.string.count else { return nil }

        let text = textView.string
        guard position <= text.utf16.count else { return nil }

        // 获取光标位置的 glyph range
        let utf16Index = text.utf16.index(text.utf16.startIndex, offsetBy: position)
        let stringIndex = String.Index(utf16Index, within: text) ?? text.endIndex
        let charIndex = text.distance(from: text.startIndex, to: stringIndex)

        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }

        // 获取该字符位置的 glyph index
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)

        // 获取该 glyph 的 bounding rect
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 0), in: textContainer)

        // 考虑 textContainerInset
        let inset = textView.textContainerInset
        let x = glyphRect.minX + inset.width
        let y = glyphRect.minY + inset.height

        // 计算行号
        let lineNumber = (text as NSString).substring(to: charIndex).components(separatedBy: .newlines).count

        return CursorRectInfo(x: x, y: y, height: glyphRect.height, lineNumber: lineNumber)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SQLEditorTextView?
        // 去重缓存：避免 resize 期间重复触发 SwiftUI setState
        var lastReportedSelection: NSRange?
        var lastReportedCursor: Int?

        init(_ parent: SQLEditorTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent?.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let selectedRange = textView.selectedRange()

            if let parent = parent {
                // 通知选中范围变化（只在真正变化时回调）
                if selectedRange.length > 0 {
                    if lastReportedSelection != selectedRange {
                        lastReportedSelection = selectedRange
                        let text = textView.string
                        let startIndex = text.index(text.startIndex, offsetBy: selectedRange.location)
                        let endIndex = text.index(startIndex, offsetBy: min(selectedRange.length, text.count - selectedRange.location))
                        let selectedText = String(text[startIndex..<endIndex])
                        parent.onSelectionChange?(selectedRange, selectedText)
                    }
                }

                // 通知光标位置变化（只在真正变化时回调）
                if lastReportedCursor != selectedRange.location {
                    lastReportedCursor = selectedRange.location
                    parent.onCursorPositionChange?(selectedRange.location)

                    // 同时更新光标矩形
                    if let cursorRect = parent.getCursorRect(textView: textView, position: selectedRange.location) {
                        parent.onCursorRectChange?(cursorRect)
                    }
                }
            }
        }
    }
}
