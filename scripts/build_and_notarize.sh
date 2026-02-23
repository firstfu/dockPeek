#!/bin/bash
#
#  build_and_notarize.sh
#  dockPeek
#
#  完整的 macOS 應用程式建置、簽署、公證與 DMG 打包腳本。
#  此腳本會依序執行：Archive → Export → 建立 DMG → 提交公證 → 釘選公證票據。
#
#  使用方式：
#    # 使用環境變數提供 Apple ID 憑證
#    export APPLE_ID="your@email.com"
#    export APPLE_TEAM_ID="WY468E45SJ"
#    export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
#    ./scripts/build_and_notarize.sh
#
#    # 或使用已儲存的 Keychain Profile
#    ./scripts/build_and_notarize.sh --keychain-profile "YourProfileName"
#
#  前置需求：
#    - Xcode 命令列工具已安裝
#    - 已設定有效的 Developer ID Application 憑證
#    - chmod +x scripts/build_and_notarize.sh
#

set -euo pipefail

# ==============================================================================
# 設定變數
# ==============================================================================

APP_NAME="dockPeek"
SCHEME="dockPeek"
PROJECT="dockPeek.xcodeproj"
BUNDLE_ID="com.firstfu.dockPeek"
TEAM_ID="WY468E45SJ"

# 建置輸出目錄
BUILD_DIR="build"
ARCHIVE_DIR="${BUILD_DIR}/archive"
EXPORT_DIR="${BUILD_DIR}/export"
ARCHIVE_PATH="${ARCHIVE_DIR}/${APP_NAME}.xcarchive"
EXPORT_OPTIONS_PLIST="${BUILD_DIR}/ExportOptions.plist"

# Keychain Profile（可透過命令列參數覆寫）
KEYCHAIN_PROFILE=""

# ==============================================================================
# 顏色定義（用於終端輸出）
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==============================================================================
# 輔助函式
# ==============================================================================

# 輸出帶顏色的狀態訊息
info() {
    echo -e "${BLUE}[資訊]${NC} $1"
}

success() {
    echo -e "${GREEN}[完成]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

error() {
    echo -e "${RED}[錯誤]${NC} $1" >&2
}

step() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# 錯誤清理函式（trap 觸發）
cleanup_on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo ""
        error "腳本執行失敗（結束碼：${exit_code}）"
        error "正在清理中間檔案..."

        # 移除可能不完整的產出物
        [ -d "${ARCHIVE_PATH}" ] && rm -rf "${ARCHIVE_PATH}" && info "已移除不完整的 archive"
        [ -f "${EXPORT_OPTIONS_PLIST}" ] && rm -f "${EXPORT_OPTIONS_PLIST}" && info "已移除 ExportOptions.plist"

        # 如果匯出目錄中有不完整的 .app，也一併清除
        if [ -d "${EXPORT_DIR}/${APP_NAME}.app" ]; then
            rm -rf "${EXPORT_DIR}/${APP_NAME}.app"
            info "已移除不完整的匯出 .app"
        fi

        # 移除可能不完整的 DMG
        local dmg_pattern="${BUILD_DIR}/${APP_NAME}-*.dmg"
        for f in $dmg_pattern; do
            if [ -f "$f" ]; then
                rm -f "$f"
                info "已移除不完整的 DMG：$(basename "$f")"
            fi
        done

        echo ""
        error "建置流程中止。請修正上述問題後重試。"
    fi
}

trap cleanup_on_error EXIT

# ==============================================================================
# 解析命令列參數
# ==============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keychain-profile)
            KEYCHAIN_PROFILE="$2"
            shift 2
            ;;
        --keychain-profile=*)
            KEYCHAIN_PROFILE="${1#*=}"
            shift
            ;;
        -h|--help)
            echo "用法：$0 [選項]"
            echo ""
            echo "選項："
            echo "  --keychain-profile <名稱>   使用已儲存的 notarytool Keychain Profile"
            echo "  -h, --help                  顯示此說明"
            echo ""
            echo "環境變數（未使用 --keychain-profile 時必須設定）："
            echo "  APPLE_ID                    Apple ID 電子郵件"
            echo "  APPLE_TEAM_ID               Apple Developer Team ID"
            echo "  APPLE_APP_SPECIFIC_PASSWORD  App 專用密碼"
            echo ""
            echo "儲存 Keychain Profile："
            echo "  xcrun notarytool store-credentials \"ProfileName\" \\"
            echo "    --apple-id \"your@email.com\" \\"
            echo "    --team-id \"WY468E45SJ\" \\"
            echo "    --password \"xxxx-xxxx-xxxx-xxxx\""
            exit 0
            ;;
        *)
            error "未知選項：$1"
            echo "使用 -h 或 --help 查看說明"
            exit 1
            ;;
    esac
done

# ==============================================================================
# 驗證憑證設定
# ==============================================================================

