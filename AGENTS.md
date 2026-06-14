# Repository Guidelines

## 项目结构与模块组织

本仓库是一个基于 Electron 的桌面悬浮倒计时应用。

- `main.js`：Electron 主进程入口，负责窗口创建、置顶、最小化等应用生命周期逻辑。
- `preload.js`：向渲染进程暴露安全的桥接 API。
- `index.html`、`renderer.js`、`styles.css`：主设置窗口和倒计时界面。
- `mini.html`、`mini.js`、`mini.css`：独立的迷你悬浮倒计时窗口。
- `scripts/package-windows.js`、`scripts/package-macos.js`：生成 Windows 和 macOS ZIP 发布包。
- `release/`、`release-gitee/`：本地生成的发布产物，不要提交到 Git。

当前没有独立的 `test/` 目录或资源目录。新增文件时，尽量放在对应功能附近；生成物、缓存和打包文件应保持在版本控制之外。

## 构建、测试与开发命令

安装依赖：

```bash
npm install
```

本地运行 Electron 应用：

```bash
npm start
```

生成发布包：

```bash
npm run package:win        # Windows x64 和 arm64
npm run package:win:x64    # 仅 Windows x64
npm run package:win:arm64  # 仅 Windows arm64
npm run package:mac        # macOS Intel 和 Apple Silicon
npm run package:mac:x64    # 仅 macOS Intel
npm run package:mac:arm64  # 仅 macOS Apple Silicon
```

如果 Electron 下载较慢，可以在命令前加：`ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/`。

## 编码风格与命名约定

项目使用原生 JavaScript、HTML 和 CSS。保持现有风格：JSON 使用 2 空格缩进，JavaScript 保留分号，优先使用 `const`/`let`，变量和函数使用描述性的 camelCase 命名。主窗口逻辑放在 `renderer.js`，迷你窗口逻辑放在 `mini.js`，Electron 生命周期和窗口管理逻辑放在 `main.js`。

## 测试指南

当前尚未配置自动化测试框架。提交前至少运行 `npm start`，手动验证开始、暂停、继续、重置、Pin、Unpin 和窗口拖动行为。修改打包逻辑时，运行对应的 `npm run package:*` 命令，并确认预期 ZIP 出现在 `release/` 中。

## 提交与 Pull Request 规范

近期提交使用简短、明确的描述，例如 `Add macOS packaging script`、`Update release and packaging docs`。提交应聚焦单一目的，不要包含生成的 ZIP。Pull Request 应说明改动内容、影响平台、手动验证步骤；涉及 UI 时附截图或录屏。

## 发布与产物说明

GitHub 和 Gitee 对仓库文件大小都有约束，打包后的应用不要提交进 Git。大文件应通过 Releases 发布；如果 Gitee 附件超过大小限制，使用 `release-gitee/` 中生成的分卷文件上传。
