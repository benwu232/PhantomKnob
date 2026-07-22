#!/bin/bash

# ==============================================================================
# PhantomKnob - 一键构建、Developer ID 签名与 Apple 公证（Notarization）脚本
# ==============================================================================
# 
# 准备工作：
# 1. 确保已在 macOS 系统中安装了完整的 Xcode。
# 2. 拥有一个付费的 Apple 开发者账号，且已在 Mac 机上导入了 "Developer ID Application" 证书。
# 3. 在苹果开发者中心获取您的 Team ID，并在 App Store Connect 或通过 Apple ID 页面
#    生成一个公证专用的“App 专用密码”（App-Specific Password）。
# 4. 根据您的实际账号信息修改下方的变量配置。
#
# ==============================================================================

# 基础配置信息
APP_NAME="PhantomKnob"
BUNDLE_ID="com.phantomknob.PhantomKnob"
PROJECT_DIR="$(pwd)/PhantomKnob"
BUILD_DIR="$(pwd)/build"
DMG_DIR="$(pwd)/dist"

# ============================ 需由用户配置的证书与公证信息 ============================
# 您的 Developer ID Application 证书全名（可在 Keychain 中查看，或运行 `security find-identity -v -p codesigning`）
# 示例: "Developer ID Application: Company Name (A1B2C3D4E5)"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Your Name (TEAM_ID)}"

# 您的 Apple 开发者 Team ID (10位字符，例如: A1B2C3D4E5)
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-YOUR_TEAM_ID}"

# 您的 Apple ID 邮箱账号 (例如: developer@example.com)
APPLE_ID="${APPLE_ID:-YOUR_APPLE_ID_EMAIL}"

# 您的 Apple ID App 专用密码 (注意：不是您的 Apple ID 登录密码，是通过 appleid.apple.com 申请的 App-Specific Password)
# 推荐做法：在环境变量中设置 EXPORT_NOTARY_PASSWORD，或在运行此脚本前配置 keychain profile
# 示例：notarytool --keychain-profile "my-profile"
# 如果使用 App 专用密码，可以直接填写在下方或从外部注入：
APP_SPECIFIC_PASSWORD="${EXPORT_NOTARY_PASSWORD:-YOUR_APP_SPECIFIC_PASSWORD}"
# =====================================================================================

# 使用独立 Xcode 目录
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

set -euo pipefail

# 日志输出函数
log_info() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

# 1. 前置验证
log_info "正在验证构建环境..."
if [ ! -d "/Applications/Xcode.app" ]; then
    log_error "未检测到 /Applications/Xcode.app，此脚本需要完整的 Xcode 才能运行公证和硬化运行时配置。"
    exit 1
fi

# 2. 清理历史构建
log_info "清理旧的构建产物..."
rm -rf "${BUILD_DIR}"
rm -rf "${DMG_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${DMG_DIR}"

# 2.5. 设置 build number 自增
log_info "设置 Build Number..."
BUILD_NUMBER=$(git rev-list --count HEAD)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "${PROJECT_DIR}/Info.plist"
log_info "Build Number 设置为: $BUILD_NUMBER"

IS_ADHOC=false
if [ "${SIGNING_IDENTITY}" = "Developer ID Application: Your Name (TEAM_ID)" ] || [ -z "${SIGNING_IDENTITY}" ]; then
    log_info "⚠️ 未检测到已配置的 Apple 开发者证书，降级为 Ad-hoc (自签名) 模式打包..."
    SIGNING_IDENTITY="-"
    IS_ADHOC=true
fi

# 3. 运行 xcodebuild 进行归档构建 (Archive)
log_info "开始使用 xcodebuild 编译并归档项目 (Release 配置)..."
if [ "${IS_ADHOC}" = "true" ]; then
    xcodebuild archive \
        -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
        -scheme "${APP_NAME}" \
        -configuration Release \
        -archivePath "${BUILD_DIR}/${APP_NAME}.xcarchive" \
        CODE_SIGN_STYLE="Manual" \
        CODE_SIGN_IDENTITY="-" \
        ENABLE_HARDENED_RUNTIME="YES"

    # 4. 导出 App Bundle (Ad-hoc 模式直接提取 xcarchive 中的 App 产物)
    log_info "正在导出 App Bundle (Ad-hoc)..."
    mkdir -p "${BUILD_DIR}/Exported"
    cp -R "${BUILD_DIR}/${APP_NAME}.xcarchive/Products/Applications/${APP_NAME}.app" "${BUILD_DIR}/Exported/"
    log_info "正在对导出的 App 及其内含库进行 Ad-hoc 递归重签名..."
    codesign --force --sign - --deep "${BUILD_DIR}/Exported/${APP_NAME}.app"
