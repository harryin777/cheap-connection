//
//  SQLEditorTextView.swift
//  cheap-connection
//
//  SQL 编辑器 TextView - 支持选中范围和光标位置追踪
//

import SwiftUI
import AppKit

private enum SQLSyntaxHighlighter {
    static let keywordColor = NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.32, alpha: 1.0)
    static let commentColor = NSColor(calibratedRed: 0.42, green: 0.62, blue: 0.46, alpha: 1.0)
    static let stringColor = NSColor(calibratedRed: 0.47, green: 0.72, blue: 0.80, alpha: 1.0)

    private static let keywordPattern = #"(?i)\b(select|from|where|join|left|right|inner|outer|cross|full|on|insert|into|values|update|set|delete|create|table|alter|drop|distinct|group|by|order|limit|offset|having|and|or|not|is|null|like|in|between|as|case|when|then|else|end|union|all|exists|count|sum|min|max|avg|desc|asc|primary|key|foreign|constraint|index|unique|if|begin|commit|rollback)\b"#
    private static let lineCommentPattern = #"(?m)(--|#).*$"#
    private static let blockCommentPattern = #"(?s)/\*.*?\*/"#
    private static let stringPattern = #"'(?:''|[^'])*'"#

    private static let keywordRegex = try? NSRegularExpression(pattern: keywordPattern)
    private static let lineCommentRegex = try? NSRegularExpression(pattern: lineCommentPattern)
    private static let blockCommentRegex = try? NSRegularExpression(pattern: blockCommentPattern)
    private static let stringRegex = try? NSRegularExpression(pattern: stringPattern)

    static func apply(to textStorage: NSTextStorage, fullRange: NSRange, font: NSFont) {
        let source = textStorage.string

        textStorage.addAttributes(
            [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ],
            range: fullRange
        )

        apply(regex: stringRegex, color: stringColor, in: source, textStorage: textStorage, font: font)
        apply(regex: keywordRegex, color: keywordColor, in: source, textStorage: textStorage, font: font)
        apply(regex: lineCommentRegex, color: commentColor, in: source, textStorage: textStorage, font: font)
        apply(regex: blockCommentRegex, color: commentColor, in: source, textStorage: textStorage, font: font)
    }

    private static func apply(
        regex: NSRegularExpression?,
        color: NSColor,
        in source: String,
        textStorage: NSTextStorage,
        font: NSFont
    ) {
        guard let regex else { return }
        let fullRange = NSRange(location: 0, length: source.utf16.count)

        regex.enumerateMatches(in: source, options: [], range: fullRange) { match, _, _ in
            guard let range = match?.range, range.location != NSNotFound else { return }
            textStorage.addAttributes(
                [
                    .font: font,
                    .foregroundColor: color
                ],
                range: range
            )
        }
    }
}

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
    let editorFontSize: CGFloat
    /// 外部请求设置的光标位置（用于自动补全后同步光标）
    var requestedCursorPosition: Int?
    var onSelectionChange: ((NSRange, String) -> Void)?
    var onCursorPositionChange: ((Int) -> Void)?
    var onCursorRectChange: ((CursorRectInfo) -> Void)?

    private var editorFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: editorFontSize, weight: .regular)
    }

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
        textView.font = editorFont
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.insertionPointColor = NSColor.labelColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.lineFragmentPadding = 0

        // 设置初始文本
        textView.string = text
        applyEditorAppearance(to: textView)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // 更新字体（响应设置变化）
        if textView.font?.pointSize != editorFontSize {
            textView.font = editorFont
            if !textView.hasMarkedText() {
                applyEditorAppearance(to: textView)
            }
        }

        if textView.hasMarkedText() {
            return
        }

        // 优先处理外部请求的光标位置（自动补全后同步光标）
        if let requestedPosition = requestedCursorPosition,
           context.coordinator.lastRequestedCursor != requestedPosition {
            context.coordinator.lastRequestedCursor = requestedPosition

            // 先更新文本（如果需要）
            if textView.string != text {
                textView.string = text
                applyEditorAppearance(to: textView)
            }

            // 设置新的光标位置
            let validPosition = min(max(0, requestedPosition), text.count)
            textView.setSelectedRange(NSRange(location: validPosition, length: 0))
            return
        }

        // 只在文本真正改变时更新
        if textView.string != text {
            // 保存当前选中范围
            let selectedRange = textView.selectedRange()

            textView.string = text
            applyEditorAppearance(to: textView)

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

    private func applyEditorAppearance(to textView: NSTextView) {
        let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
        guard let textStorage = textView.textStorage else { return }

        textStorage.beginEditing()
        SQLSyntaxHighlighter.apply(to: textStorage, fullRange: fullRange, font: editorFont)
        textStorage.endEditing()

        textView.typingAttributes[.font] = editorFont
        textView.typingAttributes[.foregroundColor] = NSColor.labelColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SQLEditorTextView?
        // 去重缓存：避免 resize 期间重复触发 SwiftUI setState
        var lastReportedSelection: NSRange?
        var lastReportedCursor: Int?
        // 外部请求光标位置去重
        var lastRequestedCursor: Int?

        init(_ parent: SQLEditorTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if !textView.hasMarkedText() {
                parent?.applyEditorAppearance(to: textView)
            }
            parent?.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            if textView.hasMarkedText() { return }
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
