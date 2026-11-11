# Kaze SLauncher

> **语言 / Language**：**简体中文** · [English](docs/User-Guide.md)

> 在 Android 手机上运行 **Minecraft Java 版服务端**的启动器。应用内置基于 proot 的 Ubuntu 24.04 运行环境，无需 Root，也不需要单独安装 Termux。

[![CI](https://github.com/0Sakura721/Kaze-SLauncher/actions/workflows/ci.yml/badge.svg)](https://github.com/0Sakura721/Kaze-SLauncher/actions/workflows/ci.yml)
![Kotlin](https://img.shields.io/badge/Kotlin-2.1-blue?logo=kotlin)
![Jetpack Compose](https://img.shields.io/badge/Jetpack%20Compose-Material%203-green)
![minSdk](https://img.shields.io/badge/minSdk-24-orange)
![License](https://img.shields.io/badge/license-GPL--3.0-blue)

请从 [GitHub Releases](https://github.com/0Sakura721/Kaze-SLauncher/releases) 获取安装包；版本变更见 [CHANGELOG.md](CHANGELOG.md)。

> **关于液态玻璃：** 液态玻璃主题已从主线构建中移除，但相关代码仍保留在仓库中。需要该主题时，请查看 [`liquidglassver` 分支说明](LIQUIDGLASS_BRANCH.md)，不要把该分支直接合并回主线。

## 文档导航

| 想了解 | 文档 |
|---|---|
| 安装、操作、备份、AI 数据说明与常见问题 | [用户使用说明](docs/使用说明.md) |
| 代码维护、测试、CI 与历史踩坑记录 | [维护笔记](docs/MAINTENANCE.md) |
| 发布签名、密钥管理与发版检查 | [发布签名手册](docs/RELEASE-SIGNING.md) |
| 初始设计决策与架构演变（历史记录） | [项目计划](docs/PLAN.md) |
| 第三方代码、素材与许可证清单 | [第三方声明](THIRD_PARTY_NOTICES.md) |
| 液态玻璃分支的用途与使用方式 | [分支说明](LIQUIDGLASS_BRANCH.md) |

- **[English User Guide](docs/User-Guide.md)** — full user manual in English
## 快速开始

1. 从 [Releases](https://github.com/0Sakura721/Kaze-SLauncher/releases) 下载与设备架构相符的 APK 并安装。
2. 打开应用，在主页选择「部署」初始化 Linux 运行环境。首次部署需要联网，rootfs 已包含在 APK 中，无需再下载大型系统镜像。
3. 进入「服务端」→「新建」，选择核心与版本，设置内存、端口等参数，并明确勾选同意 Minecraft EULA。
4. 下载创建完成后启动服务端，在「控制台」查看实时日志或输入命令。首次启动会按应用流程处理 EULA 并重新启动服务端。

**如何选择 APK**

- **64 位 ARM 手机：** 选择 `arm64-v8a`。
- **32 位 ARM 设备：** 可尝试 `armeabi-v7a`，但该架构的真机验证较少，发布包会标记为 experimental。
- **Universal：** 当前发行不提供该包。

详细的页面操作与故障排查见 [用户使用说明](docs/使用说明.md)。

## 主要功能

### 服务端管理

- 支持 Vanilla、Paper、Purpur、Spigot、Fabric、Forge、NeoForge，以及导入自定义服务端 JAR。
- **基岩版**：一键下载 PowerNukkitX 创建基岩版实例（默认端口 19132/UDP），附加包按 `manifest.json` 自动分类并带 `pack_icon.png` 图标。
- 多实例独立管理，各自拥有目录、端口、内存与运行状态。
- 可安装 Java、管理 EULA 和 `server.properties`，并配置 JVM 附加参数与 `nogui`。
- 支持插件/模组搜索安装、启停、实例备份与恢复，以及通过系统文件选择器导入/导出。
- **模组界面显示真实图标**：从 jar 里读 `fabric.mod.json` / `mods.toml` / `mcmod.info`，抽 `icon.png`、`logo.png` 做列表图标，同时显示版本、加载器、作者、依赖与兼容性提示。
- **本地导入模组/插件**：文件选择器多选 jar，或直接选 `.zip` / `.mrpack` 整合包自动展开；按 SHA-1 去重、同名冲突先确认、加载器/版本不匹配只警告不拦截。
- **客户端模组同步**：把服务端启用中的模组打成 `client-pack.zip` / `.mrpack`，并在手机上起一个带令牌的局域网 HTTP 服务（`/mods.txt`、`/manifest.json`、`/mod/<文件>`），配套 `kaze-sync.sh` / `kaze-sync.ps1` 按 sha1 增量同步 —— 服务端换模组后玩家重跑一次即可。
- **资源中心**：模组 / 插件 / 资源包搜索与推荐（都带真实图标，**没下载也看得到**）、地图存档导入/下载/一键切换（旧世界自动备份）、基岩版服务端与附加包管理。
- **基岩版开服**：一键下载 PowerNukkitX 创建基岩版实例（官方 BDS 只有 x86_64，手机跑不了）；`.mcpack` / `.mcaddon` 按 manifest 分辨资源包/行为包，图标取包内 `pack_icon.png`。
- **常用指令面板**：控制台里可收起的 40 条常用命令（玩家/时间/世界/规则/维护五组），点一下即发送。
- **内容源自动回退**：内置官方 Modrinth 与 MCIM 国内镜像，官方不通自动切镜像，也可在资源中心右上角手动锁定/自定义。
- **客户端专用模组检测**：按 `environment=client`、已知渲染/界面模组名单、Modrinth `server_side` 三重判定，结果默认勾选，可「停用所选」或「全部停用」（只改名 `.disabled`，不删文件）。
- **崩溃自动重启**：「实例详情 → 高级设置」里开关；连续重启上限 3 次、成功启动后计数清零（逻辑在服务端管理器里，已有崩溃循环保护）。
- **公网与远程**（主页「远程」）：**Tailscale**（检测/打开/复制 100.x 连接地址）、**樱花映射**（应用内用访问密钥登录 → 选隧道 → 一键起 frpc，配置由官方 API 生成）、**自建 frp**（填 frps 地址/令牌即可），以及**远程管理 API**（`/api/status`、`/api/logs`、`/api/command`、`/api/start|stop`，经 Tailscale/frp 暴露后浏览器可远程看日志/发命令/启停）。
- **远程串流说明**：Sunshine / foundation-sunshine 是 x86_64 桌面串流服务端（需 GPU 编码），手机 ARM 跑不了；页面内给出「PC 装 Sunshine + 手机 Moonlight + 同一 Tailscale」的可行方案与链接。
- 支持优雅停止、一键重启、实例置顶、连接地址复制和停服自动备份。

### 运行环境与控制台

- APK 内置 Ubuntu 24.04 rootfs 和修补版 proot；不需要 Root 或 Termux。
- **Java 版本默认自动、也可手动指定**：按 Minecraft 版本推断（1.8–1.16.5 → 8，1.17–1.20.4 → 17，1.20.5+ 及 24.x–25.x → 21，26.x 起 → 25，快照版按年份）。创建实例时可在「自动 / 8 / 17 / 21 / 25」里选；已创建的实例也能在「实例详情 → 高级设置」随时改（同一台设备装了多个 Java、或整合包要求特定版本时有用）；自定义核心还会尝试按 JAR 的 class 文件版本推断。
- 控制台支持实时日志、命令输入、日志筛选与搜索、快捷命令、玩家管理以及 CPU/内存监控。
- **离线控制台**：服务端没启动也能用 —— `props`（改 server.properties）、`wl`（白名单）、`mods enable/disable`、`ls`/`cat`/`grep`，以及 `sh <命令>` 进 proot 执行任意 Linux 命令。
- 应用内更新支持完整 APK 与增量更新；下载后会验证 SHA-256，失败时可回退到完整包。

### 可选 AI 助手

- 可协助诊断日志、读取实例文件、读取你指定的网页、生成文件修改建议和执行控制台命令。
- **每个工具可单独设权限**（自动 / 每次询问 / 禁止）；文件写入默认每次确认，敏感文件（凭据、`ops.json`、开了 rcon 的 `server.properties`）读取也要确认，控制台命令另有「仅建议 / 白名单自动 / 全部自动」三档。
- **技能（skills）**：把 `SKILL.md` 放进实例目录的 `skills/<名字>/`，AI 就会知道它、需要时自己读取全文 —— 用来教它你这个服特有的流程。清单会进系统提示，正文按需读取；可在「AI 设置 → 技能」逐个开关。
- **不联网搜索**：AI 只会调用你自己填的服务地址，不会自行检索；要它看网页就把链接发给它。
- **隐私提示：** 你配置的模型服务会收到实例状态、近期控制台日志（其中可能包含玩家聊天）、经你确认读取的文件内容（含技能文档）。配置前请阅读 [AI 助手数据说明](docs/使用说明.md#12-ai-助手会发什么数据--key-存哪--技能)。

## 开发与构建

### 环境要求

- JDK 17 或更高版本。
- Android SDK，包含 Android 35 平台与对应 Build Tools。
- 使用仓库内的 Gradle Wrapper，无需单独安装 Gradle。

### 常用命令

~~~bash
# arm64-v8a Debug APK
./gradlew :app:assembleArm64Debug

# armeabi-v7a Debug APK（experimental）
./gradlew :app:assembleArmhfDebug

# 单元测试
./gradlew :app:testArm64DebugUnitTest

# 生成 Robolectric / Roborazzi 界面截图
./gradlew :app:recordRoborazziArm64Debug

# Release APK（必须配置正式签名密钥）
./gradlew :app:assembleArm64Release :app:assembleArmhfRelease
~~~

APK 输出位于 `app/build/outputs/apk/` 下对应的架构与构建类型目录。Release 签名从本地 `local.properties` 或 CI 环境变量读取；**缺少签名凭据时不会回退使用 debug 密钥**。发布前请核验 APK 签名，具体步骤见 [发布签名手册](docs/RELEASE-SIGNING.md)。

### 代码结构

~~~text
app/src/main/java/com/kaze/newage/
├── ui/       # Jetpack Compose 页面、组件、主题与导航
├── core/     # 环境部署、Java 管理、服务端生命周期、下载、更新与 AI
├── data/     # 实例、设置与数据模型
└── util/     # 下载、解压、存储等工具

app/src/test/          # 单元测试与界面截图测试
.github/workflows/     # CI、APK 构建与 Release 流水线
~~~

CI 会运行单元测试和界面截图测试；Release 流水线还会检查正式 APK 的签名。涉及真机权限、后台保活、设备兼容性与部分服务端安装器的行为，仍需在真实 ARM 设备上验证。

## 已知限制

- **x86_64 模拟器不适合运行服务端。** proot 的运行依赖与常见模拟器的 ARM 翻译层不兼容；界面测试可用，但部署环境与实际服务端运行请优先使用真实 ARM 设备。
- Forge / NeoForge 的 `--installServer` 路径尚未在所有设备和版本上完成真机验证；失败时请查看安装器完整输出。
- 首次部署、安装 Java、下载服务端核心及附加内容需要网络。
- Spigot 使用社区 CDN，可能无法获得与其他核心相同的官方哈希校验信息。
- `armeabi-v7a` 包的设备覆盖验证少于 `arm64-v8a`。

## 许可证与致谢

项目整体采用 **GPL-3.0**（按 GPL-3.0 第 9 条可选用任何更新版本），见 [LICENSE](LICENSE)；版权归属与许可证适用说明见 [COPYRIGHT](COPYRIGHT)；第三方代码、素材、二进制及运行时组件清单见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

> **为什么不能改成更宽松的许可证**：本项目改编了 GPL-3.0 项目的源代码（FCL / ZalithLauncher 2 / PojavLauncher），GPL 具有传染性，改编作品必须同样以 GPL-3.0 发布。许可证全文随 APK 内置，可在应用内「设置 → 关于与许可证」查看。

本项目参考或改编了 [Fold Craft Launcher](https://github.com/FCL-Team/FoldCraftLauncher)、[ZalithLauncher 2](https://github.com/ZalithLauncher/ZalithLauncher2)、[PojavLauncher](https://github.com/PojavLauncherTeam/PojavLauncher)、[Miuix](https://github.com/Miuix-Kotlin-Multiplatform/Miuix) 等项目。具体来源与许可证以第三方声明及对应上游许可证文本为准。

## ☕ 赞助支持

如果这个项目对你有帮助，可以请我喝杯奶茶 ☕

| 支付宝（推荐） |
|:------:|
| ![支付宝](docs/images/alipay.jpg) |

> 扫码时请确认收款人显示为「洋洋」，谨防仿冒二维码。

## 📦 直接安装包

`dist/` 目录里放了**已签名**的 arm64 安装包（随源码一起提交，方便没有构建环境的用户）：

- `dist/Kaze-SLauncher-0.13.3-arm64-signed.apk`（versionCode 45 / versionName 0.13.3）
- `dist/SHA256SUMS.txt`：安装包校验值，下载后可自行核对
- 签名证书 SHA-256：`674f95fb44d6b62f615b35061400ad21290f784bf4e565876bb2324506974128`
  （与旧版本一致，可覆盖升级；换签名会导致无法覆盖安装）

> 正式分发建议在 GitHub **Releases** 里挂 APK（不进 git 历史、不占仓库体积）；
> `dist/` 这份是为了"克隆下来就能装"。

## 免责声明

- 使用 Minecraft 服务端前，请阅读并遵守 [Minecraft EULA](https://aka.ms/MinecraftEULA)。
- 本项目与 Mojang Studios 无隶属或背书关系；Minecraft 是其各自权利人拥有的商标。
- 请在重要操作前备份世界数据。因设备兼容性、系统后台限制、网络或误操作造成的数据损失，由使用者自行承担。
