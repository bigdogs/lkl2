
# lkl2 日志查看器设计文档

## 背景
内部日志采用“每行一个 JSON 事件”的格式，使用通用编辑器（Notepad++、VSCode 等）阅读时不具备良好的可读性和检索效率。本项目旨在提供一款专用日志查看器，提升日志定位、筛选与分析效率。

## 痛点与目标
- 每行日志字段极多（约 1–2KB），原文展示难以一眼获取关键信息
- 需要按关键字段快速过滤，如事件名、时间、节点信息等
- 需要在原始日志中进行全文搜索，并在结果中高亮上下文
- 需要随时查看某一行原始 JSON 的完整、格式化视图

## 技术选型
- Flutter 负责 UI 渲染与交互（Material 3）
- Rust 负责核心逻辑：配置解析、文件读取、数据存储（SQLite/FTS）、过滤与搜索
- Flutter 与 Rust 通过 flutter_rust_bridge 进行跨语言调用  
  依赖版本固定为 2.11.1，见 [Cargo.toml](file:///Users/bigdogs/working/lkl2/rust/liblkl2/Cargo.toml)

## 架构总览
- UI（Flutter）  
  - 主日志区：显示关键信息列表  
  - 过滤设置区：关键字段过滤、全文搜索输入  
  - 过滤结果区：展示命中结果并高亮

## 配置文件
配置文件为 `lkl2.toml`，当前由 libparser 嵌入并解析，仅 [logs] 段用于列定义：

```toml
[logs]
lineNumber = "$lineno"
eventTime  = "$line.Event.paltformUtcTime"
eventName  = "$line.Event.telemetryEventName"
sourceNodeId = "$line.Event.SourcenodeId"
targetNodeId = "$line.Event.TargetnodeId"
```

- 语法说明  
  - `$lineno`：当前行号  
  - `$line` 或 `$0`：当前行 JSON 根对象  
  - `$line.<path>`：从根对象开始的点号路径
- 完整示例参见 [lkl2.toml](file:///Users/bigdogs/working/lkl2/rust/libparser/lkl2.toml)

备注：`[[col]]` 段为 UI 渲染配置的预留示例，目前 libparser 未解析该段，后续由 Flutter 层解析并驱动渲染。这里还未设计完整需要后续继续完善


## 功能设计
### 关键信息展示
- 仅显示时间、事件名、核心字段（如文件路径、进程 ID 等），由配置驱动

### 原始 JSON 展示
- 右键菜单“显示 JSON”，弹窗展示格式化后的完整 JSON

### 关键字段过滤
- 在过滤区域提供下拉选项，按已配置的列进行过滤（等值、前缀、包含等）

### 全文搜索与高亮
- 在原始日志中全文搜索，结果区展示命中片段，并进行高亮与上下文截取

## UI 设计
### UI 风格
- Material 3，全局主题色为蓝，支持主题切换
- 样式与交互严格遵循 Material 3

### 菜单
- File → Open（打开文件）
- View → Reload（从磁盘重新加载）

### 页面布局
- 未加载：居中展示文件拖拽/上传窗口，支持拖放与“选择文件”按钮
- 加载中：显示进度与占位骨架（主日志区显示 shimmer，过滤区禁用控件）
- 已加载：页面上下三部分  
  - 主日志区：关键信息列表，支持虚拟化渲染与懒加载  
  - 过滤设置区：关键字段过滤控件 + 全文搜索框  
  - 过滤结果区：展示命中日志与高亮

### 日志显示
#### 1. 关键信息
- 依据配置列渲染，支持列宽、标签与文本组合，行内多段展示

#### 2. 搜索高亮
```text
...this is a <highlight>keyword</highlight> log very very long...
```
仅在过滤结果区展示，并提供上下文截取与命中计数

## UI 交互
- 拖动分割线调节主日志区与过滤区占比
- 右键菜单：显示 JSON、复制行、复制字段
- 过滤交互：  
  - 关键字段下拉选择与输入  
  - 搜索框输入后 Enter/按钮触发搜索，命中则在过滤结果区展示并高亮