else
    xcodebuild archive \
        -project "${PROJECT_DIR}/${APP_NAME}.xcodeproj" \
        -scheme "${APP_NAME}" \
        -configuration Release \
        -archivePath "${BUILD_DIR}/${APP_NAME}.xcarchive" \
        CODE_SIGN_STYLE="Manual" \
        CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
        DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
        ENABLE_HARDENED_RUNTIME="YES" \
        OTHER_CODE_SIGN_FLAGS="--options runtime"

    EXPORT_PLIST="${BUILD_DIR}/exportOptions.plist"
    cat > "${EXPORT_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>${SIGNING_IDENTITY}</string>
    <key>teamID</key>
    <string>${DEVELOPMENT_TEAM}</string>
</dict>
</plist>
EOF

    # 4. 导出 App Bundle
    log_info "正在导出 App Bundle..."
    xcodebuild -exportArchive \
        -archivePath "${BUILD_DIR}/${APP_NAME}.xcarchive" \
        -exportOptionsPlist "${EXPORT_PLIST}" \
        -exportPath "${BUILD_DIR}/Exported"
fi

EXPORTED_APP="${BUILD_DIR}/Exported/${APP_NAME}.app"

if [ ! -d "${EXPORTED_APP}" ]; then
    log_error "App Bundle 导出失败！"
    exit 1
fi

# 5. 校验 App 的 Hardened Runtime 签名
log_info "正在校验导出的 App 代码签名和硬化运行时 (Hardened Runtime) 状态..."
codesign -dvvv "${EXPORTED_APP}" || true
log_info "运行公证要求性自检评估..."
spctl --assess --type execute --verbose "${EXPORTED_APP}" || true

# 6. 打包成品牌化可分发的 DMG 镜像
log_info "正在通过 scripts/package_dmg.sh 创建品牌化 .dmg 磁盘映像文件..."
DMG_PATH="${DMG_DIR}/${APP_NAME}_v1.0.dmg"
bash "$(dirname "$0")/package_dmg.sh" "${EXPORTED_APP}" "${DMG_PATH}"

log_info "品牌化 DMG 构建成功，路径: ${DMG_PATH}"

# 7. 对 DMG 磁盘映像本身进行代码签名
log_info "正在对 DMG 本身进行代码签名..."
codesign --force \
         --sign "${SIGNING_IDENTITY}" \
         "${DMG_PATH}"

log_info "验证已签名的 DMG..."
codesign -dvvv "${DMG_PATH}"

# 8. 提交到 Apple Notarization 服务进行公证
log_info "开始向 Apple 公证服务器提交公证申请 (使用 notarytool)..."

# 检查是否配置了必要的公证信息
if [ "${SIGNING_IDENTITY}" = "Developer ID Application: Your Name (TEAM_ID)" ] || [ "${APPLE_ID}" = "YOUR_APPLE_ID_EMAIL" ]; then
    log_info "⚠️  检测到目前使用的是脚本默认配置模板。公证步骤已自动旁路。"
    log_info "⚠️  请在实际发布前编辑本脚本头部的变量，填入您的真实 Team ID、Apple ID 以及 App 专用密码。"
    log_info "🎉 本地编译、打包及签名逻辑已圆满完成！安装包位于: ${DMG_PATH}"
    exit 0
fi

# 运行公证提交并等待结果（--wait 选项会让命令行阻塞轮询，直到公证通过或拒绝）
if xcrun notarytool submit "${DMG_PATH}" \
    --apple-id "${APPLE_ID}" \
    --password "${APP_SPECIFIC_PASSWORD}" \
    --team-id "${DEVELOPMENT_TEAM}" \
    --wait; then
    
    log_info "🎉 Apple 公证成功通过！"
    
    # 9. 注入（Staple）公证凭证到 DMG 文件中
    log_info "正在向 DMG 磁盘映像植入 (Staple) 公证凭证..."
    xcrun stapler staple "${DMG_PATH}"
    
    log_info "完成公证最终状态验证..."
    spctl --assess --type open --context context:primary-signature --verbose "${DMG_PATH}"
    xcrun stapler validate "${DMG_PATH}"
    
    log_info "🎉 恭喜！已公证且附带凭证的磁盘安装镜像构建成功！"
    log_info "分发路径: ${DMG_PATH}"
else
    log_error "❌ Apple 公证审核失败！请查看公证日志。"
    exit 1
fi
