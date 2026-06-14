#include <windows.h>
#include <shlobj.h>

#include <cstdint>
#include <fstream>
#include <string>
#include <vector>

namespace {
constexpr char kMagic[] = "FCQTSFX1";

std::wstring archSuffix()
{
#if defined(_M_ARM64) || defined(__aarch64__)
    return L"Arm64";
#elif defined(_M_X64) || defined(__x86_64__)
    return L"X64";
#else
    return L"Unknown";
#endif
}

std::wstring quote(const std::wstring &value)
{
    std::wstring escaped;
    escaped.reserve(value.size() + 2);
    escaped.push_back(L'\'');
    for (wchar_t ch : value) {
        escaped.push_back(ch);
        if (ch == L'\'') {
            escaped.push_back(ch);
        }
    }
    escaped.push_back(L'\'');
    return escaped;
}

std::wstring modulePath()
{
    std::vector<wchar_t> buffer(MAX_PATH);
    DWORD length = 0;
    while (true) {
        length = GetModuleFileNameW(nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
        if (length == 0) {
            return L"";
        }
        if (length < buffer.size() - 1) {
            return std::wstring(buffer.data(), length);
        }
        buffer.resize(buffer.size() * 2);
    }
}

std::wstring knownFolder(int csidl)
{
    wchar_t path[MAX_PATH] = {};
    if (SHGetFolderPathW(nullptr, csidl, nullptr, SHGFP_TYPE_CURRENT, path) != S_OK) {
        return L"";
    }
    return path;
}

bool readPayload(const std::wstring &exePath, std::vector<char> *payload)
{
    std::ifstream input(exePath, std::ios::binary | std::ios::ate);
    if (!input) {
        return false;
    }

    const std::streamoff fileSize = input.tellg();
    const std::streamoff trailerSize = 16;
    if (fileSize <= trailerSize) {
        return false;
    }

    input.seekg(fileSize - trailerSize);
    char magic[8] = {};
    std::uint64_t payloadSize = 0;
    input.read(magic, sizeof(magic));
    input.read(reinterpret_cast<char *>(&payloadSize), sizeof(payloadSize));
    if (std::string(magic, sizeof(magic)) != std::string(kMagic, sizeof(magic)) || payloadSize == 0) {
        return false;
    }
    if (payloadSize > static_cast<std::uint64_t>(fileSize - trailerSize)) {
        return false;
    }

    payload->resize(static_cast<size_t>(payloadSize));
    input.seekg(fileSize - trailerSize - static_cast<std::streamoff>(payloadSize));
    input.read(payload->data(), static_cast<std::streamsize>(payload->size()));
    return input.good();
}

bool writeFile(const std::wstring &path, const std::vector<char> &data)
{
    std::ofstream output(path, std::ios::binary | std::ios::trunc);
    if (!output) {
        return false;
    }
    output.write(data.data(), static_cast<std::streamsize>(data.size()));
    return output.good();
}

bool writeTextFile(const std::wstring &path, const std::wstring &data)
{
    std::wofstream output(path, std::ios::trunc);
    if (!output) {
        return false;
    }
    output << data;
    return output.good();
}

std::wstring readTextFile(const std::wstring &path)
{
    std::wifstream input(path);
    if (!input) {
        return L"";
    }

    std::wstring data;
    std::getline(input, data, L'\0');
    return data;
}

std::wstring payloadSignature(const std::vector<char> &payload)
{
    std::uint64_t hash = 1469598103934665603ULL;
    for (unsigned char byte : payload) {
        hash ^= byte;
        hash *= 1099511628211ULL;
    }
    return std::to_wstring(payload.size()) + L":" + std::to_wstring(hash);
}

bool fileExists(const std::wstring &path)
{
    const DWORD attributes = GetFileAttributesW(path.c_str());
    return attributes != INVALID_FILE_ATTRIBUTES && !(attributes & FILE_ATTRIBUTE_DIRECTORY);
}

std::wstring payloadPath(const std::wstring &baseDir)
{
    return baseDir + L"\\payload-" + std::to_wstring(GetCurrentProcessId()) + L".zip";
}

HANDLE acquireExtractLock()
{
    const std::wstring name = L"Local\\FloatingCountdownQt" + archSuffix() + L"SfxExtract";
    HANDLE mutex = CreateMutexW(nullptr, FALSE, name.c_str());
    if (!mutex) {
        return nullptr;
    }

    const DWORD result = WaitForSingleObject(mutex, 120000);
    if (result == WAIT_OBJECT_0 || result == WAIT_ABANDONED) {
        return mutex;
    }

    CloseHandle(mutex);
    return nullptr;
}

bool runAndWait(const std::wstring &command)
{
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    startup.dwFlags = STARTF_USESHOWWINDOW;
    startup.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION process{};

    std::wstring mutableCommand = command;
    if (!CreateProcessW(nullptr, mutableCommand.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process)) {
        return false;
    }
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exitCode = 1;
    GetExitCodeProcess(process.hProcess, &exitCode);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return exitCode == 0;
}

bool launchApp(const std::wstring &appPath, const std::wstring &workDir)
{
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION process{};
    std::wstring command = L"\"" + appPath + L"\"";
    if (!CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE, 0, nullptr, workDir.c_str(), &startup, &process)) {
        return false;
    }
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return true;
}
}

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int)
{
    const std::wstring exePath = modulePath();
    std::vector<char> payload;
    if (exePath.empty() || !readPayload(exePath, &payload)) {
        MessageBoxW(nullptr, L"无法读取内置应用包。", L"Floating Countdown", MB_ICONERROR);
        return 1;
    }

    const std::wstring localAppData = knownFolder(CSIDL_LOCAL_APPDATA);
    if (localAppData.empty()) {
        MessageBoxW(nullptr, L"无法定位用户应用目录。", L"Floating Countdown", MB_ICONERROR);
        return 1;
    }

    const std::wstring baseDir = localAppData + L"\\FloatingCountdownQt" + archSuffix();
    const std::wstring appDir = baseDir + L"\\app";
    const std::wstring zipPath = payloadPath(baseDir);
    const std::wstring appPath = appDir + L"\\FloatingCountdown.exe";
    const std::wstring markerPath = baseDir + L"\\payload.version";
    const std::wstring signature = payloadSignature(payload);
    CreateDirectoryW(baseDir.c_str(), nullptr);

    HANDLE extractLock = acquireExtractLock();
    if (!extractLock) {
        MessageBoxW(nullptr, L"等待应用包准备超时。", L"Floating Countdown", MB_ICONERROR);
        return 1;
    }

    if (fileExists(appPath) && readTextFile(markerPath) == signature) {
        CloseHandle(extractLock);
        if (!launchApp(appPath, appDir)) {
            MessageBoxW(nullptr, L"启动 Floating Countdown 失败。", L"Floating Countdown", MB_ICONERROR);
            return 1;
        }
        return 0;
    }

    if (!writeFile(zipPath, payload)) {
        CloseHandle(extractLock);
        MessageBoxW(nullptr, L"无法写入临时应用包。", L"Floating Countdown", MB_ICONERROR);
        return 1;
    }

    const std::wstring ps =
        L"powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
        L"\"Remove-Item -LiteralPath " + quote(appDir) + L" -Recurse -Force -ErrorAction SilentlyContinue; "
        L"New-Item -ItemType Directory -Force -Path " + quote(appDir) + L" | Out-Null; "
        L"Expand-Archive -LiteralPath " + quote(zipPath) + L" -DestinationPath " + quote(appDir) + L" -Force\"";

    if (!runAndWait(ps)) {
        DeleteFileW(zipPath.c_str());
        CloseHandle(extractLock);
        MessageBoxW(nullptr, L"解压应用包失败。", L"Floating Countdown", MB_ICONERROR);
        return 1;
    }

    DeleteFileW(zipPath.c_str());

    if (!writeTextFile(markerPath, signature)) {
        CloseHandle(extractLock);
        MessageBoxW(nullptr, L"无法写入应用版本标记。", L"Floating Countdown", MB_ICONERROR);
        return 1;
    }

    CloseHandle(extractLock);

    if (!launchApp(appPath, appDir)) {
        MessageBoxW(nullptr, L"启动 Floating Countdown 失败。", L"Floating Countdown", MB_ICONERROR);
        return 1;
    }

    return 0;
}
