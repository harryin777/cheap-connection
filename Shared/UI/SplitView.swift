//
//  SplitView.swift
//  cheap-connection
//
//  原生 NSSplitView 包装器 - 避免 SwiftUI 拖拽重绘循环
//

import SwiftUI
import AppKit

/// 原生 NSSplitView 包装器 - 避免 SwiftUI 拖拽重绘循环
/// NSSplitView 的 splitter 拖拽由 AppKit 内部处理，不会触发 SwiftUI 视图重绘
struct SplitView: NSViewRepresentable {
    var topView: AnyView
    var bottomView: AnyView
    @Binding var topHeight: CGFloat
    var minTopHeight: CGFloat = 120
    var minBottomHeight: CGFloat = 100

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = false
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator

        // 创建上下两个视图的 hosting controller
        let topHosting = NSHostingController(rootView: topView)
        let bottomHosting = NSHostingController(rootView: bottomView)

        topHosting.view.identifier = NSUserInterfaceItemIdentifier("topView")
        bottomHosting.view.identifier = NSUserInterfaceItemIdentifier("bottomView")

        splitView.addArrangedSubview(topHosting.view)
        splitView.addArrangedSubview(bottomHosting.view)

        // 存储引用
        context.coordinator.topHostingController = topHosting
        context.coordinator.bottomHostingController = bottomHosting

        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        // 更新子视图内容
        context.coordinator.topHostingController?.rootView = topView
        context.coordinator.bottomHostingController?.rootView = bottomView

        // 只在非拖拽状态时响应外部 topHeight 变化
        if !context.coordinator.isDragging {
            if let topView = splitView.arrangedSubviews.first {
                let constraints = topView.constraints
                // 移除旧的高度约束
                constraints.filter { $0.identifier == "topHeight" }.forEach {
                    topView.removeConstraint($0)
                }

                let heightConstraint = NSLayoutConstraint(
                    item: topView,
                    attribute: .height,
                    relatedBy: .greaterThanOrEqual,
                    toItem: nil,
                    attribute: .notAnAttribute,
                    multiplier: 1,
                    constant: topHeight
                )
                heightConstraint.identifier = "topHeight"
                heightConstraint.priority = .required
                topView.addConstraint(heightConstraint)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSSplitViewDelegate {
        var parent: SplitView
        var topHostingController: NSHostingController<AnyView>?
        var bottomHostingController: NSHostingController<AnyView>?
        var isDragging = false
        var lastReportedHeight: CGFloat?

        init(_ parent: SplitView) {
            self.parent = parent
        }

        func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimum: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            if dividerIndex == 0 {
                return parent.minTopHeight
            }
            return proposedMinimum
        }

        func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximum: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
            if dividerIndex == 0 {
                return splitView.bounds.height - parent.minBottomHeight
            }
            return proposedMaximum
        }

        func splitViewWillResizeSubviews(_ notification: Notification) {
            isDragging = true
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard let splitView = notification.object as? NSSplitView,
                  let topView = splitView.arrangedSubviews.first else { return }

            let newHeight = topView.bounds.height

            // 只在高度真正变化时才更新，避免循环
            if lastReportedHeight != newHeight {
                lastReportedHeight = newHeight
                DispatchQueue.main.async { [weak self] in
                    self?.parent.topHeight = newHeight
                }
            }
        }

        func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
            // 拖拽结束
            isDragging = false
            splitView.adjustSubviews()
        }
    }
}