step "驗證環境與憑證"

if [ -n "${KEYCHAIN_PROFILE}" ]; then
    info "將使用 Keychain Profile：${KEYCHAIN_PROFILE}"
else
    # 檢查環境變數
    if [ -z "${APPLE_ID:-}" ]; then
        error "缺少 APPLE_ID 環境變數。請設定或使用 --keychain-profile。"
        exit 1
    fi
    if [ -z "${APPLE_TEAM_ID:-}" ]; then
        error "缺少 APPLE_TEAM_ID 環境變數。請設定或使用 --keychain-profile。"
        exit 1
    fi
    if [ -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]; then
        error "缺少 APPLE_APP_SPECIFIC_PASSWORD 環境變數。請設定或使用 --keychain-profile。"
        exit 1
    fi
    info "將使用環境變數中的 Apple ID 憑證（${APPLE_ID}）"
fi

# 確認 Xcode 命令列工具可用
if ! command -v xcodebuild &> /dev/null; then
    error "找不到 xcodebuild。請安裝 Xcode 命令列工具。"
    exit 1
fi

# 確認專案檔存在
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

if [ ! -d "${PROJECT}" ]; then
    error "找不到專案檔：${PROJECT}（目前目錄：$(pwd)）"
    exit 1
fi

success "環境驗證完成"

# ==============================================================================
# 步驟 1：準備建置目錄
# ==============================================================================

step "步驟 1/6：準備建置目錄"

# 清理舊的建置產出物
if [ -d "${ARCHIVE_PATH}" ]; then
    warn "移除舊的 archive..."
    rm -rf "${ARCHIVE_PATH}"
fi

if [ -d "${EXPORT_DIR}" ]; then
    warn "移除舊的匯出目錄..."
    rm -rf "${EXPORT_DIR}"
fi

# 建立所需目錄
mkdir -p "${ARCHIVE_DIR}"
mkdir -p "${EXPORT_DIR}"
mkdir -p "${BUILD_DIR}"

success "建置目錄已就緒"

# ==============================================================================
# 步驟 2：Archive 建置
# ==============================================================================

step "步驟 2/6：Archive 建置"

info "正在以 Release 組態建置 ${APP_NAME}..."

xcodebuild archive \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=macOS" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    CODE_SIGN_STYLE="Manual" \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    | tail -n 5

if [ ! -d "${ARCHIVE_PATH}" ]; then
    error "Archive 建置失敗：找不到 ${ARCHIVE_PATH}"
    exit 1
fi

success "Archive 建置完成：${ARCHIVE_PATH}"

# ==============================================================================
# 步驟 3：匯出已簽署的 .app
# ==============================================================================

step "步驟 3/6：匯出已簽署的 .app"

# 程式化產生 ExportOptions.plist
info "正在產生 ExportOptions.plist..."

cat > "${EXPORT_OPTIONS_PLIST}" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>${BUNDLE_ID}</key>
        <string></string>
    </dict>
</dict>
</plist>
PLIST

info "正在匯出 .app..."

xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_DIR}" \
    -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
    | tail -n 5

APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    error "匯出失敗：找不到 ${APP_PATH}"
    exit 1
fi

# 讀取版本號
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || echo "1.0.0")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${APP_PATH}/Contents/Info.plist" 2>/dev/null || echo "1")

info "應用程式版本：${APP_VERSION}（Build ${BUILD_NUMBER}）"

# 驗證程式碼簽署
info "正在驗證程式碼簽署..."
codesign --verify --deep --strict "${APP_PATH}"
success "程式碼簽署驗證通過"

# 顯示簽署詳情
codesign -dvv "${APP_PATH}" 2>&1 | grep -E "^(Authority|TeamIdentifier|Identifier)" || true

success "匯出完成：${APP_PATH}"

# ==============================================================================
# 步驟 4：建立 DMG
# ==============================================================================

step "步驟 4/6：建立 DMG 安裝映像檔"

DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
DMG_TEMP="${BUILD_DIR}/${APP_NAME}-temp.dmg"
VOLUME_NAME="${APP_NAME}"
MOUNT_POINT="/Volumes/${VOLUME_NAME}"

# 清理舊的 DMG
[ -f "${DMG_PATH}" ] && rm -f "${DMG_PATH}"
[ -f "${DMG_TEMP}" ] && rm -f "${DMG_TEMP}"

# 確保 Volume 未被掛載
if [ -d "${MOUNT_POINT}" ]; then
    warn "偵測到已掛載的 Volume，正在卸載..."
    hdiutil detach "${MOUNT_POINT}" -force 2>/dev/null || true
fi

info "正在建立暫存 DMG..."

# 計算所需大小（.app 大小 + 額外空間）
APP_SIZE_KB=$(du -sk "${APP_PATH}" | cut -f1)
DMG_SIZE_KB=$((APP_SIZE_KB + 20480))  # 額外 20MB 供版面配置使用

