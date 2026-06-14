# Floating Countdown Qt Quick

这是 Floating Countdown 的 Qt Quick / QML 原生版本，用于提供比 Electron 更小、比纯 Win32/AppKit 更统一美观的桌面包。

## 目标平台

当前优先支持 Windows ARM64。macOS ARM64 会复用同一套 Qt/QML 工程后续补齐。

## 依赖

- Qt 6.5 或更新版本，包含 Qt Quick
- CMake 3.21 或更新版本
- Ninja
- Windows ARM64 C++ 构建工具链

## Windows ARM64 构建

```powershell
cmake -S native\qt-qml -B native\qt-qml\build\windows-arm64 -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build native\qt-qml\build\windows-arm64 --config Release
```

## Windows ARM64 打包

```powershell
powershell -ExecutionPolicy Bypass -File native\qt-qml\scripts\package-windows-arm64.ps1
```

输出文件：

```text
release-native\FloatingCountdown-win32-arm64-qt.zip
```
