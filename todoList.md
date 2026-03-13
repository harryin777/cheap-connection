# Todo List - V1 版本开发计划

基于 CLAUDE.md 规划的 V1 功能范围，分解为以下开发阶段。

---

## UI 设计原则

**与 DataGrip 保持一致的 UI 风格：**

- **左侧边栏**：树形结构显示数据库连接，可展开查看数据库/表层级
- **主工作区**：标签页式布局（Console、数据编辑器等）
- **数据表格**：紧凑、专业、列头固定、行号显示、斑马纹
- **SQL 编辑器**：顶部工具栏，执行按钮、历史记录下拉
- **整体风格**：紧凑、信息密度高、深浅色模式支持
- **工具栏**：简洁的图标按钮，hover 提示
- **状态栏**：显示连接状态、查询信息

---

## 阶段 0: 项目基础设施 ✅

### 0.1 项目初始化
- [x] 创建 Xcode 项目 (SwiftUI + macOS)
- [x] 配置最低系统版本 (macOS 15 Sequoia)
- [x] 创建目录结构
  ```
  DatabaseClient/
  ├── App/
  ├── Features/
  │   ├── Connections/
  │   ├── MySQL/
  │   └── Redis/
  ├── Shared/
  │   ├── Models/
  │   ├── UI/
  │   └── Services/
  └── Infrastructure/
      ├── Drivers/
      ├── Security/
      ├── Storage/
      └── Logging/
  ```

### 0.2 基础模型定义
- [x] 定义 `DatabaseKind` 枚举 (mysql / redis)
- [x] 定义 `ConnectionConfig` 基础模型
- [x] 定义 `AppError` 错误类型体系
- [x] 定义通用分页模型 `PaginationState`

---

## 阶段 1: 连接管理基础 ✅

### 1.1 安全存储层
- [x] 实现 `KeychainService` 协议
- [x] 密码存储 / 读取 / 删除
- [x] 敏感信息脱敏处理

### 1.2 本地持久化层
- [x] 实现 `ConnectionRepository`
- [x] 连接配置的 CRUD 操作
- [x] 实现 `RecentHistoryRepository`
- [x] 最近连接记录管理

### 1.3 连接配置 UI
- [x] 连接列表侧边栏
- [x] 新建连接表单
- [x] 编辑连接表单
- [x] 删除连接确认对话框
- [x] 连接图标 / 状态显示

---

## 阶段 2: MySQL 核心功能

### 维护规则
- 功能清单只保留稳定的 V1 能力范围，不按每次小改动持续膨胀
- Bug 清单只保留当前待修问题
- 已解决的 bug 直接从 bug 清单删除，不保留历史堆叠
- 新发现的问题统一追加到“2.B MySQL 当前待修 Bug”

### 2.A MySQL 功能范围

#### 2.1 MySQL 驱动层 ✅
- [x] 定义 `MySQLClientProtocol` 协议
- [x] 实现 `MySQLErrorMapper` 错误映射器
- [x] 实现 `MySQLClient` 适配器
- [x] 集成 MySQLKit SPM 依赖
- [x] 连接 / 断开 / 心跳检测测试 (实际验证) ✅

#### 2.2 MySQL 领域模型 ✅
- [x] `MySQLConnectionConfig`
- [x] `MySQLSession` 运行时状态
- [x] `MySQLDatabaseSummary`
- [x] `MySQLTableSummary`
- [x] `MySQLColumnDefinition`
- [x] `MySQLQueryResult`
- [x] `MySQLRowValue`
- [x] `SQLRiskLevel` SQL风险分析

#### 2.3 MySQL 服务层 ✅
- [x] `MySQLService` - 封装数据库操作
- [x] 获取数据库列表
- [x] 获取表列表
- [x] 获取表结构
- [x] 分页查询表数据
- [x] 执行任意 SQL

#### 2.4 MySQL UI - DataGrip 风格 ✅
- [x] `MySQLWorkspaceView` 主工作区布局
- [x] `MySQLSidebarView` 树形侧边栏
- [x] `MySQLStructureView` 表结构视图
- [x] `MySQLDataView` 数据浏览视图
- [x] `MySQLResultView` 查询结果展示
- [x] UI 风格对齐 DataGrip (紧凑、斑马纹、工具栏)

#### 2.5 MySQL UI - SQL 编辑器 ✅
- [x] `MySQLEditorView` SQL编辑器
- [x] 执行按钮 / 绿色播放图标
- [x] `MySQLResultView` 查询结果展示
- [x] 执行信息 (耗时 / 影响行数)
- [x] 基础执行历史
- [x] **SQL 自动补全** - 表名和列名提示

#### 2.5.1 MySQL UI - 数据表格增强 ✅
- [x] 鼠标悬停单元格展示全部内容 (Tooltip)
- [x] 双击单元格进入编辑模式
- [x] 单元格选中高亮
- [x] 编辑后保存到数据库
- [x] SQL 标签页查询结果也支持双击编辑

#### 2.6 MySQL 安全防护 ✅
- [x] 高风险 SQL 检测 (DROP / TRUNCATE / 无条件 DELETE)
- [x] 危险操作确认对话框

#### 2.7 MySQL 数据导入 ✅
- [x] 导入 .sql 文件并执行
- [x] 文件选择对话框
- [x] 导入进度 / 结果反馈