# 建立可讀寫的暫存 DMG
hdiutil create \
    -srcfolder "${APP_PATH}" \
    -volname "${VOLUME_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${DMG_SIZE_KB}k" \
    "${DMG_TEMP}" \
    > /dev/null

info "正在掛載暫存 DMG..."

# 掛載暫存 DMG
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP}")
DEVICE_NAME=$(echo "${MOUNT_OUTPUT}" | grep -o '/dev/disk[0-9]*' | head -1)

if [ ! -d "${MOUNT_POINT}" ]; then
    error "掛載 DMG 失敗"
    exit 1
fi

info "正在建立 Applications 捷徑..."

# 建立 /Applications 符號連結
ln -sf /Applications "${MOUNT_POINT}/Applications"

info "正在設定 DMG 視窗版面..."

# 使用 AppleScript 設定 DMG 視窗外觀
# 應用程式圖示在左側，Applications 捷徑在右側
osascript << APPLESCRIPT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 200, 900, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set position of item "${APP_NAME}.app" of container window to {120, 160}
        set position of item "Applications" of container window to {380, 160}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# 確保所有寫入完成
sync

info "正在卸載暫存 DMG..."
hdiutil detach "${MOUNT_POINT}" -force > /dev/null

info "正在轉換為壓縮唯讀 DMG..."

# 轉換為壓縮的唯讀格式
hdiutil convert "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_PATH}" \
    > /dev/null

# 清理暫存檔
rm -f "${DMG_TEMP}"

if [ ! -f "${DMG_PATH}" ]; then
    error "DMG 建立失敗"
    exit 1
fi

DMG_SIZE=$(du -h "${DMG_PATH}" | cut -f1)
success "DMG 建立完成：${DMG_PATH}（${DMG_SIZE}）"

# ==============================================================================
# 步驟 5：提交公證
# ==============================================================================

step "步驟 5/6：提交 Apple 公證"

info "正在將 DMG 提交至 Apple 進行公證..."
info "這可能需要數分鐘，請耐心等候..."

NOTARIZE_OUTPUT=""

if [ -n "${KEYCHAIN_PROFILE}" ]; then
    # 使用 Keychain Profile
    NOTARIZE_OUTPUT=$(xcrun notarytool submit "${DMG_PATH}" \
        --keychain-profile "${KEYCHAIN_PROFILE}" \
        --wait \
        2>&1)
else
    # 使用環境變數中的憑證
    NOTARIZE_OUTPUT=$(xcrun notarytool submit "${DMG_PATH}" \
        --apple-id "${APPLE_ID}" \
        --team-id "${APPLE_TEAM_ID}" \
        --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
        --wait \
        2>&1)
fi

echo "${NOTARIZE_OUTPUT}"

# 檢查公證結果
if echo "${NOTARIZE_OUTPUT}" | grep -q "status: Accepted"; then
    success "Apple 公證通過！"
elif echo "${NOTARIZE_OUTPUT}" | grep -q "status: Invalid"; then
    error "公證被拒絕。請查看上方的詳細資訊。"

    # 嘗試取得公證紀錄
    SUBMISSION_ID=$(echo "${NOTARIZE_OUTPUT}" | grep -o 'id: [a-f0-9-]*' | head -1 | cut -d' ' -f2)
    if [ -n "${SUBMISSION_ID}" ]; then
        info "正在取得公證紀錄..."
        if [ -n "${KEYCHAIN_PROFILE}" ]; then
            xcrun notarytool log "${SUBMISSION_ID}" \
                --keychain-profile "${KEYCHAIN_PROFILE}" 2>&1 || true
        else
            xcrun notarytool log "${SUBMISSION_ID}" \
                --apple-id "${APPLE_ID}" \
                --team-id "${APPLE_TEAM_ID}" \
                --password "${APPLE_APP_SPECIFIC_PASSWORD}" 2>&1 || true
        fi
    fi
    exit 1
else
    error "公證結果不明確。請手動檢查狀態。"
    exit 1
fi

# ==============================================================================
# 步驟 6：釘選公證票據
# ==============================================================================

step "步驟 6/6：釘選公證票據至 DMG"

info "正在釘選公證票據..."

xcrun stapler staple "${DMG_PATH}"

# 驗證釘選結果
info "正在驗證釘選結果..."
xcrun stapler validate "${DMG_PATH}"

success "公證票據已成功釘選至 DMG"

# ==============================================================================
# 完成
# ==============================================================================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  建置與公證流程全部完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
info "應用程式：${APP_NAME} v${APP_VERSION}（Build ${BUILD_NUMBER}）"
info "DMG 檔案：${DMG_PATH}"
info "DMG 大小：${DMG_SIZE}"
echo ""
info "此 DMG 已經過 Apple 公證，可安全發佈給使用者。"
echo ""
