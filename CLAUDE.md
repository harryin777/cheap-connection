# CLAUDE.md

## 项目概述

这是一个使用 **Swift** 开发的 **macOS 原生数据库客户端**。  
当前项目范围刻意收窄，只支持两种数据库：

- **MySQL**
- **Redis**

项目目标：

- 低内存占用
- 启动快
- 连接稳定
- 原生 macOS 体验
- 架构清晰，便于长期维护

这不是一个”全能型数据库 IDE”，而是一个聚焦于 **MySQL + Redis** 的轻量级桌面客户端。

---

## 开发工作流

### GPT 注释优先
在本项目中，代码中可能包含以 `GPT` 或 `// GPT:` 开头的注释。这些注释是待办事项或改进建议。

**工作流程：**
1. 接到开发任务时，优先使用 `Grep` 工具搜索关键字 `GPT` 查找相关注释
2. 找到 GPT 注释后，按照注释中的指示完成代码编辑
3. 完成后删除或更新该 GPT 注释

**GPT 注释格式示例：**
```swift
// GPT: 这里需要添加错误处理
// GPT TODO: 优化这个循环的性能
// GPT FIXME: 这个逻辑有 bug，需要修复
```

---

## 产品定位

这个产品应该具备以下特征：

- 比 JetBrains 系工具更轻
- 比 Electron 类工具更原生
- 比企业级数据库 IDE 更简单直接

产品优先级如下：

1. **连接速度**
2. **界面响应速度**
3. **资源占用控制**
4. **清晰的信息结构**
5. **安全默认值**
6. **在不过度设计前提下保持可扩展性**

---

## v1 核心范围

### MySQL
支持以下能力：

- 保存和管理 MySQL 连接
- 连接 / 断开连接
- 查看数据库列表
- 查看数据表列表
- 查看表结构
- 分页浏览表数据
- 手动执行 SQL
- 展示查询结果
- 基础执行历史
- 基础错误提示
- 支持导入.sql 文件

### Redis
支持以下能力：

- 保存和管理 Redis 连接
- 连接 / 断开连接
- 浏览 key 空间
- 搜索 key
- 查看 key 类型
- 查看 key 的 TTL
- 查看常见类型的值：
  - string
  - hash
  - list
  - set
  - zset
- 手动执行 Redis 命令
- 基础命令历史
- 基础错误提示

### 通用能力
- 左侧连接列表 / 侧边栏
- 最近连接
- 安全保存账号密码
- 支持深色模式
- 支持快捷键
- 基础设置页
- Debug 模式下的结构化日志

---

## v1 不做的内容

除非明确要求，否则不要加入以下功能：

- PostgreSQL 支持
- MongoDB 支持
- 第一阶段就做 SSH Tunnel 管理
- 可视化 Query Builder
- ER 图
- Redis Cluster 拓扑图
- 重型 SQL 自动补全引擎
- App 内置 AI 聊天
- 团队同步 / 云账号系统
- 插件市场
- Web 版本
- 跨平台支持

v1 必须保持收敛、可交付。

---

## 技术方向

### 语言与框架
- 开发语言：**Swift**
- UI 框架：**SwiftUI**
- 应用类型：原生 macOS App
- 最低系统版本：选用较新的 macOS 版本，但不要为过老系统做过多兼容性负担

### 架构
采用 **模块化 MVVM 风格架构**，清晰拆分以下层级：

- UI 层
- ViewModel / 状态层
- 领域服务层
- 驱动适配层 / 数据访问层

要求：

- 不要做超大的 ViewModel
- 不要把数据库连接或查询逻辑直接写进 SwiftUI View
- 不要把持久化、运行时状态、界面逻辑混在一起

建议的顶层模块划分：

- `App`
- `Features/Connections`
- `Features/MySQL`
- `Features/Redis`
- `Shared/UI`
- `Shared/Models`
- `Shared/Services`
- `Infrastructure/Storage`
- `Infrastructure/Security`
- `Infrastructure/Drivers`
- `Infrastructure/Logging`

---

## 设计原则

