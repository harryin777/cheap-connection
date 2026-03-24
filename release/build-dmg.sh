#!/bin/bash

# Cheap Connection DMG 打包脚本
# 使用方法: ./build-dmg.sh

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="cheap-connection"
DMG_NAME="cheap-connection.dmg"
RELEASE_DIR="$PROJECT_DIR/release"

echo "=========================================="
echo "Cheap Connection DMG 打包脚本"
echo "=========================================="

# 检查 create-dmg 是否安装
if ! command -v create-dmg &> /dev/null; then
    echo "❌ create-dmg 未安装"
    echo "请运行: brew install create-dmg"
    exit 1
fi

# 进入项目目录
cd "$PROJECT_DIR"

# 构建 Release 版本
echo ""
echo "📦 构建 Release 版本..."
xcodebuild -scheme cheap-connection \
    -configuration Release \
    -derivedDataPath build \
    clean build \
    ONLY_ACTIVE_ARCH=NO

# 拷贝 .app 到 release 目录
APP_PATH="$RELEASE_DIR/$APP_NAME.app"
echo ""
echo "📋 拷贝应用到 release 目录..."
rm -rf "$APP_PATH"
cp -R "build/Build/Products/Release/$APP_NAME.app" "$RELEASE_DIR/"

# 提取图标
ICNS_PATH="$RELEASE_DIR/AppIcon.icns"
echo ""
echo "🎨 提取应用图标..."
APP_ICON_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"
if [ -f "$APP_ICON_PATH" ]; then
    cp "$APP_ICON_PATH" "$ICNS_PATH"
    echo "✅ 图标已提取: $ICNS_PATH"
else
    echo "⚠️  未找到图标文件，将使用默认图标"
    ICNS_PATH=""
fi

# 删除旧的 DMG
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
rm -f "$DMG_PATH"

# 创建 DMG
echo ""
echo "💿 创建 DMG 安装包..."
if [ -f "$ICNS_PATH" ]; then
    create-dmg \
        --volname "Cheap Connection" \
        --volicon "$ICNS_PATH" \
        --window-pos 200 120 \
        --window-size 660 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 180 170 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 480 170 \
        "$DMG_PATH" \
        "$APP_PATH"
else
    create-dmg \
        --volname "Cheap Connection" \
        --window-pos 200 120 \
        --window-size 660 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 180 170 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 480 170 \
        "$DMG_PATH" \
        "$APP_PATH"
fi

echo ""
echo "=========================================="
echo "✅ 打包完成!"
echo "=========================================="
echo "DMG 位置: $DMG_PATH"
echo ""
echo "文件大小: $(du -h "$DMG_PATH" | cut -f1)"
