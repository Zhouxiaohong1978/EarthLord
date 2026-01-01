#!/bin/bash
# 此脚本在每次编译后自动添加 Google Sign-In 所需的 URL Scheme

INFO_PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ ! -f "$INFO_PLIST" ]; then
    echo "Warning: Info.plist not found at $INFO_PLIST"
    exit 0
fi

URL_SCHEME="com.googleusercontent.apps.787278856146-gvlmqojud2qubju02ll0hih93m3c9ek3"

# 添加 URL Scheme（忽略已存在的错误）
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Editor" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $URL_SCHEME" "$INFO_PLIST" 2>/dev/null || true

echo "✅ Google Sign-In URL Scheme configured"