### 1. 原生优先
优先使用 macOS 原生交互方式。  
不要为了“像网页后台”而牺牲桌面应用体验。

### 2. 默认快速
应用应该启动快、切换流畅、连接迅速。

### 3. 控制内存
避免重量级抽象、无意义缓存、整表整库全量加载。

### 4. 安全操作
任何可能有破坏性的操作，都要有明确保护。

### 5. 范围小但完成度高
宁可少做，也要把核心链路做好。

### 6. 状态可预测
界面状态变化应该容易理解，避免隐式副作用。

---

## UI 设计原则

### 主界面布局
建议布局：

- 左侧边栏：
  - 保存的连接
  - 最近连接
- 中间主区域：
  - 当前数据库工作区
- 可选底部面板：
  - 日志 / 查询结果 / 错误信息

### MySQL 界面
MySQL 部分应重点支持：

- 数据库列表
- 表列表
- 表结构
- 表数据浏览
- SQL 编辑器
- 查询结果展示

### Redis 界面
Redis 部分应重点支持：

- key 浏览器
- key 搜索
- key 详情面板
- 命令行控制台
- 命令执行结果

### 交互要求
- 明确显示 loading 状态
- 连接和查询时不要整体卡住 UI
- 错误信息对用户可读
- 空状态要有引导性
- 键盘操作不能是事后补充，而应作为一等能力考虑

---

## 安全要求

### 凭证存储
- 密码必须存储在 **macOS Keychain**
- 不允许把明文密码写入普通本地文件
- 普通连接信息可以本地保存，但敏感凭证必须走安全存储

### 日志
- 禁止记录密码
- 禁止记录完整连接凭证
- 日志中涉及敏感连接信息时必须脱敏

### 危险操作保护
对于以下操作，应在适当场景中要求用户明确确认：

- `DROP`
- 无条件或高风险 `DELETE`
- Redis 批量删除
- 大范围破坏性命令

---

## 性能要求

### 启动
应用启动时不要主动预加载全部元数据。

### 连接管理
- 懒连接
- 谨慎复用连接
- 空闲连接适时关闭
- 不要做无限制连接池

### MySQL 数据浏览
- 必须分页
- 默认不要加载大表全量数据
- 必须有合理的行数限制

### Redis 浏览
- 尽量采用增量扫描方式
- 避免阻塞式全量 key 扫描
- 大 value 只做预览，不要一次性全量塞进内存

---

## 代码风格

### 通用原则
- 清晰优先于炫技
- 小类型、小函数、可组合
- 命名明确，不要滥用缩写
- 在合理范围内优先不可变数据
- 单个函数只做一件事

### Swift 风格
- 遵循标准 Swift 命名规范
- 类型名使用 `UpperCamelCase`
- 变量和函数使用 `lowerCamelCase`
- enum case 使用 `lowerCamelCase`
- 除极小局部作用域外，不使用单字母变量名
- 非必要不要强制解包
- 生产代码中避免 `try!`

### SwiftUI 约束
- View 应保持声明式、简洁
- 可复用 UI 要抽成子 View
- 数据库逻辑不能直接写在 View body 里
- 避免一个文件里塞进超大 View

### 并发
- 有意识地使用 Swift Concurrency
- UI 更新必须在正确的 actor 上执行
- 避免连接状态与查询状态竞争
- 对长时间任务尽量支持取消

---

## 错误处理

所有面向用户的操作都应返回结构化错误。

错误分类至少包括：

- connection error
- authentication error
- timeout
- network error
- query error
- parsing / decoding error
- unsupported operation
- internal unexpected error

要求：

- 开发日志可以详细
- 用户提示必须简洁、可理解
- 保留底层错误上下文，便于调试
- 禁止静默吞错

---

## 推荐项目结构

