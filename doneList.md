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

## 阶段 2: MySQL 核心功能

### 2.1 MySQL 驱动层 (Infrastructure/Drivers/)
- [x] 2026-03-10: 实现 `MySQLClientProtocol` 协议
  - 定义连接/断开/查询等接口
  - 分页数据获取接口
- [x] 2026-03-10: 实现 `MySQLErrorMapper` 错误映射器
  - 将 MySQL 驱动错误映射到 AppError
  - 处理认证失败、连接拒绝、超时、语法错误等
- [x] 2026-03-10: 实现 `MySQLClient` 驱动适配器
  - 基于 MySQLKit + MySQLNIO (待添加依赖)
  - 实现所有 MySQLClientProtocol 方法

### 2.2 MySQL 领域模型 (Features/MySQL/Models/)
- [x] 2026-03-10: 实现 `MySQLConnectionConfig` 连接配置
- [x] 2026-03-10: 实现 `MySQLSession` 会话状态
  - 连接状态管理 (disconnected/connecting/connected/error)
  - 选中数据库/表状态
- [x] 2026-03-10: 实现 `MySQLDatabaseSummary` 数据库摘要
- [x] 2026-03-10: 实现 `MySQLTableSummary` 表摘要
- [x] 2026-03-10: 实现 `MySQLColumnDefinition` 列定义
- [x] 2026-03-10: 实现 `MySQLRowValue` 行值类型
  - 支持 string/int/double/date/data/null
- [x] 2026-03-10: 实现 `MySQLQueryResult` 查询结果
  - 列定义、行数据、执行信息、错误信息
- [x] 2026-03-10: 实现 `SQLRiskLevel` SQL风险分析
  - safe/warning/dangerous 三级风险
  - DROP/TRUNCATE/无WHERE DELETE 检测

### 2.3 MySQL 服务层 (Features/MySQL/Services/)
- [x] 2026-03-10: 实现 `MySQLService` 服务类
  - 连接管理、数据库/表获取
  - 表结构查询、分页数据获取
  - SQL 执行、服务器信息获取

### 2.4 MySQL UI (Features/MySQL/Views/)
- [x] 2026-03-10: 实现 `MySQLWorkspaceView` 主工作区
  - 连接状态管理、数据库/表选择
  - 结构/数据/SQL 三个标签页
- [x] 2026-03-10: 实现 `MySQLDatabaseListView` 数据库列表
- [x] 2026-03-10: 实现 `MySQLTableListView` 表列表
- [x] 2026-03-10: 实现 `MySQLStructureView` 表结构视图
  - 使用 SwiftUI Table 显示列定义
- [x] 2026-03-10: 实现 `MySQLDataView` 数据浏览视图
  - 分页控制、上一页/下一页
  - 显示行号和分页信息
- [x] 2026-03-10: 实现 `MySQLEditorView` SQL编辑器
  - SQL 文本编辑
  - Cmd+Enter 执行
  - 执行历史
  - 危险 SQL 确认对话框
- [x] 2026-03-10: 实现 `MySQLResultView` 查询结果展示
  - 表格展示、NULL 值特殊显示
  - 执行信息显示

### 2.5 辅助模型
- [x] 2026-03-10: 实现 `OrderDirection` 排序方向枚举
- [x] 2026-03-10: 修复 `PaginationState` 添加 hasNext 属性

### 2.6 Redis 占位
- [x] 2026-03-10: 创建 `RedisWorkspaceView` 占位视图

### 2.7 DataGrip 风格 UI 改造
- [x] 2026-03-10: 更新 todoList 添加 UI 风格与 DataGrip 保持一致的设计目标
  - 左侧树形结构（数据库-表层级）
  - 紧凑的数据表格样式、斑马纹、行号
  - 工具栏简洁图标设计
  - 状态栏信息显示
  - 整体间距和字体调整
- [x] 2026-03-10: 修改 `MySQLDatabaseSummary` 添加 tables 属性支持树形展开
- [x] 2026-03-10: 创建 `MySQLSidebarView` 树形侧边栏组件
- [x] 2026-03-10: 重写 `MySQLWorkspaceView` 主布局
- [x] 2026-03-10: 重写 `MySQLResultView` 紧凑表格样式
  - 更小的字体、 紧凑的行号列
  - 斑马纹背景
  - 状态栏显示执行时间和行数
- [x] 2026-03-10: 重写 `MySQLDataView` 工具栏和表格优化
  - 紧凑的工具栏设计
  - 分页控件优化
- [x] 2026-03-10: 重写 `MySQLStructureView` 表格样式优化
  - 紧凑的表格样式
  - 主键图标高亮
- [x] 2026-03-10: 重写 `MySQLEditorView` 工具栏优化
  - 绿色执行按钮
  - 紧凑的历史面板
- [x] 2026-03-10: 修改 `MainView` 集成 MySQLWorkspaceView 和 RedisWorkspaceView

### 2.8 代码清理
- [x] 2026-03-10: 移除未使用的 `@Environment(\.colorScheme)` 变量
  - MySQLSidebarView.swift
  - MySQLResultView.swift
  - MySQLWorkspaceView.swift
- [x] 2026-03-10: 移除未使用的 `@State selectedColumn` 变量
  - MySQLStructureView.swift
  - MySQLResultView.swift
  - MySQLDataView.swift
- [x] 2026-03-10: 修复 force unwrap 问题
  - ConnectionRepository.swift - 使用 guard let 替代 first!
  - RecentHistoryRepository.swift - 使用 guard let 替代 first!
- [x] 2026-03-10: 改进 MySQLClient 线程安全
  - deinit 中使用异步 Task 替代同步 .wait()
- [x] 2026-03-10: 删除冗余视图文件
  - MySQLDatabaseListView.swift (已被 MySQLSidebarView 替代)
  - MySQLTableListView.swift (已被 MySQLSidebarView 替代)

---

### 待完成 (需手动操作)
- [ ] **将以下文件添加到 Xcode 项目**
  - `Infrastructure/Drivers/MySQLClientProtocol.swift`
  - `Infrastructure/Drivers/MySQLErrorMapper.swift`
  - `Infrastructure/Drivers/MySQLClient.swift`
  - `Features/MySQL/Models/MySQLConnectionConfig.swift`
  - `Features/MySQL/Models/MySQLSession.swift`
  - `Features/MySQL/Models/MySQLTableSummary.swift`
  - `Features/MySQL/Models/MySQLColumnDefinition.swift`
  - `Features/MySQL/Models/SQLRiskLevel.swift`
  - `Features/MySQL/Models/MySQLRowValue.swift`
  - `Features/MySQL/Models/MySQLQueryResult.swift`
  - `Features/MySQL/Models/MySQLDatabaseSummary.swift`
  - `Features/MySQL/Services/MySQLService.swift`
  - `Features/MySQL/Views/MySQLEditorView.swift`
  - `Features/MySQL/Views/MySQLResultView.swift`
  - `Features/MySQL/Views/MySQLStructureView.swift`
  - `Features/MySQL/Views/MySQLWorkspaceView.swift`
  - `Features/MySQL/Views/MySQLDataView.swift`
  - `Shared/Models/OrderDirection.swift`
  - `Features/Redis/Views/RedisWorkspaceView.swift`
- [ ] **删除根目录重复文件**: `/MySQLSidebarView.swift`
- [ ] 添加 MySQLKit SPM 依赖到 Xcode 项目

---

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
