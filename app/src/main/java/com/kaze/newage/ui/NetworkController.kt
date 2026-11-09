package com.kaze.newage.ui

import android.content.Context
import com.kaze.newage.core.env.ProotEnvironment
import com.kaze.newage.core.net.NetworkAccess
import com.kaze.newage.core.net.SakuraFrpApi
import com.kaze.newage.core.net.SakuraTunnel
import com.kaze.newage.core.net.SakuraUser
import com.kaze.newage.core.server.ServerProperties
import com.kaze.newage.data.prefs.SettingsPrefs
import com.kaze.newage.data.model.ServerInstance
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * 公网访问控制器：Tailscale 状态、樱花映射登录/隧道、自建 frp、frpc 进程。
 *
 * 设计取舍：**只跑一个 frpc 实例**。同一条公网出口同时跑多条隧道没有意义，
 * 反而会出现"两个 frpc 抢同一个本地端口/同一条连接"的怪问题。切换线路就是先停再启。
 */
class NetworkController(
    private val context: Context,
    private val env: ProotEnvironment,
    private val prefs: SettingsPrefs,
    private val scope: CoroutineScope,
) {

    private val _tailscale = MutableStateFlow(NetworkAccess.Tailscale(false, emptyList(), emptyList()))
    val tailscale: StateFlow<NetworkAccess.Tailscale> = _tailscale.asStateFlow()

    data class SakuraState(
        val token: String = "",
        val user: SakuraUser? = null,
        val loading: Boolean = false,
        val tunnels: List<SakuraTunnel> = emptyList(),
        val selectedId: Long? = null,
        val error: String? = null,
        val message: String = "",
    )

    private val _sakura = MutableStateFlow(SakuraState(token = prefs.sakuraToken.value))
    val sakura: StateFlow<SakuraState> = _sakura.asStateFlow()

    /** frpc 进程状态（日志也在这里） */
    val frpc: NetworkAccess.FrpcRunner = NetworkAccess.FrpcRunner(env)

    /** 自建 frp 的操作反馈 */
    private val _message = MutableStateFlow("")
    val message: StateFlow<String> = _message.asStateFlow()

    /** 下载 frpc 的进度（0..1） */
    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()
    private val _progress = MutableStateFlow(0f)
    val progress: StateFlow<Float> = _progress.asStateFlow()

    fun refreshTailscale() {
        _tailscale.value = NetworkAccess.tailscale(context)
    }

    fun openTailscale(): Boolean = NetworkAccess.openTailscale(context)

    // ── 樱花映射 ──

    /**
     * "登录"= 用访问密钥换账号信息 + 隧道列表。
     *
     * 为什么不是用户名密码：樱花开放 API 只支持 Bearer 访问密钥（官网「账户 → 访问密钥」生成），
     * 密码登录带 2FA/风控，官方没有对第三方开放。把密钥加密存在本机，等价于"已登录"。
     */
    fun loginSakura(token: String) {
        val t = token.trim().ifBlank { prefs.sakuraToken.value }
        if (t.isBlank()) {
            _sakura.value = _sakura.value.copy(error = "先填访问密钥（樱花面板 → 账户 → 访问密钥）")
            return
        }
        _sakura.value = _sakura.value.copy(loading = true, error = null, message = "登录中…")
        scope.launch(Dispatchers.IO) {
            try {
                val user = SakuraFrpApi.userInfo(t)
                val tunnels = SakuraFrpApi.tunnels(t)
                prefs.setSakuraToken(t)
                _sakura.value = SakuraState(
                    token = t,
                    user = user,
                    loading = false,
                    tunnels = tunnels,
                    selectedId = tunnels.firstOrNull()?.id,
                    message = "已登录：${user.name}（${tunnels.size} 条隧道）",
                )
            } catch (e: Exception) {
                _sakura.value = _sakura.value.copy(
                    loading = false,
                    message = "",
                    error = e.message ?: "登录失败",
                )
            }
        }
    }

    fun logoutSakura() {
        prefs.setSakuraToken("")
        _sakura.value = SakuraState()
        frpc.stop()
    }

    fun selectTunnel(id: Long) {
        _sakura.value = _sakura.value.copy(selectedId = id, error = null)
    }

    fun startSakura(instance: ServerInstance) {
        val state = _sakura.value
        val id = state.selectedId
        if (state.token.isBlank() || id == null) {
            _sakura.value = state.copy(error = "先登录并选择一条隧道")
            return
        }
        if (_busy.value) return
        _busy.value = true
        _progress.value = 0f
        _sakura.value = state.copy(loading = true, error = null, message = "准备 frpc…")
        scope.launch(Dispatchers.IO) {
            try {
                ensureFrpc()
                _sakura.value = _sakura.value.copy(message = "生成隧道配置…")
                val config = SakuraFrpApi.tunnelConfig(state.token, id.toString())
                val ok = frpc.start(config, "樱花映射 #$id")
                _sakura.value = _sakura.value.copy(
                    loading = false,
                    message = if (ok) "已启动隧道 #$id（下方看日志）" else "",
                    error = if (ok) null else "frpc 启动失败（看下方日志）",
                )
            } catch (e: Exception) {
                _sakura.value = _sakura.value.copy(
                    loading = false,
                    message = "",
                    error = e.message ?: "启动失败",
                )
            } finally {
                _busy.value = false
            }
        }
    }

    // ── 自建 frp ──

    fun startCustomFrp(
        instance: ServerInstance,
        serverAddr: String,
        serverPort: Int,
        token: String,
        remotePort: Int,
    ) {
        if (serverAddr.isBlank()) {
            _message.value = "先填 frps 地址"
            return
        }
        if (_busy.value) return
        _busy.value = true
        _progress.value = 0f
        _message.value = "准备 frpc…"
        scope.launch(Dispatchers.IO) {
            try {
                ensureFrpc()
                val localPort = localPortOf(instance)
                val cfg = NetworkAccess.FrpConfig(
                    serverAddr = serverAddr.trim(),
                    serverPort = serverPort,
                    token = token,
                    proxyName = "kaze-" + instance.id.take(6),
                    localIp = "127.0.0.1",
                    localPort = localPort,
                    remotePort = remotePort,
                )
                prefs.setFrp(serverAddr, serverPort, token, remotePort)
                val ok = frpc.start(cfg.toToml(), "自建 frp $serverAddr:$serverPort")
                _message.value = if (ok) {
                    "已启动：服务器 ${serverAddr}:${serverPort} → 本地 ${localPort}（远程端口 $remotePort）"
                } else {
                    "frpc 启动失败（看下方日志）"
                }
            } catch (e: Exception) {
                _message.value = e.message ?: "启动失败"
            } finally {
                _busy.value = false
            }
        }
    }

    fun stopTunnel() {
        frpc.stop()
        _message.value = "已停止"
        _sakura.value = _sakura.value.copy(message = "已停止")
    }

    /** 本地服务端口：Java 读 server.properties，基岩版默认 19132 */
    fun localPortOf(instance: ServerInstance): Int =
        ServerProperties.load(instance.dir)["server-port"]?.toIntOrNull()
            ?: if (instance.bedrock) 19132 else 25565

    private fun ensureFrpc() {
        if (frpc.hasBinary()) return
        val client = SakuraFrpApi.frpcClient()
        val ok = frpc.ensureBinary(client.url, client.md5) { p, m ->
            _progress.value = p.coerceIn(0f, 1f)
            _message.value = m
        }
        if (!ok) throw RuntimeException("frpc 下载失败（检查网络）")
    }
}
