# Floating Countdown

一个基于 Electron 的桌面悬浮倒计时程序，支持 Windows 和 macOS。

## 功能

- 自定义分钟数和秒数，默认 `01:00`
- 每 1 秒递减一次
- 开始、暂停、继续、重置
- Pin 后带过渡动画自动最小化设置窗口，并打开独立置顶时间悬浮窗
- 时间悬浮窗只展示时间、极简状态和 `Unpin` 恢复按钮
- 无边框半透明悬浮卡片界面
- 设置窗口和时间悬浮窗都可通过卡片区域拖动

## 运行

```bash
npm install
npm start
```

如果 Electron 下载失败，可以使用镜像重试：

```bash
ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/ npm install
```

## 使用说明

1. 输入分钟和秒数。
2. 点击“开始”启动倒计时。
3. 运行中点击“暂停”，暂停后点击“继续”。
4. 点击“重置”恢复到当前输入的分钟和秒数。
5. 点击 `Pin` 会最小化设置窗口，并显示一个置顶时间悬浮窗。
6. 在时间悬浮窗点击 `Unpin`，会关闭时间窗并恢复设置窗口。

## 发布与打包

### 下载发布包

已发布的 Windows 和 macOS ZIP 包可以在 GitHub Releases 下载：

- <https://github.com/kicocolor/FloatingCountdown/releases>
- 最新版本：<https://github.com/kicocolor/FloatingCountdown/releases/tag/v1.0.1>

当前发布包包含：

- `FloatingCountdown-win32-x64.zip`：Windows x64
- `FloatingCountdown-win32-arm64.zip`：Windows ARM64
- `FloatingCountdown-darwin-x64.zip`：macOS Intel
- `FloatingCountdown-darwin-arm64.zip`：macOS Apple Silicon

### 打包命令

推荐使用国内镜像打包，避免 Electron 运行时下载过慢。

```bash
ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/ npm run package:win
ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/ npm run package:win:x64
ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/ npm run package:win:arm64
npm run package:mac
npm run package:mac:x64
npm run package:mac:arm64
```

如果网络环境稳定，也可以不加 `ELECTRON_MIRROR`。如果下载卡住或失败，可以清理半截缓存后重试：

```bash
rm -rf ~/Library/Caches/electron
ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/ npm run package:win
```

为减少依赖，macOS 交叉打包不会写入 Windows 版本信息、图标或签名，因此不需要安装 Wine。

### 打包产物

完整 ZIP 产物位于 `release/`，适合上传到 GitHub Releases：

- `FloatingCountdown-win32-x64.zip`
- `FloatingCountdown-win32-arm64.zip`
- `FloatingCountdown-darwin-x64.zip`
- `FloatingCountdown-darwin-arm64.zip`

用于 Gitee 发行版上传的产物位于 `release-gitee/`。由于 Gitee 单个附件存在 100 MB 左右的大小限制，超过限制的 ZIP 会拆成 `.part-*` 分卷：

- `FloatingCountdown-darwin-arm64.zip`
- `FloatingCountdown-darwin-x64.zip.part-00`
- `FloatingCountdown-darwin-x64.zip.part-01`
- `FloatingCountdown-win32-x64.zip.part-00`
- `FloatingCountdown-win32-x64.zip.part-01`
- `FloatingCountdown-win32-arm64.zip.part-00`
- `FloatingCountdown-win32-arm64.zip.part-01`

Gitee 分卷合并说明见 `release-gitee/README-GITEE-RELEASE.txt`，校验值见 `release-gitee/SHA256SUMS.txt`。

### 运行打包产物

Windows 解压对应架构的 ZIP 后，运行目录内的 `FloatingCountdown.exe`。macOS 解压对应架构的 ZIP 后，运行 `FloatingCountdown.app`。

## 当前范围

当前提供 Windows 和 macOS 的便携 ZIP 打包，不包含安装器、代码签名、公证或自动更新。
