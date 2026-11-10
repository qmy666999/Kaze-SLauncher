# 服务端资源管理模块 PRD（对齐 ZalithLauncher2 交互范式）

> 适用范围：Kaze SLauncher（MC **Java 服务端**管理器）。
> 红线：只借鉴 ZL2 的**交互/信息结构/下载队列/资源管理体验**，不移植任何客户端启动、游戏渲染、客户端加载逻辑。
> 所有资源操作都落在「当前选中的服务实例目录」内，实例之间完全隔离。

---

## 0. 现状与差距（本仓库 0.13.x）

| 需求 | 现状 | 结论 |
|---|---|---|
| 在线模组库（Modrinth） | 已有搜索/推荐/详情/收藏/版本选择/镜像图标/翻页 | ✅ 基本完成 |
| 在线模组库（CurseForge） | 无（需 API Key + 适配器） | ⬜ 待做 |
| 只返回服务端模组 | 本次新增：按 `server_side/client_side` 过滤（默认开） | 🟡 本轮完成 |
| 筛选器：MC 版本 / 加载器 / 分类 / 排序 | 排序 + "全部版本"开关已有；版本/加载器/分类筛选 | ⬜ 待做 |
| 卡片布局对齐 ZL2 | 48dp 图标 + 标题/简介/下载量 + 详情弹窗 + 星标 | ✅ 完成 |
| 版本树 / 依赖树 | 版本列表（内嵌面板）已有；依赖树/缺失依赖推荐 | ⬜ 待做 |
| 全局下载队列 | 无 | ⬜ 待做（优先级最高） |
| 本地模组：开关/多选/删除/导出/更新扫描 | 开关、删除、体检（客户端专用检测）已有；多选/导出/扫描部分 | 🟡 部分 |
| 资源包在线库 / 本地 | 在线库已有；本地列表、启用禁用 | 🟡 部分 |
| 资源包拖拽排序 / 导入导出 / 预览 / 校验 | 无 | ⬜ 待做 |
| 存档缩略图（level.dat）/ 备份恢复 / 批量 | 缩略图与导入/删除已有；备份/恢复/重命名/批量 | 🟡 部分 |
| 下载失败原因弹窗 / 限速提示 | 错误信息已透出；无队列限速 | ⬜ 待做 |
| SAF / 实例隔离 | 导入走 SAF，文件全部在实例目录 | ✅ 完成 |

---

## 1. 页面结构

```
资源中心（ContentScreen）
├── 顶栏：实例名 · MC 版本 · 内容源（官方/镜像）· 一键刷新
├── Tab：模组 | 插件 | 资源包 | 地图 | 基岩版
├── 模组
│   ├── 子 Tab：在线库 | 本地模组
│   ├── 在线库
│   │   ├── 搜索框 + 排序 + 筛选栏（MC 版本 / 加载器 / 分类 / 仅服务端）
│   │   ├── 推荐区（可折叠）
│   │   ├── 搜索/推荐卡片行（图标、标题、简介、下载量、星标、安装）
│   │   ├── 内嵌版本面板（页面内，不弹窗）
│   │   └── 分页
│   └── 本地模组
│       ├── 多选工具条：启用/禁用、删除、导出、体检
│       └── 列表：图标、文件名、版本、加载器、启用开关
├── 资源包
│   ├── 子 Tab：在线库 | 本地
│   └── 本地：拖动排序（加载优先级）、启用/禁用、导入/导出、预览、校验
├── 地图（存档）
│   ├── 缩略图墙（level.dat 读取 icon.png / 生成占位）
│   ├── 操作：导入、从链接下载、备份、恢复、重命名、删除、批量
└── 全局下载面板（悬浮，跨页面可见）
    ├── 任务行：图标、名称、进度、速度、状态
    └── 操作：暂停/继续/取消/重试、失败原因
```

状态管理：每个 Tab 一个 Controller（`ContentController` / `AddonsController` / `WorldsController`），
下载队列全局单例 `DownloadQueue`（`StateFlow<List<DownloadTask>>`），由 AppContainer 持有。

---

## 2. 数据类定义（已实现/计划）