```text
DatabaseClient/
├── CLAUDE.md
├── DatabaseClientApp/
│   ├── App/
│   ├── Features/
│   │   ├── Connections/
│   │   ├── MySQL/
│   │   └── Redis/
│   ├── Shared/
│   │   ├── Models/
│   │   ├── UI/
│   │   └── Services/
│   ├── Infrastructure/
│   │   ├── Drivers/
│   │   ├── Security/
│   │   ├── Storage/
│   │   └── Logging/
│   └── Resources/
├── DatabaseClientTests/
└── DatabaseClientUITests/


## 领域模型规范

### 连接配置
保存的连接配置建议包含：

- id
- name
- databaseKind（`mysql` / `redis`）
- host
- port
- username（如适用）
- passwordReference（Keychain 中的引用，不保存明文密码）
- defaultDatabase / namespace（如适用）
- sslMode / tlsConfig（如实现）
- createdAt
- updatedAt
- lastUsedAt

### 运行时会话状态
持久化连接配置与运行时状态必须分离。

运行时状态建议包含：

- isConnected
- isConnecting
- connectionId
- serverInfo
- selectedDatabase
- selectedTable
- selectedKey
- recentErrors
- runningTaskState

除非有明确理由，不要把“持久化配置”和“运行时状态”混在同一个模型中。

### MySQL 领域模型建议
建议至少包含以下模型：

- `MySQLConnectionConfig`
- `MySQLSession`
- `MySQLDatabaseSummary`
- `MySQLTableSummary`
- `MySQLColumnDefinition`
- `MySQLQueryRequest`
- `MySQLQueryResult`
- `MySQLRowValue`

其中：

- `MySQLQueryResult` 应支持列定义、行数据、执行耗时、影响行数、错误信息
- `MySQLRowValue` 应能明确区分：
  - string
  - number
  - bool
  - date / datetime
  - null
  - binary / unsupported preview

### Redis 领域模型建议
建议至少包含以下模型：

- `RedisConnectionConfig`
- `RedisSession`
- `RedisKeySummary`
- `RedisKeyDetail`
- `RedisValueType`
- `RedisCommandRequest`
- `RedisCommandResult`

其中：

- `RedisKeySummary` 应包含 key 名称、类型、TTL、大小或摘要信息（如可获取）
- `RedisValueType` 应覆盖：
  - string
  - hash
  - list
  - set
  - zset
  - stream（如后续扩展）
  - unknown

---

## 驱动层规则

所有数据库驱动都必须封装在内部抽象之后。  
UI 层和 Feature 层不能直接依赖第三方驱动 API。

建议定义如下协议：

- `MySQLClientProtocol`
- `RedisClientProtocol`

驱动适配层职责：

- connect / disconnect
- ping
- execute query / command
- fetch metadata
- fetch paginated data
- map low-level errors into internal error types
- map low-level raw results into domain models

### 驱动层约束
- 不允许把第三方驱动返回类型直接暴露给 UI 层
- 不允许在 ViewModel 中直接写第三方驱动调用代码
- 不允许把驱动层和本地持久化层混在一起

### 适配器目标
驱动层必须做到：

- 可替换
- 可 mock
- 可测试
- 对上层隐藏第三方库细节

---

## 存储规则

### 本地持久化允许保存的内容
只允许本地保存以下内容：

- 连接基础信息
- 用户设置
- 最近使用记录
- 必要的窗口状态 / UI 偏好

### 禁止持久化的内容
不要保存以下内容：

- Keychain 之外的明文密码
- 默认情况下的全量表数据缓存
- 大体积 Redis value 的持久化副本
- 未做轮转的无限增长日志
- 查询结果中的敏感数据快照（除非明确设计为用户导出功能）

### 存储层建议
建议拆分为：

- `ConnectionRepository`
- `SettingsRepository`
- `RecentHistoryRepository`
- `KeychainService`

存储层职责应仅限于：

- 读写本地配置
- 维护最近记录
- 管理安全凭证引用

不要在存储层中混入数据库连接逻辑。

---

## 日志规则

Debug 构建中应使用结构化日志。

### 建议记录的内容
- 功能进入 / 退出
- 连接创建 / 连接关闭
- 查询开始 / 结束
- 命令执行开始 / 结束
- 慢操作耗时
- 错误类别
- 重试行为（如果存在）

### 禁止记录的内容
- 密码
- 完整连接凭证
- 敏感业务数据明文
- 默认情况下的整表结果内容
- Redis 大 value 的完整内容

### 日志设计要求
- 日志的目标是帮助排查稳定性和性能问题
- 用户侧错误提示与开发日志必须分离
- 敏感字段必须脱敏
- 对同类高频日志应避免刷屏

---

## MySQL 功能实现要求

### 必备能力
- 列出数据库
- 列出表
- 查看表结构
- 分页浏览表数据
- 执行临时 SQL
- 展示查询结果
- 支持手动刷新
- 支持行数限制

### 结果展示要求
- 大结果集必须分页或限制返回条数
- 不能因查询结果过大而阻塞 UI
- `NULL` 值要有清晰视觉区分
- 列类型信息应在必要时可见
- 执行结果应展示：
  - 是否成功
  - 耗时
  - 影响行数（如适用）
  - 错误信息（如失败）

### SQL 编辑器要求
v1 只实现轻量能力：

- 文本输入
- 执行当前 SQL
- 展示结果
- 保留最近执行历史

以下能力不是 v1 必需项：

- 重型自动补全
- 复杂语义分析
- IDE 级别代码导航
- 多标签复杂编排系统

### 安全要求
对于高风险 SQL，需要额外防护或明确提示，例如：

- `DROP`
- `TRUNCATE`
- 无 `WHERE` 的 `DELETE`
- 大范围 `UPDATE`

---

## Redis 功能实现要求

### 必备能力
- 浏览 key
- 搜索 key
- 查看 key 类型
- 查看 TTL
- 查看 value
- 执行手动命令
- 展示基础命令结果

### Key 浏览要求
- 应优先使用增量扫描策略，如 `SCAN`
- 不要默认执行阻塞式全量获取
- 不要假设 key 数量很少
- 对大 key 空间应有基本保护措施

### Value 展示要求
对常见类型提供专门展示：

- string → 文本预览
- hash → 键值表格
- list → 有序列表
- set → 列表
- zset → member + score 表格

对于较大 value：

- 只显示预览
- 显示大小信息
- 支持按需加载
- 不能因为单个大 key 让界面卡死

### 命令执行要求
- 展示原始命令结果
- 对错误结果清晰提示
- 保留最近命令历史
- 高风险命令应谨慎处理，例如：
  - `FLUSHDB`
  - `FLUSHALL`
  - 大规模删除命令

---

## 测试要求

### 单元测试
重点覆盖以下内容：

- 连接配置校验
- 错误映射
- 结果转换逻辑
- 分页逻辑
- Redis value 格式化逻辑
- 本地存储辅助逻辑
- ViewModel 的关键状态流转

### 集成测试
在可行条件下覆盖：

- 连接测试 MySQL
- 执行简单 SQL
- 获取数据库和表结构
- 分页读取表数据
- 连接测试 Redis
- set / get / TTL / 类型读取
- 常见 key 类型读取

### 测试原则
- 单元测试优先覆盖纯逻辑部分
- 集成测试重点覆盖关键链路
- 不要过度依赖真实生产环境
- 测试数据应尽量小而稳定
- 对错误路径也要有覆盖

---

## UI 测试

UI 测试只覆盖高价值主流程，不追求面面俱到。

### 应覆盖的主流程
- 新建连接
- 编辑连接
- 删除连接
- 成功连接 MySQL
- 成功连接 Redis
- 浏览 MySQL 数据
- 浏览 Redis key
- 登录失败时展示错误
- 执行查询 / 命令后展示结果

### 不建议过早投入的内容
以下内容不应在早期投入大量 UI 自动化测试成本：

- 复杂视觉细节断言
- 高频变化页面的脆弱断言
- 大量依赖时序的测试
- 覆盖率导向的机械堆砌

### UI 测试目标
UI 测试的目标是验证：

- 关键主流程可用
- 基本交互没有回归
- 常见错误路径能正确提示
- 主要页面不会出现明显功能断裂