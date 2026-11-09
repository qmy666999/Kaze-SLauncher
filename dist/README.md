# Kaze SLauncher 0.11.2（arm64，已签名）

- 适用：Android 7.0+（minSdk 27），arm64-v8a
- 版本：versionCode 37 / versionName 0.11.2
- 签名：CN=Kaze SLauncher
  SHA-256：674f95fb44d6b62f615b35061400ad21290f784bf4e565876bb2324506974128
- 覆盖安装要求与旧版**同一签名**（本目录的包与 0.9.x~0.11.x 签名一致）
- 校验：

  ```sh
  sha256sum -c SHA256SUMS.txt
  ```

- 本版重点：樱花映射**保持登录**（访问密钥加密保存，进页面自动恢复；令牌失效才清除）。
- 说明：只提供 arm64；32 位设备请按 README 的构建步骤自行打 armhf 包。