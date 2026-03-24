//
//  RedisValueViews.swift
//  cheap-connection
//
//  Redis 值视图预览集合
//

import SwiftUI

#Preview("String") {
    RedisStringValueView(value: "Hello, World! 这是一个测试字符串。")
        .frame(width: 600, height: 400)
}

#Preview("Hash") {
    RedisHashValueView(value: [
        "name": "John Doe",
        "email": "john@example.com",
        "age": "30",
        "created_at": "2024-01-15T10:30:00Z"
    ])
    .frame(width: 600, height: 400)
}

#Preview("List") {
    RedisListValueView(value: ["item1", "item2", "item3", "item4", "item5"])
        .frame(width: 600, height: 400)
}

#Preview("Set") {
    RedisSetValueView(value: ["member1", "member2", "member3", "alpha", "beta"])
        .frame(width: 600, height: 400)
}

#Preview("ZSet") {
    RedisZSetValueView(value: [
        RedisZSetMember(member: "player1", score: 100),
        RedisZSetMember(member: "player2", score: 250),
        RedisZSetMember(member: "player3", score: 175)
    ])
    .frame(width: 600, height: 400)
}