```kotlin
// 在线项目（已实现，ModrinthApi.kt）
@Serializable data class ModrinthProject(
    val id: String = "", val slug: String = "", val title: String = "",
    val description: String = "", val project_type: String = "",
    val icon_url: String = "", val downloads: Long = 0, val followers: Long = 0,
    val categories: List<String> = emptyList(),
    val game_versions: List<String> = emptyList(),
    val loaders: List<String> = emptyList(),
    /** required / optional / unsupported —— 服务端过滤依据 */
    val client_side: String = "", val server_side: String = "",
    val body: String = "",           // 详情正文
) {
    /** 服务端加载会崩/无意义：客户端必需，或服务端明确不支持 */
    val clientOnly: Boolean
        get() = server_side.equals("unsupported", true) ||
                client_side.equals("required", true)
}

@Serializable data class ModrinthVersion(
    val id: String = "", val project_id: String = "", val version_number: String = "",
    val game_versions: List<String> = emptyList(),
    val loaders: List<String> = emptyList(),
    val files: List<ModrinthFile> = emptyList(),
    val dependencies: List<ModrinthDependency> = emptyList(),   // 计划
)

@Serializable data class ModrinthDependency(
    val version_id: String? = null, val project_id: String? = null,
    val dependency_type: String = "required",  // required / optional / incompatible
)

// 下载队列（计划）
data class DownloadTask(
    val id: String,
    val kind: TaskKind,              // MOD / PLUGIN / RESOURCEPACK / WORLD / SERVER_JAR
    val title: String,
    val instanceId: String,
    val url: String,
    val dest: File,
    val totalBytes: Long = 0,
    val doneBytes: Long = 0,
    val state: State = State.QUEUED,
    val error: String? = null,
) {
    enum class State { QUEUED, RUNNING, PAUSED, DONE, FAILED, CANCELLED }
    enum class TaskKind { MOD, PLUGIN, RESOURCEPACK, WORLD, SERVER_JAR }
}

// 本地资源（计划）
data class LocalAddon(
    val file: File, val name: String, val version: String, val loader: String,
    val enabled: Boolean, val icon: File?, val clientOnly: Boolean,
)
data class LocalPack(
    val file: File, val name: String, val enabled: Boolean, val order: Int,
    val valid: Boolean, val preview: File?,
)
```

---

## 3. Modrinth 筛选参数（服务端模组）

搜索（`/v2/search`）只支持 `project_type / categories / versions` 等 facet，**没有**
`server_side` facet，所以分两步：

```text
GET /v2/search
  ?query=<关键词>
  &limit=20&offset=0
  &index=relevance|downloads|newest
  &facets=[["project_type:mod"],["categories:fabric","categories:quilt"],["versions:1.21.1"]]
```

再批量补详情并过滤：

```text
GET /v2/projects?ids=["id1","id2", ...]
→ 过滤 client_side == "required" 或 server_side == "unsupported"
```

插件同理：`project_type:plugin`，加载器 `paper/spigot/bukkit/purpur`。
资源包：`project_type:resourcepack`，**不要**带 loaders。

CurseForge（计划，需要 API Key）：

```text
GET https://api.curseforge.com/v1/mods/search
  ?gameId=432            # Minecraft
  &classId=6             # 6=Mods, 12=Resource Packs, 17=Worlds
  &gameVersion=1.21.1
  &modLoaderType=4       # 1=Forge 4=Fabric 5=Quilt 6=NeoForge
  &searchFilter=<关键词>
  &sortField=2&sortOrder=desc
  &index=0&pageSize=20
Header: x-api-key: <key>
```

CurseForge 没有 `client_side/server_side` 字段，只能：
1. 依赖 `classId`（资源包/地图天然不是模组）；
2. 对模组读取 `latestFiles` 的 `gameVersions` 与 `modLoaderType`；
3. 维护"已知客户端模组名单"（Sodium/Iris/ModMenu…）兜底过滤。

---

## 4. ViewModel / 状态设计

```kotlin
class ContentController(
    context: Context, instanceStore: InstanceStore, scope: CoroutineScope,
    prefs: SettingsPrefs, onInstanceCreated: (ServerInstance) -> Unit,
) {
    data class ContentUiState(
        val kind: ContentKind,
        val query: String, val sort: Sort,
        val page: Int, val hasMore: Boolean,
        val showAllVersions: Boolean,     // 现有
        val serverOnly: Boolean = true,   // 只显示服务端模组（新增）
        val hits: List<ModrinthSearchHit>,
        val favorites: Set<String>,
        val showFavoritesOnly: Boolean,
        // ...
    )
    data class VersionsPanel(project, loading, versions, includeAll, error)
    data class ProjectDetail(visible, loading, project, error)

    fun search(instance, query, sort, page)      // 内部按 serverOnly 过滤
    fun setServerOnly(v: Boolean)                // 重新搜索/推荐
    fun toggleVersionsPanel(instance, project)   // 页面内嵌版本面板
    fun installPanelVersion(instance, version)   // 安装指定版本
    fun toggleFavorite(id)
    fun openProjectDetail(project)
}
```

下载队列（计划）：

```kotlin
class DownloadQueue(private val scope: CoroutineScope) {
    val tasks: StateFlow<List<DownloadTask>>
    fun enqueue(task: DownloadTask): String
    fun pause(id: String); fun resume(id: String)
    fun cancel(id: String); fun retry(id: String)
    // 工作协程：串行 1~2 并发，Range 续传，失败写 error 原因
}
```

---

## 5. Compose UI 组件（资源管理页，无客户端逻辑）

### 5.1 在线模组卡片（已实现，节选）

