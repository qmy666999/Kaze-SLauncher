# Kaze SLauncher 0.11.3（arm64，已签名）

安装包**不放在仓库里**（33 MB 二进制会让仓库越来越大），请从 Releases 下载：

- 发行页：https://github.com/qmy666999/Kaze-SLauncher/releases/tag/v0.11.3
- 直链：https://github.com/qmy666999/Kaze-SLauncher/releases/download/v0.11.3/Kaze-SLauncher-0.11.3-arm64-signed.apk

- 适用：Android 7.0+（minSdk 27），arm64-v8a
- 版本：versionCode 38 / versionName 0.11.3
- 签名：CN=Kaze SLauncher，SHA-256
  `674f95fb44d6b62f615b35061400ad21290f784bf4e565876bb2324506974128`
- 校验（下载后）：

  ```sh
  sha256sum -c SHA256SUMS.txt
  ```

- 本版重点：修复资源中心 HTTP 404（URL 少斜杠）、版本/下载地址官方源优先、
  公网与远程一键刷新/樱花刷新/frps 检测、资源中心「检测各源」。
- 只提供 arm64；32 位设备请按 README 的构建步骤自行打 armhf 包。