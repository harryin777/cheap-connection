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

### 2.9 编译修复与集成
- [x] 2026-03-11: 修复 MySQLService.swift 编译错误
  - 修复 row[safe: 0] 下标访问语法
- [x] 2026-03-11: 修复 MySQLEditorView.swift 编译错误
  - 移除不兼容的 onKeyPress 修饰符
- [x] 2026-03-11: 修复 MySQLStructureView.swift 编译错误
  - 重写 Table API 使用正确的 TableColumn.width() 修饰符
  - 添加显式类型注解 (column: MySQLColumnDefinition)
- [x] 2026-03-11: 修复 MySQLWorkspaceView.swift 编译错误
  - 修复 .accent ShapeStyle 为 .tint
  - 添加缺失的 try 关键字
- [x] 2026-03-11: 修复 MySQLSidebarView.swift 编译错误
  - 修复 .sidebarBackgroundColor 为 Color(nsColor: .controlBackgroundColor)
  - 修复三元表达式类型推断问题
- [x] 2026-03-11: 所有 MySQL 相关文件已添加到 Xcode 项目
- [x] 2026-03-11: MySQLKit SPM 依赖已集成
- [x] 2026-03-11: 项目编译成功，无告警

### 2.10 网络连接修复
- [x] 2026-03-11: 添加 App Sandbox 网络权限
  - 创建 CheapConnection.entitlements 文件
  - 配置 com.apple.security.network.client 权限
  - 在 project.pbxproj 中添加 CODE_SIGN_ENTITLEMENTS
- [x] 2026-03-11: 修复 MySQLClient DNS 解析问题
  - 使用 POSIX getaddrinfo 替代 SwiftNIO SocketAddress
  - 支持 IPv4/IPv6 多地址解析
  - 添加私网 IP 检测和友好错误提示
  - 实现连接超时检测和错误消息优化
- [x] 2026-03-11: MySQL 连接功能验证通过（阿里云 RDS MySQL）

### 2.11 UI 细节修复
- [x] 2026-03-11: 修复 ProgressView 布局约束警告
  - 替换 scaleEffect 为固定 frame
- [x] 2026-03-11: 修复加载表功能
  - 展开数据库时自动触发表加载
  - 添加调试日志
- [x] 2026-03-11: 改进 MySQLResultView 数据表格
  - 支持拖拽调整列宽
  - 内容靠左对齐
  - 添加明显的列分割线
  - 鼠标悬停显示调整光标
- [x] 2026-03-11: 双击表名默认打开数据标签

### 2.12 SQL 执行修复
- [x] 2026-03-11: 修复 SQL 标签页执行查询报错问题
  - 问题: 在 SQL 标签页执行 `SELECT * FROM table` 报 "SQL 语法错误"
  - 原因: MySQLKit 使用 prepared statement，不支持 USE 语句切换数据库
  - 解决: 实现 SQL 预处理，自动为表名添加数据库前缀
  - 支持 FROM/JOIN/UPDATE/INSERT/DELETE 等语句的表名补全
  - 例如: `SELECT * FROM ad_supply_task` → `SELECT * FROM `db`.`ad_supply_task``

### 2.13 SQL 自动补全
- [x] 2026-03-11: 实现 SQL 编辑器自动补全功能
  - 输入时自动显示补全建议
  - 支持表名、列名、关键字提示
  - Tab 键接受建议
  - 上下箭头导航建议

### 2.14 数据表格增强
- [x] 2026-03-11: 实现数据表格单元格交互功能
  - 鼠标悬停显示完整内容 (Tooltip)
  - 单击选中单元格
  - 双击进入编辑模式
  - 编辑后自动保存到数据库
  - 支持主键条件更新
- [x] 2026-03-11: 修复数据表格交互问题
  - 修复单击/双击手势冲突（使用 simultaneousGesture）
  - SQL 标签页查询结果也支持双击编辑
  - 编辑功能仅在选择表时可用

### 2.15 MySQL 数据导入
- [x] 2026-03-11: 实现 SQL 数据导入功能
  - 在 SQL 编辑器工具栏添加导入按钮
  - 使用 NSOpenPanel 选择 .sql 文件
  - 解析多语句 SQL（处理字符串内的分号）
  - 逐条执行 SQL 语句
  - 显示执行进度和结果统计
  - 注：此功能用于导入并执行 .sql 文件（如数据迁移）

