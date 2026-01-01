#!/bin/bash
# Google Sign-In URL Scheme 修复脚本
# 每次 clean build 后运行此脚本

echo "🔧 正在添加 Google Sign-In URL Scheme..."

# 查找编译后的 Info.plist
INFO_PLIST=$(find ~/Library/Developer/Xcode/DerivedData/EarthLord-*/Build/Products/Debug-iphonesimulator/EarthLord.app/Info.plist 2>/dev/null | head -1)

if [ -z "$INFO_PLIST" ]; then
    echo "❌ 找不到编译后的应用，请先编译项目"
    exit 1
fi

echo "📁 找到 Info.plist: $INFO_PLIST"

# 删除旧的 URL Types（如果存在）
/usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes" "$INFO_PLIST" 2>/dev/null

# 添加 URL Scheme
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Editor" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string com.googleusercontent.apps.787278856146-gvlmqojud2qubju02ll0hih93m3c9ek3" "$INFO_PLIST"

echo "✅ URL Scheme 已添加"

# 重新安装到模拟器
SIMULATOR_ID="0A376BFC-9FFE-4C4E-8A3C-59E4DBB41D4A"
APP_PATH=$(dirname "$INFO_PLIST")

echo "📱 正在安装到模拟器..."
xcrun simctl install $SIMULATOR_ID "$APP_PATH"

echo "✅ 完成！现在可以测试 Google 登录了"
