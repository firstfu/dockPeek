#!/bin/bash
#
#  create_dmg.sh
#  dockPeek
#
#  獨立的 DMG 建立腳本。用於已有建置好的 .app 時，快速產生專業的 DMG 安裝映像檔。
#  會自動從 .app 的 Info.plist 讀取版本號，並建立含有 Applications 捷徑的 DMG。
#
#  使用方式：
#    ./scripts/create_dmg.sh /path/to/dockPeek.app
#    ./scripts/create_dmg.sh build/export/dockPeek.app
#    ./scripts/create_dmg.sh build/export/dockPeek.app --output ~/Desktop
#
#  前置需求：
#    - macOS 系統（需要 hdiutil 與 osascript）
#    - chmod +x scripts/create_dmg.sh
#

set -euo pipefail

# ==============================================================================
# 設定變數
# ==============================================================================

APP_NAME="dockPeek"
VOLUME_NAME="dockPeek"

# 預設輸出目錄
OUTPUT_DIR="build"

# DMG 視窗配置
WINDOW_WIDTH=500
WINDOW_HEIGHT=300
ICON_SIZE=80
APP_ICON_X=120
APP_ICON_Y=160
APPS_ICON_X=380
APPS_ICON_Y=160

# ==============================================================================
# 顏色定義（用於終端輸出）
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ==============================================================================
# 輔助函式
# ==============================================================================

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
    echo -e "${CYAN}── $1${NC}"
}

usage() {
    echo -e "${BOLD}用法：${NC}"
    echo "  $0 <.app 路徑> [選項]"
    echo ""
    echo -e "${BOLD}引數：${NC}"
    echo "  <.app 路徑>               已建置的 .app 套裝軟體路徑"
    echo ""
    echo -e "${BOLD}選項：${NC}"
    echo "  --output <目錄>            DMG 輸出目錄（預設：build/）"
    echo "  --volume-name <名稱>       DMG 磁碟區名稱（預設：dockPeek）"
    echo "  -h, --help                 顯示此說明"
    echo ""
    echo -e "${BOLD}範例：${NC}"
    echo "  $0 build/export/dockPeek.app"
    echo "  $0 /path/to/dockPeek.app --output ~/Desktop"
    echo "  $0 build/export/dockPeek.app --volume-name \"dockPeek Installer\""
}

# 錯誤清理函式
cleanup_on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo ""
        error "DMG 建立失敗（結束碼：${exit_code}）"

        # 卸載可能殘留的 Volume
        if [ -d "/Volumes/${VOLUME_NAME}" ]; then
            warn "正在卸載殘留的磁碟區..."
            hdiutil detach "/Volumes/${VOLUME_NAME}" -force 2>/dev/null || true
        fi

        # 清理暫存 DMG
        if [ -n "${DMG_TEMP:-}" ] && [ -f "${DMG_TEMP}" ]; then
            rm -f "${DMG_TEMP}"
            info "已清理暫存檔案"
        fi
    fi
}

trap cleanup_on_error EXIT

# ==============================================================================
# 解析命令列參數
# ==============================================================================

APP_PATH=""
DMG_TEMP=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --output=*)
            OUTPUT_DIR="${1#*=}"
            shift
            ;;
        --volume-name)
            VOLUME_NAME="$2"
            shift 2
            ;;
        --volume-name=*)
            VOLUME_NAME="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            error "未知選項：$1"
            echo ""
            usage
            exit 1
            ;;
        *)
            if [ -z "${APP_PATH}" ]; then
                APP_PATH="$1"
            else
                error "多餘的引數：$1"
                echo ""
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# ==============================================================================
# 驗證輸入
# ==============================================================================

if [ -z "${APP_PATH}" ]; then
    error "請提供 .app 套裝軟體的路徑"
    echo ""
    usage
    exit 1
fi

# 確保切到專案根目錄（如果是相對路徑的話）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