### 2.16 MySQL UI 优化
- [x] 2026-03-12: 修复 Query Tab 关闭按钮功能
  - 扩大按钮点击区域（使用 contentShape(Rectangle())）
  - 更换图标为 xmark.circle.fill，提升可见性
  - 添加 onCloseTab 回调，关闭时清空查询结果
  - 增加按钮 frame 尺寸，提升可点击性
- [x] 2026-03-12: 优化左侧侧边栏为完整树形结构（DataGrip 风格）
  - 顶层显示连接名（如 aliyun），带展开/折叠箭头
  - 第二层显示数据库列表
  - 第三层显示表列表
  - 连接节点包含刷新按钮和收起全部按钮
  - 优化展开/折叠动画

### 2.17 MySQL Query 执行语义细化
- [x] 2026-03-12: 实现 DataGrip 风格的 SQL 执行范围解析
  - 优先执行选中 SQL
  - 其次执行光标所在语句
  - 最后回退到整个 buffer
- [x] 2026-03-12: 新增 SQLStatementParser 解析器
  - 支持多语句解析（正确处理字符串、行注释、块注释中的分号）
  - 根据光标位置定位当前语句
- [x] 2026-03-12: 新增 SQLEditorTextView (NSViewRepresentable)
  - 包装 NSTextView 以获取选区范围和光标位置
  - SwiftUI TextEditor 不暴露选区 API
- [x] 2026-03-12: 修复选中单条 SQL 执行时范围错误的问题
- [x] 2026-03-12: 明确 SQL 预处理只作用于最终执行范围
- [x] 2026-03-12: 新增 EditorQueryTab 模型用于管理外部 .sql 文件

### 2.18 Query Context 与资源树解耦
- [x] 2026-03-12: 把左侧资源树选择状态与右侧 query 文件执行上下文彻底拆开
  - selectedConnectionId / selectedDatabaseName / selectedTableName 只用于资源树浏览
  - EditorQueryTab 新增独立上下文字段：queryConnectionId / queryConnectionName / queryDatabaseName
- [x] 2026-03-12: 右上角 connection pill 改成真实可切换的连接列表
  - 支持切换到其他已保存连接
  - 不再与左侧资源树当前高亮连接强绑定
- [x] 2026-03-12: 右上角 schema/database pill 列表跟随当前 queryConnectionId 动态刷新
  - 新增 connectionDatabaseCache 按连接 ID 缓存数据库列表
  - 异步加载其他连接的数据库列表
- [x] 2026-03-12: 左侧点击连接/数据库/表时只影响资源树浏览态和结构/数据面板
  - 不再污染当前 query 文件的执行上下文
- [x] 2026-03-12: query connection 切换后自动校验旧 queryDatabase 是否有效
  - 无效时回退到默认数据库
- [x] 2026-03-12: 清理所有相关 GPT 注释

### 2.19 MySQL Bug 修复
- [x] 2026-03-12: 修复 SQL 结果网格列头固定问题
  - 使用 LazyVStack + pinnedViews: [.sectionHeaders] 实现固定表头
  - 纵向滚动时列名保持固定在顶部（DataGrip 风格）
- [x] 2026-03-12: 修复 Query Connection 切换时状态同步问题
  - 使用整体替换方式更新 editorTabs 元素，确保 SwiftUI 检测到变化
  - 切换连接时先同步更新 UI 状态（queryConnectionId/Name/Database=nil）
  - 然后异步获取新连接的数据库列表并设置默认库
- [x] 2026-03-12: 修复 Query Database Options 残留旧连接库名问题
  - 切换连接时不再短暂复用旧连接的 databases 列表
  - 只从缓存或新连接的实时拉取结果获取数据库列表
- [x] 2026-03-12: 清理所有 GPT TODO 注释

### 2.20 Swift 文件行数重构
- [x] 2026-03-12: 更新 CLAUDE.md 添加文件大小限制规则
  - Swift 文件行数不得超过 300 行
  - 使用 MARK: - 注释清晰划分功能区域
- [x] 2026-03-12: 重构 SQLRiskLevel.swift (345 行 → 3 个文件)
  - `SQLRiskLevel.swift` (137 行) - SQL 风险等级枚举
  - `SQLExecutionScope.swift` (22 行) - SQL 执行范围定义
  - `SQLStatementParser.swift` (200 行) - SQL 语句解析器
  - 所有文件已添加到 Xcode 项目
  - 编译通过

