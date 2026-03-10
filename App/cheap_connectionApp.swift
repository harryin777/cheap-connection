//
//  cheap_connectionApp.swift
//  cheap-connection
//
//  Created by harry on 2026/3/10.
//

import SwiftUI

@main
struct cheap_connectionApp: App {
    @State private var connectionManager = ConnectionManager()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(connectionManager)
        }
        .commands {
            // 添加连接相关菜单命令
            CommandGroup(replacing: .newItem) {
                Button("新建连接") {
                    // 触发新建连接
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
