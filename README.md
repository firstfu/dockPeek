# dockPeek

macOS 選單列工具，當滑鼠懸停在 Dock 圖示上時，即時顯示該應用程式的視窗縮圖預覽。

## 功能特色

- **視窗縮圖預覽** — 懸停 Dock 圖示即可預覽該 App 所有開啟中的視窗
- **最小化視窗支援** — 最小化的視窗也會顯示在預覽中，並以半透明覆蓋層標示
- **快速切換視窗** — 點擊縮圖即可跳轉至對應視窗
- **關閉視窗 / 結束應用程式** — 直接在預覽面板中關閉單一視窗或結束整個 App
- **選單列常駐** — 以 Menu Bar agent app 運行，不佔用 Dock 空間
- **登入時自動啟動** — 支援 macOS 原生 Launch at Login
- **可調整縮圖大小** — 在設定中自訂縮圖寬度（150–300pt）

## 系統需求

- macOS 26.2 或更新版本
- Xcode 26.2（用於編譯）

## 權限需求

dockPeek 需要以下系統權限才能正常運作：

| 權限 | 用途 |
|------|------|
| **輔助使用（Accessibility）** | 偵測 Dock 上的滑鼠懸停事件、操作視窗 |
| **螢幕錄製（Screen Recording）** | 透過 ScreenCaptureKit 擷取視窗縮圖 |

首次啟動時，App 會引導你前往「系統設定」授予權限。

## 安裝與編譯

```bash
# 複製專案
git clone https://github.com/firstfu/dockPeek.git
cd dockPeek

# 編譯
xcodebuild -project dockPeek.xcodeproj -scheme dockPeek build
```

或在 Xcode 中開啟 `dockPeek.xcodeproj`，選擇 `dockPeek` scheme 後按 `Cmd + R` 執行。

## 使用方式

1. 啟動 dockPeek 後，選單列會出現一個圖示
2. 將滑鼠移至 Dock 上的任意 App 圖示
3. 稍候片刻，該 App 的視窗縮圖預覽面板會自動浮現
4. **點擊縮圖**切換至該視窗；**點擊 ✕** 關閉視窗
5. 滑鼠離開 Dock 區域後，預覽面板自動消失

## 架構概覽

```
dockPeekApp (@main, SwiftUI App)
├── MenuBarExtra          選單列圖示
│   └── MenuBarMenu       啟用開關、設定、結束
├── Settings              設定視窗
└── AppDelegate（核心協調者）
    ├── PermissionManager  輔助使用權限偵測與輪詢
    ├── DockWatcher        滑鼠事件監聽 + AX API 識別 Dock 圖示
    ├── WindowManager      視窗列表查詢 + ScreenCaptureKit 縮圖擷取
    ├── PreviewPanel       浮動 NSPanel，含淡入淡出動畫
    └── SettingsManager    使用者偏好設定（@Observable + UserDefaults）
```

### 資料流程

1. `DockWatcher` 透過全域滑鼠事件偵測游標接近 Dock
2. 經 150ms 防抖後，以 `AXUIElementCopyElementAtPosition` 查詢 Dock 上的 AX 元素
3. 比對 `NSWorkspace.shared.runningApplications` 取得應用程式名稱與 PID
4. `WindowManager.fetchWindows` 以 PID 過濾視窗清單，並透過 `SCScreenshotManager` 擷取縮圖
5. `PreviewPanel` 在 Dock 圖示上方顯示浮動預覽面板

## 測試

```bash
# 執行所有測試（單元測試 + UI 測試）
xcodebuild -project dockPeek.xcodeproj -scheme dockPeek test

# 僅執行單元測試
xcodebuild -project dockPeek.xcodeproj -scheme dockPeek -only-testing:dockPeekTests test
```

- 單元測試使用 **Swift Testing** 框架（`@Test`、`@Suite`）
- 測試以隔離的 `UserDefaults(suiteName:)` 確保互不干擾

## 技術細節

- **語言 / 框架**：Swift、SwiftUI、AppKit、ScreenCaptureKit
- **並行模型**：Swift 6 concurrency，預設 `@MainActor` 隔離
- **App 類型**：Menu Bar agent app（`LSUIElement = YES`）
- **沙盒**：已停用（Accessibility API 與 CGWindowList 需要）
- **Hardened Runtime**：已啟用（公證所需）

## 授權條款

MIT License