---

## 阶段 3: Redis 核心功能

### 3.1 Redis 驱动层 (Infrastructure/Drivers/)
- [x] 2026-03-17: 实现 `RedisClientProtocol` 协议
  - 连接管理接口 (connect/disconnect/ping)
  - Key 操作接口 (scan/getType/getTTL/delete)
  - 值获取接口 (string/hash/list/set/zset)
  - 命令执行接口
- [x] 2026-03-17: 集成 RediStack (vapor/redis) 驱动库
- [x] 2026-03-17: 实现 `RedisClient` 驱动适配器
  - 基于 RediStack + SwiftNIO
  - actor 保证线程安全
  - 多地址连接尝试
  - 资源正确清理
- [x] 2026-03-17: 实现 `RedisErrorMapper` 错误映射器
  - NIO ChannelError 处理
  - 认证/连接/超时/网络错误映射
- [x] 2026-03-17: 实现 `RedisValueConverter` 值转换器
  - RESP 协议值转换
  - Scan/Hash/Array/ZSet 结果转换
- [x] 2026-03-17: 实现 `RedisRiskDetector` 高风险命令检测
  - FLUSHDB/FLUSHALL 检测
  - 大规模删除检测
  - DEBUG 命令检测

### 3.2 Redis 领域模型 (Features/Redis/Models/)
- [x] 2026-03-17: 实现 `RedisConnectionConfig` 连接配置
- [x] 2026-03-17: 实现 `RedisSession` 会话状态
- [x] 2026-03-17: 实现 `RedisKeySummary` Key 摘要
- [x] 2026-03-17: 实现 `RedisKeyDetail` Key 详情
- [x] 2026-03-17: 实现 `RedisValueType` 值类型枚举
- [x] 2026-03-17: 实现 `RedisValue` 值封装
- [x] 2026-03-17: 实现 `RedisCommandResult` 命令执行结果

### 3.3 Redis 服务层 (Features/Redis/Services/)
- [x] 2026-03-17: 实现 `RedisService` 服务类
  - 连接管理、Key 扫描、值获取
  - 命令执行、服务器信息获取

### 3.4 Redis UI - Key 浏览 (Features/Redis/Views/)
- [x] 2026-03-17: 实现 `RedisWorkspaceView` 主工作区
  - 连接状态管理 (连接中/已连接/错误)
  - 左右分栏布局 (Key 列表 + 详情)
- [x] 2026-03-17: 实现 `RedisKeyListView` Key 列表视图
  - 增量加载 (SCAN 命令)
  - 搜索功能 (支持通配符)
  - 类型图标和 TTL 显示
  - 加载更多按钮
- [x] 2026-03-17: 实现 `RedisKeyDetailHeaderView` Key 详情头部
  - 类型图标和名称
  - 长度/元素数显示
  - 内存大小显示
  - TTL 过期时间显示

### 3.5 Redis UI - Value 展示 (Features/Redis/Views/)
- [x] 2026-03-17: 实现 `RedisStringValueView` String 类型展示
  - 等宽字体显示
  - 大 value 预览截断
  - 字符/字节统计
- [x] 2026-03-17: 实现 `RedisHashValueView` Hash 类型展示
  - 键值表格布局
  - 搜索字段功能
  - 按名称排序
- [x] 2026-03-17: 实现 `RedisListValueView` List 类型展示
  - 带索引的列表显示
  - 有序展示
- [x] 2026-03-17: 实现 `RedisSetValueView` Set 类型展示
  - 成员列表
  - 搜索功能
  - 排序功能
- [x] 2026-03-17: 实现 `RedisZSetValueView` ZSet 类型展示
  - 分数 + 成员表格
  - 按分数排序 (升序/降序)
  - 搜索功能

### 3.3 Redis 服务层 (Features/Redis/Services/)
- [x] 2026-03-17: 实现 `RedisService` 服务类
  - 连接管理、Key 扫描、值获取
  - 命令执行、服务器信息获取

## 通用功能

### 4.1 编译警告修复
- [x] 2026-03-17: 修复所有 Swift 6 严格并发检查警告
  - 添加 @preconcurrency import RediStack
  - 添加 nonisolated 到所有工具方法和初始化器
  - 重构 ConnectionManager 为 shared 单例模式
  - 修复未使用变量警告 (MainView, cheap_connectionApp)