```kotlin
@Composable
fun AddonCard(
    project: ModrinthProject,
    favorite: Boolean,
    busy: Boolean,
    onOpenDetail: () -> Unit,
    onToggleFavorite: () -> Unit,
    onInstall: () -> Unit,
) {
    M3EListItem(
        headline = project.title,
        supporting = "${formatDownloads(project.downloads)} 次下载 · ${project.description}",
        leading = { RemoteIcon(project.icon_url, Icons.Filled.Extension, size = 48.dp) },
        onClick = onOpenDetail,
        trailing = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onToggleFavorite) {
                    Icon(if (favorite) Icons.Filled.Star else Icons.Outlined.StarBorder, null)
                }
                Button(onClick = onInstall, enabled = !busy) { Text("安装") }
            }
        },
    )
}
```

### 5.2 内嵌版本面板（已实现，节选）

```kotlin
@Composable
fun VersionsPanelCard(
    state: VersionsPanel,
    onToggleAll: (Boolean) -> Unit,
    onInstall: (ModrinthVersion) -> Unit,
    onClose: () -> Unit,
) {
    M3ECard(variant = M3ECardVariant.Outlined, title = "版本 · ${state.project?.title.orEmpty()}") {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Switch(state.includeAll, onToggleAll)
            Text("显示全部 MC 版本")
            Spacer(Modifier.weight(1f))
            TextButton(onClose) { Text("收起") }
        }
        state.versions.forEach { v ->
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(v.version_number)
                    Text("${v.game_versions.take(4).joinToString("/")} · ${v.loaders.joinToString("/")}")
                }
                TextButton({ onInstall(v) }) { Text("安装") }
            }
        }
    }
}
```

### 5.3 下载任务面板（计划）

```kotlin
@Composable
fun DownloadPanel(tasks: List<DownloadTask>, onPause: (String) -> Unit, onCancel: (String) -> Unit) {
    Card(Modifier.fillMaxWidth()) {
        Text("下载任务（${tasks.count { it.state == RUNNING }} 进行中）")
        tasks.forEach { t ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(t.title)
                    LinearProgressIndicator(
                        progress = { if (t.totalBytes > 0) t.doneBytes.toFloat() / t.totalBytes else 0f },
                    )
                    Text(t.error ?: "${t.doneBytes / 1024} KB / ${t.totalBytes / 1024} KB")
                }
                when (t.state) {
                    RUNNING -> TextButton({ onPause(t.id) }) { Text("暂停") }
                    PAUSED -> TextButton({ onPause(t.id) }) { Text("继续") }
                    FAILED -> TextButton({ onCancel(t.id) }) { Text("重试") }
                    else -> {}
                }
            }
        }
    }
}
```

---

## 6. 风险清单：哪些模组不能装到服务端

**必须过滤（客户端专属，装到服务端多数直接崩或毫无作用）：**

| 类型 | 代表模组 | 判断依据 |
|---|---|---|
| 渲染/光影 | Sodium、Iris、OptiFine、Canvas、Embeddium、Rubidium | `environment=client` / 客户端专用 |
| 界面/HUD | ModMenu、JourneyMap、Xaero's Minimap、WTHIT、Jade | 纯客户端 |
| 资源/音效客户端 | Sound Physics、Dynamic Surroundings | 客户端 |
| 小地图/录像 | ReplayMod、Flashback | 客户端 |
| 按键/手柄 | Controlling、MidnightControls | 客户端 |
| 皮肤/披风 | Capes、Elytra Trims(部分) | 客户端 |

**可以装服务端（但需注意）：**

- Lithium / Krypton / FerriteCore / Spark / Fabric API：双端通用，服务端可用；
- AppleSkin：`environment=client`，服务端装了没用（应过滤）；
- Carpet / Axiom：服务端可用，但需要玩家端配合的功能要说明；
- 数据包类（datapack）不是模组，装 `mods/` 会崩。

**判定顺序（本项目实现）：**

1. `fabric.mod.json` 的 `environment: "client"` → 客户端专用；
2. Modrinth `server_side == "unsupported"` → 服务端不支持；
3. 已知客户端模组名单（Sodium/Iris/ModMenu…）兜底；
4. 无法判定 → 标"未知"，由用户决定（模组体检页可一键停用）。

---

## 7. 验收标准（本轮可验证）

- [x] 在线库默认**不显示**客户端专属模组（`server_side=unsupported` / `client_side=required`）；
- [x] 可开关「仅服务端模组」，关闭后能看到全部；
- [x] 版本选择在页面内展开，不弹窗；
- [x] 每行 48dp 图标、详情、收藏、下载量；
- [ ] 全局下载队列（暂停/继续/取消/重试）—— 待做；
- [ ] CurseForge 源（需 API Key）；
- [ ] 资源包拖拽排序 / 备份恢复 / 批量操作 —— 待做。

---

## 8. 里程碑建议

1. **M1（已完成）**：在线库 + 服务端过滤 + 版本选择 + 详情/收藏。
2. **M2**：全局下载队列（串行 + 暂停/重试 + 失败原因）+ 依赖缺失提示。
3. **M3**：本地模组多选/导出/更新扫描；资源包本地排序/导入导出/预览。
4. **M4**：存档备份/恢复/批量；CurseForge 适配器（API Key）。
