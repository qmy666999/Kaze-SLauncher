package com.kaze.newage.core.content

/**
 * 内容源（Modrinth 官方 + 国内镜像）。
 *
 * 为什么需要：`api.modrinth.com` 在部分网络下连不上（超时/被限速），
 * 而资源中心的搜索、推荐、安装版本解析**全部**依赖它 —— 一个源不通，整页就是
 * "没有可用条目"。这里预置官方源与 MCIM 镜像，默认**自动**：官方优先，失败立刻换镜像。
 *
 * 每个源都是**同构的 Modrinth v2 API**（路径完全一致），只是 host 不同，
 * 所以切换源不需要改任何业务代码。
 */
data class ContentSource(
    val id: String,
    val label: String,
    val baseUrl: String,
) {
    val isOfficial: Boolean get() = id == "official"
}

object ContentSources {

    const val OFFICIAL_URL = "https://api.modrinth.com/v2"

    /** MCIM（mcmod-info-mirror）提供的 Modrinth API 镜像，国内可直连 */
    const val MCIM_URL = "https://mod.mcimirror.top/modrinth/v2"

    val OFFICIAL = ContentSource("official", "官方 Modrinth", OFFICIAL_URL)
    val MCIM = ContentSource("mcim", "MCIM 国内镜像", MCIM_URL)

    val BUILT_IN: List<ContentSource> = listOf(OFFICIAL, MCIM)

    /** 设置里的取值：auto / official / mcim / custom */
    const val MODE_AUTO = "auto"
    const val MODE_CUSTOM = "custom"

    @Volatile
    private var order: List<ContentSource> = BUILT_IN

    /**
     * 按设置决定尝试顺序。
     *
     * 自动模式永远是「官方 → 镜像」：镜像的更新可能滞后几小时，
     * 能让官方先跑就让官方先跑；直连不通时才有一次超时代价。
     */
    @Synchronized
    fun configure(mode: String, customUrl: String = "") {
        val m = mode.trim().lowercase()
        order = when (m) {
            "official" -> listOf(OFFICIAL)
            "mcim" -> listOf(MCIM)
            MODE_CUSTOM -> {
                val custom = customUrl.trim().removeSuffix("/")
                if (custom.startsWith("https://") && custom.contains("/v2")) {
                    listOf(ContentSource("custom", "自定义源", custom)) + BUILT_IN
                } else {
                    BUILT_IN
                }
            }
            else -> BUILT_IN
        }
    }

    /** 当前尝试顺序（第一个是首选） */
    fun active(): List<ContentSource> = order

    fun labelOf(baseUrl: String): String =
        BUILT_IN.firstOrNull { it.baseUrl == baseUrl }?.label ?: "自定义源"

    /** 把接口地址（可能已带 host）还原成相对路径，便于换源重试 */
    fun pathOf(url: String): String {
        val idx = url.indexOf("/v2/")
        return if (idx >= 0) url.substring(idx + 3) else url
    }
}