- [x] 2026-03-17: 项目编译成功，零警告

### 4.2 UI 改进
- [x] 2026-03-17: 连接表单数据库类型显示不同图标
  - MySQL: cylinder.split.1x2 (数据库圆筒图标)
  - Redis: memorychip (内存芯片图标)

### 4.3 统一工作区壳层
- [x] 2026-03-18: 创建 `UnifiedWorkspaceView` 统一右侧工作区壳层
  - MySQL/Redis 使用相同的上下分割布局
  - 保持一致的编辑器 + 结果区布局
- [x] 2026-03-18: 创建 `RedisEditorView` 命令编辑器
  - 与 MySQL 风格一致的工具栏设计
  - 历史面板、执行按钮
- [x] 2026-03-18: 创建 `SplitView` 共享组件 (NSSplitView wrapper)
  - 从 MySQLWorkspaceView 提取为共享组件
  - 支持拖拽调整分割比例
- [x] 2026-03-18: 创建 `WorkspaceManager` 工作区生命周期管理
  - 活动工作区切换
  - 工作区打开/关闭通知
  - 断连完成同步

### 4.4 Task 竞态问题修复
- [x] 2026-03-18: 修复 MySQL workspace 切换时的 Task 竞态问题
  - 添加 `pendingTasks` 字典管理异步任务引用
  - `workspaceWillClose` 时先取消所有任务再断连
  - 各异步操作增加 `Task.isCancelled` 检查
- [x] 2026-03-18: 解决 mysql-nio "Statement not closed" 断言错误
  - 确保连接断开前所有查询任务已完成或取消
  - 使用 `cancelPendingTasksAndWait()` 等待任务结束

### 4.5 左侧资源树与右侧工作区解耦
- [x] 2026-03-20: 修复左侧单击连接隐式创建 workspace 的问题
  - 移除 `selectConnection` 中的自动打开 workspace 逻辑
  - 单击只更新资源树高亮和展开态，不创建 workspace
  - 保留双击打开 workspace（显式动作）
- [x] 2026-03-20: 清理所有相关 GPT 注释
  - ConnectionListInteractions.swift
  - WorkspaceTabBar.swift
  - WorkspaceManager.swift
  - MainView.swift

### 4.6 修复 todoList.md 中的 4 个 Bug
- [x] 2026-03-20: 修复"导入 query 文件"按钮语义混线问题
  - `openSQLFile()` 现在会清除所有执行结果状态（sqlResult, tableDataResult, importResult 等）
  - 确保打开文件后界面只显示编辑器内容，不残留之前的执行结果
- [x] 2026-03-20: 修复连接选择器只显示 MySQL 连接的问题
  - `availableConnections` 现在返回所有连接（MySQL + Redis）
- [x] 2026-03-20: 修复连接菜单未按类型分组的问题
  - `SQLEditorConnectionMenu` 现在按 MySQL/Redis 分组显示
  - 使用 Section 分组，中间加分隔线
  - 不同类型使用不同图标（cylinder/memorybox）和颜色
- [x] 2026-03-20: 修复连接 pill 无法区分类型的问题
  - 闭合态 pill 现在根据当前连接类型显示不同图标和颜色
  - MySQL: 蓝色 cylinder 图标
  - Redis: 红色 memorybox 图标

### 4.7 标签栏/状态栏字体大小可调整
- [x] 2026-03-24: 新增 `tabBarFontSize` 设置项（默认 11pt）
- [x] 2026-03-24: 设置 > 外观中添加"标签栏/状态栏"字体大小调整控件
- [x] 2026-03-24: 为多个视图添加 `@ObservedObject` 监听设置变化
  - WorkspaceTabBar, MySQLResultView, MySQLEditorView
  - RedisConsoleView, RedisEditorView
- [x] 2026-03-24: 修复表格表头和行号字体响应设置变化
  - ResultPinnedHeaderView: 表头字体使用 tabBarFontSize
  - ResultDataRowView: 行号字体使用 tabBarFontSize
  - 分页控件、状态栏、工具栏等均已支持响应式更新

---

## 格式说明

每完成一个标志性功能，按以下格式添加记录：

```
- [x] YYYY-MM-DD: 功能描述
```

示例：
- [x] 2026-03-10: 完成连接配置模型设计
- [x] 2026-03-10: 实现 MySQL 连接功能
