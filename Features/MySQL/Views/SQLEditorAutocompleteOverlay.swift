//
//  SQLEditorAutocompleteOverlay.swift
//  cheap-connection
//
//  SQL 编辑器自动补全浮层组件
//

import SwiftUI

/// SQL 编辑器自动补全浮层
struct SQLEditorAutocompleteOverlay: View {
    let suggestions: [SQLCompletionSuggestion]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.prefix(8).enumerated()), id: \.element.id) { index, suggestion in
                suggestionRow(suggestion, at: index)
            }
        }
        .frame(minWidth: 200, maxWidth: 300)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(6)
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
    }

    // MARK: - Subviews

    private func suggestionRow(_ suggestion: SQLCompletionSuggestion, at index: Int) -> some View {
        Button {
            onSelect(index)
        } label: {
            HStack(spacing: 8) {
                // 左侧类型缩略词：T(表)/C(列)/K(关键字)
                Text(suggestion.type.badge)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(badgeColor(for: suggestion.type))
                    .cornerRadius(3)

                Text(suggestion.displayText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)

                Spacer()

                Text(suggestion.type.rawValue)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(index == selectedIndex ? Color.accentColor.opacity(0.2) : Color.clear)
    }

    private func badgeColor(for type: SQLCompletionSuggestion.SuggestionType) -> Color {
        switch type {
        case .table:
            return .blue
        case .column:
            return .orange
        case .keyword:
            return .purple
        }
    }
}

#Preview {
    SQLEditorAutocompleteOverlay(
        suggestions: [
            SQLCompletionSuggestion(text: "users", type: .table),
            SQLCompletionSuggestion(text: "user_id", type: .column),
            SQLCompletionSuggestion(text: "SELECT", type: .keyword)
        ],
        selectedIndex: 0,
        onSelect: { _ in }
    )
    .padding()
}
