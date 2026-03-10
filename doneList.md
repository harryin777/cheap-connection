# Done List

记录项目开发过程中完成的标志性功能。

---

## 项目初始化

- [x] 2026-03-10: 创建项目规划文档 CLAUDE.md，确定技术方向和功能范围
- [x] 2026-03-10: 创建 Xcode 项目 (SwiftUI + macOS 15)
- [x] 2026-03-10: 创建项目目录结构 (App/Features/Shared/Infrastructure/Assets.xcassets)
- [x] 2026-03-10: 定义基础模型 DatabaseKind, ConnectionConfig, PaginationState, AppError
- [x] 2026-03-10: 修复项目目录结构，编译成功

---

## 阶段 1: 连接管理基础

### 1.1 安全存储层
- [x] 2026-03-10: 实现 `KeychainError` 错误类型
- [x] 2026-03-10: 实现 `KeychainService` 协议和实现类
  - 密码安全存储到 macOS Keychain
  - 密码读取 / 删除功能
  - 服务标识: com.yzz.cheap-connection

### 1.2 本地持久化层
- [x] 2026-03-10: 实现 `ConnectionRepository` 协议和实现类
  - 连接配置 CRUD 操作
  - JSON 文件持久化 (~Library/Application Support/com.yzz.cheap-connection/)
  - ISO8601 日期编解码
- [x] 2026-03-10: 实现 `RecentHistoryRepository` 协议和实现类
  - 最近连接记录管理
  - 最多保留 10 条记录
  - 按连接时间排序

### 1.3 连接管理服务
- [x] 2026-03-10: 实现 `ConnectionManager` 服务类
  - 使用 @Observable 宏实现响应式状态
  - 统一管理连接配置和最近连接
  - 密码与配置分离管理

### 1.4 连接配置 UI
- [x] 2026-03-10: 实现 `ConnectionFormData` 表单数据模型
- [x] 2026-03-10: 实现 `ConnectionFormViewModel` 表单视图模型
  - 新建/编辑模式支持
  - 表单验证逻辑
- [x] 2026-03-10: 实现 `ConnectionListView` 连接列表侧边栏
  - 最近连接分组显示
  - 所有连接分组显示
  - 新建连接按钮
- [x] 2026-03-10: 实现 `ConnectionRowView` 连接行视图
  - 数据库类型图标
  - 连接信息显示
  - 右键菜单 (编辑/删除)
- [x] 2026-03-10: 实现 `ConnectionFormView` 连接表单视图
  - 基本信息区域 (名称/数据库类型)
  - 连接信息区域 (主机/端口/用户名/密码/数据库/SSL)
  - 表单验证和错误提示
- [x] 2026-03-10: 实现 `MainView` 主视图
  - NavigationSplitView 布局
  - 空状态提示
  - 连接详情占位视图
- [x] 2026-03-10: 更新 App 入口，集成 ConnectionManager

---

## MySQL 功能

<!-- MySQL 相关功能完成后在此记录 -->

## Redis 功能

<!-- Redis 相关功能完成后在此记录 -->

## 通用功能

<!-- 通用功能完成后在此记录 -->

---

## 格式说明

每完成一个标志性功能，按以下格式添加记录：

```
- [x] YYYY-MM-DD: 功能描述
```

示例：
- [x] 2026-03-10: 完成连接配置模型设计
- [x] 2026-03-10: 实现 MySQL 连接功能