# 若路徑是相對路徑，轉換為絕對路徑
if [[ "${APP_PATH}" != /* ]]; then
    APP_PATH="${PROJECT_ROOT}/${APP_PATH}"
fi

if [ ! -d "${APP_PATH}" ]; then
    error "找不到 .app 套裝軟體：${APP_PATH}"
    exit 1
fi

if [[ "${APP_PATH}" != *.app ]]; then
    error "指定的路徑不是 .app 套裝軟體：${APP_PATH}"
    exit 1
fi

INFO_PLIST="${APP_PATH}/Contents/Info.plist"
if [ ! -f "${INFO_PLIST}" ]; then
    error "找不到 Info.plist：${INFO_PLIST}"
    error "這可能不是有效的 .app 套裝軟體"
    exit 1
fi

# ==============================================================================
# 讀取版本資訊
# ==============================================================================

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  dockPeek DMG 建立工具${NC}"
echo -e "${CYAN}========================================${NC}"

step "讀取應用程式資訊"

# 從 Info.plist 讀取版本號
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${INFO_PLIST}" 2>/dev/null || echo "")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${INFO_PLIST}" 2>/dev/null || echo "")
ACTUAL_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${INFO_PLIST}" 2>/dev/null || echo "unknown")
ACTUAL_APP_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "${INFO_PLIST}" 2>/dev/null || echo "${APP_NAME}")

if [ -z "${APP_VERSION}" ]; then
    warn "無法從 Info.plist 讀取版本號，使用預設值 1.0.0"
    APP_VERSION="1.0.0"
fi

if [ -z "${BUILD_NUMBER}" ]; then
    BUILD_NUMBER="?"
fi

info "應用程式：${ACTUAL_APP_NAME}"
info "Bundle ID：${ACTUAL_BUNDLE_ID}"
info "版本：${APP_VERSION}（Build ${BUILD_NUMBER}）"
info "來源：${APP_PATH}"

# 計算 .app 大小
APP_SIZE_HUMAN=$(du -sh "${APP_PATH}" | cut -f1)
info "應用程式大小：${APP_SIZE_HUMAN}"

# ==============================================================================
# 準備輸出目錄
# ==============================================================================

step "準備輸出目錄"

# 若輸出目錄是相對路徑，轉換為絕對路徑
if [[ "${OUTPUT_DIR}" != /* ]]; then
    OUTPUT_DIR="${PROJECT_ROOT}/${OUTPUT_DIR}"
fi

mkdir -p "${OUTPUT_DIR}"

# DMG 檔名與路徑
DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
DMG_TEMP="${OUTPUT_DIR}/${APP_NAME}-temp-$$.dmg"
MOUNT_POINT="/Volumes/${VOLUME_NAME}"

# 檢查是否已存在同名 DMG
if [ -f "${DMG_PATH}" ]; then
    warn "已存在同名 DMG：${DMG_PATH}"
    warn "將會覆寫此檔案"
    rm -f "${DMG_PATH}"
fi

# 確保 Volume 未被掛載
if [ -d "${MOUNT_POINT}" ]; then
    warn "偵測到已掛載的 Volume「${VOLUME_NAME}」，正在卸載..."
    hdiutil detach "${MOUNT_POINT}" -force 2>/dev/null || true
    sleep 1
fi

success "輸出目錄已就緒：${OUTPUT_DIR}"

# ==============================================================================
# 建立暫存 DMG（可讀寫格式）
# ==============================================================================

step "建立暫存 DMG"

# 計算所需空間（.app 大小 + 額外 20MB）
APP_SIZE_KB=$(du -sk "${APP_PATH}" | cut -f1)
DMG_SIZE_KB=$((APP_SIZE_KB + 20480))

info "正在建立可讀寫的暫存 DMG（${DMG_SIZE_KB}KB）..."

hdiutil create \
    -srcfolder "${APP_PATH}" \
    -volname "${VOLUME_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${DMG_SIZE_KB}k" \
    "${DMG_TEMP}" \
    > /dev/null

success "暫存 DMG 建立完成"

# ==============================================================================
# 掛載並設定 DMG 內容
# ==============================================================================

step "設定 DMG 內容與版面"

info "正在掛載暫存 DMG..."

MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_TEMP}")
DEVICE_NAME=$(echo "${MOUNT_OUTPUT}" | grep -o '/dev/disk[0-9]*' | head -1)

if [ ! -d "${MOUNT_POINT}" ]; then
    error "掛載 DMG 失敗"
    exit 1
fi

info "已掛載至：${MOUNT_POINT}（裝置：${DEVICE_NAME}）"

# 建立 Applications 符號連結
info "正在建立 /Applications 捷徑..."
ln -sf /Applications "${MOUNT_POINT}/Applications"

# 取得 .app 在磁碟區中的實際檔名
APP_BASENAME=$(basename "${APP_PATH}")

info "正在使用 AppleScript 設定視窗版面..."

# 使用 AppleScript 設定 Finder 視窗外觀
# 配置：圖示檢視、隱藏工具列、自訂視窗大小與圖示位置
WINDOW_LEFT=400
WINDOW_TOP=200
WINDOW_RIGHT=$((WINDOW_LEFT + WINDOW_WIDTH))
WINDOW_BOTTOM=$((WINDOW_TOP + WINDOW_HEIGHT))

osascript << APPLESCRIPT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        -- 設定視窗基本屬性
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false

        -- 設定視窗大小與位置
        set the bounds of container window to {${WINDOW_LEFT}, ${WINDOW_TOP}, ${WINDOW_RIGHT}, ${WINDOW_BOTTOM}}

        -- 設定圖示檢視選項
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to ${ICON_SIZE}

        -- 設定圖示位置：.app 在左側，Applications 在右側
        set position of item "${APP_BASENAME}" of container window to {${APP_ICON_X}, ${APP_ICON_Y}}
        set position of item "Applications" of container window to {${APPS_ICON_X}, ${APPS_ICON_Y}}

        -- 重新整理視窗以套用變更
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# 隱藏不需要的檔案
if [ -f "${MOUNT_POINT}/.DS_Store" ]; then
    info "保留 Finder 版面設定（.DS_Store）"
fi

# 設定磁碟區圖示（使用 .app 的圖示）
# 嘗試複製應用程式圖示作為磁碟區圖示
ICNS_PATH="${APP_PATH}/Contents/Resources/AppIcon.icns"
if [ -f "${ICNS_PATH}" ]; then
    info "正在設定磁碟區圖示..."
    cp "${ICNS_PATH}" "${MOUNT_POINT}/.VolumeIcon.icns"
    SetFile -c icnC "${MOUNT_POINT}/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "${MOUNT_POINT}" 2>/dev/null || true
fi

# 確保所有寫入完成
sync

success "DMG 版面設定完成"

# ==============================================================================
# 卸載並轉換為最終格式
# ==============================================================================

step "轉換為最終 DMG 格式"

info "正在卸載暫存 DMG..."
hdiutil detach "${MOUNT_POINT}" -force > /dev/null
sleep 1

info "正在轉換為壓縮唯讀格式（UDZO, zlib-level=9）..."

hdiutil convert "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_PATH}" \
    > /dev/null

# 清理暫存 DMG
rm -f "${DMG_TEMP}"
DMG_TEMP=""  # 防止 trap 重複清理

if [ ! -f "${DMG_PATH}" ]; then
    error "DMG 轉換失敗"
    exit 1
fi

success "DMG 轉換完成"

# ==============================================================================
# 驗證與輸出結果
# ==============================================================================

step "驗證 DMG"

# 驗證 DMG 完整性
info "正在驗證 DMG 完整性..."
hdiutil verify "${DMG_PATH}" > /dev/null 2>&1
success "DMG 完整性驗證通過"

# 檢查程式碼簽署狀態
info "正在檢查 .app 程式碼簽署狀態..."
TEMP_MOUNT="/Volumes/${VOLUME_NAME}_verify_$$"

# 掛載 DMG 來驗證內容
hdiutil attach "${DMG_PATH}" -mountpoint "${TEMP_MOUNT}" -noverify -noautoopen > /dev/null 2>&1

VERIFIED_APP="${TEMP_MOUNT}/${APP_BASENAME}"
if [ -d "${VERIFIED_APP}" ]; then
    if codesign --verify --deep --strict "${VERIFIED_APP}" 2>/dev/null; then
        success "程式碼簽署驗證通過"
        SIGNING_INFO=$(codesign -dvv "${VERIFIED_APP}" 2>&1 | grep -E "^Authority" | head -1 || echo "無簽署資訊")
        info "簽署者：${SIGNING_INFO}"
    else
        warn "應用程式未簽署或簽署無效（發佈前建議先簽署）"
    fi
fi

hdiutil detach "${TEMP_MOUNT}" -force > /dev/null 2>&1 || true

# 計算 DMG 大小與雜湊值
DMG_SIZE=$(du -h "${DMG_PATH}" | cut -f1)
DMG_SHA256=$(shasum -a 256 "${DMG_PATH}" | cut -d' ' -f1)

# ==============================================================================
# 輸出結果摘要
# ==============================================================================

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  DMG 建立完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  ${BOLD}應用程式${NC}  ${ACTUAL_APP_NAME} v${APP_VERSION}（Build ${BUILD_NUMBER}）"
echo -e "  ${BOLD}DMG 檔案${NC}  ${DMG_PATH}"
echo -e "  ${BOLD}檔案大小${NC}  ${DMG_SIZE}"
echo -e "  ${BOLD}SHA-256 ${NC}  ${DMG_SHA256}"
echo ""
info "如需提交 Apple 公證，請執行："
echo -e "  xcrun notarytool submit \"${DMG_PATH}\" --keychain-profile \"YourProfile\" --wait"
echo -e "  xcrun stapler staple \"${DMG_PATH}\""
echo ""