#### 2.8 MySQL SQL 文件控制台 ✅
- [x] 打开外部 .sql 文件到编辑器
- [x] 选择连接执行 SQL
- [x] 保留"导入执行"功能（导入后自动执行所有语句）

#### 2.9 集成 ✅
- [x] 所有 MySQL 文件已添加到 Xcode 项目
- [x] MySQLKit 依赖已添加
- [x] 编译通过

### 2.B MySQL 当前待修 Bug
- [ ] 主界面分栏出现异常 gutter，左侧树与右侧工作区边界未对齐
- [ ] MySQL 左侧资源树回归：连接已成功但数据库列表不渲染
- [ ] 右侧 query context selector 仍未真正独立：connection pill 不能稳定单独切换，schema/database pill 也不能独立选择
- [ ] 左侧资源树与右侧 query context 仍存在错误联动，左右两边必须完全独立，互不覆盖状态
- [ ] query connection 切换时，connection menu 选择不生效，右上角 connection pill 仍停留在旧连接名
- [ ] query connection 切换时，schema/database pill 标题不随连接一起切换，仍残留旧库名
- [ ] query connection 切换时，schema/database pill 的列表没有稳定切到新连接数据库集合
- [ ] query connection 切换链路需要确认 editorTabs 更新、activeQueryTab 传播、Menu label 重建三者一致
- [ ] SQL 结果和表数据网格的列表头未固定
- [ ] 结果网格横向滚动同步、列宽拖拽同步
- [ ] 验证双向切换不会出现库名串连

---

## 阶段 3: Redis 核心功能

### 3.1 Redis 驱动层
- [ ] 定义 `RedisClientProtocol` 协议
- [ ] 集成 Redis 驱动库 (选择: RediStack / 其他)
- [ ] 实现 `RedisClient` 适配器
- [ ] 连接 / 断开 / PING 检测
- [ ] 错误映射到内部错误类型

### 3.2 Redis 领域模型
- [ ] `RedisConnectionConfig`
- [ ] `RedisSession` 运行时状态
- [ ] `RedisKeySummary`
- [ ] `RedisKeyDetail`
- [ ] `RedisValueType` 枚举
- [ ] `RedisCommandResult`

### 3.3 Redis 服务层
- [ ] `RedisService` - 封装 Redis 操作
- [ ] SCAN 增量扫描 key
- [ ] 获取 key 类型 (TYPE)
- [ ] 获取 TTL (TTL / PTTL)
- [ ] 获取各类型 value (GET / HGETALL / LRANGE / SMEMBERS / ZRANGE)

### 3.4 Redis UI - Key 浏览
- [ ] Key 列表视图 (增量加载)
- [ ] Key 搜索功能
- [ ] Key 详情面板
- [ ] 类型 / TTL 显示

### 3.5 Redis UI - Value 展示
- [ ] String 类型展示
- [ ] Hash 类型展示 (键值表格)
- [ ] List 类型展示 (有序列表)
- [ ] Set 类型展示 (列表)
- [ ] ZSet 类型展示 (member + score 表格)
- [ ] 大 value 预览 / 按需加载

### 3.6 Redis UI - 命令执行
- [ ] 命令输入界面
- [ ] 命令执行 / 结果展示
- [ ] 基础命令历史

### 3.7 Redis 安全防护
- [ ] 高风险命令检测 (FLUSHDB / FLUSHALL / 大规模删除)
- [ ] 危险操作确认对话框

---

## 阶段 4: 通用功能完善

### 4.1 用户体验
- [ ] 深色模式支持
- [ ] 全局快捷键
- [ ] 常用操作快捷键 (新建连接 / 执行 / 刷新)
- [ ] 窗口状态记忆

### 4.2 设置页
- [ ] 基础设置 UI
- [ ] 默认行数限制设置
- [ ] 连接超时设置
- [ ] 外观设置

### 4.3 日志系统
- [ ] 结构化日志实现
- [ ] Debug 模式日志开关
- [ ] 敏感信息脱敏

### 4.4 最近连接
- [x] 最近连接列表
- [x] 快速连接入口

---

## 阶段 5: 测试与优化

### 5.1 单元测试
- [ ] 连接配置校验测试
- [ ] 错误映射测试
- [ ] 结果转换逻辑测试
- [ ] 分页逻辑测试
- [ ] Redis value 格式化测试
- [ ] ViewModel 状态流转测试

### 5.2 集成测试
- [ ] MySQL 连接测试
- [ ] MySQL 基础查询测试
- [ ] Redis 连接测试
- [ ] Redis 基础命令测试

### 5.3 UI 测试
- [ ] 新建 / 编辑 / 删除连接
- [ ] MySQL 连接和数据浏览
- [ ] Redis 连接和 key 浏览
- [ ] 错误提示展示

### 5.4 性能优化
- [ ] 启动速度优化
- [ ] 大数据集加载测试
- [ ] 内存占用监控

---

## 里程碑节点

| 里程碑 | 目标 | 状态 |
|--------|------|------|
| M1 | 阶段 0-1 完成，可管理连接配置 | ✅ |
| M2 | 阶段 2 完成，MySQL 核心功能可用 | ✅ |
| M3 | 阶段 3 完成，Redis 核心功能可用 | 🔲 |
| M4 | 阶段 4 完成，通用功能完善 | 🔲 |
| M5 | 阶段 5 完成，V1 发布就绪 | 🔲 |

---

## 状态说明

- 🔲 未开始
- 🔄 进行中
- ✅ 已完成
- ⏸️ 暂停
