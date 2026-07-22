#!/bin/bash
# ==============================================================================
# PhantomKnob - 本地一键打包并跨库发布脚本 (备用)
# ==============================================================================
set -euo pipefail

DIST_REPO="benwu232/PhantomKnob"

echo "==> [1/4] 验证发布环境与工具..."
if ! command -v gh &> /dev/null; then
    echo "[ERROR] 未检测到 github-cli (gh)。请先安装 gh (通过 brew install gh)。" >&2
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "[ERROR] gh 未授权登录。请运行 'gh auth login' 登录 GitHub。" >&2
    exit 1
fi

# 检查工作区状态
if [ -n "$(git status --porcelain)" ]; then
    echo "[ERROR] Git 工作区不干净，请先提交或 stash 所有修改再进行发布。" >&2
    exit 1
fi

echo "==> [2/4] 获取版本 Tag..."
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "无")
echo "本地最近的 Tag 版本为: $LATEST_TAG"

# 提取 project.yml 中的 MARKETING_VERSION
PROJ_VERSION=$(sed -n 's/^[[:space:]]*MARKETING_VERSION:[[:space:]]*\([0-9.]*\)/\1/p' PhantomKnob/project.yml | tr -d '[:space:]')
DEFAULT_TAG="v${PROJ_VERSION}"

echo "project.yml 中的 MARKETING_VERSION 为: $PROJ_VERSION"
read -rp "请输入要发布的新版本号 (默认: ${DEFAULT_TAG}，回车直接确认): " TAG_INPUT

if [ -z "$TAG_INPUT" ]; then
    TAG_VERSION="$DEFAULT_TAG"
else
    TAG_VERSION="$TAG_INPUT"
fi

if [[ ! "$TAG_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "[ERROR] 版本号格式必须符合 vX.Y.Z 格式 (当前输入: $TAG_VERSION)" >&2
    exit 1
fi

# 如果用户输入了不同的版本号，则自动更新 project.yml
CLEAN_VERSION="${TAG_VERSION#v}"
if [ "$CLEAN_VERSION" != "$PROJ_VERSION" ]; then
    echo "检测到不同的版本号，正在将 project.yml 中的 MARKETING_VERSION 更新为: $CLEAN_VERSION"
    sed -i '' "s/\(MARKETING_VERSION:[[:space:]]*\)[0-9.]*/\1${CLEAN_VERSION}/" PhantomKnob/project.yml
    
    echo "正在运行 xcodegen 重新生成项目..."
    (cd PhantomKnob && xcodegen)
fi

if git rev-parse "$TAG_VERSION" &>/dev/null; then
    echo "[ERROR] 本地已存在 Tag $TAG_VERSION ！" >&2
    exit 1
fi

echo "==> [3/4] 编译构建 DMG 安装包..."
# 调用 build_notarize.sh 构建。如果未配置真实 Apple 证书，它会自动退化为不公证包。
./scripts/build_notarize.sh

# 寻找到编译生成的 DMG 文件，并重命名为包含版本号的名称
DMG_SOURCE="dist/PhantomKnob_v1.0.dmg"
DMG_TARGET="dist/PhantomKnob_${TAG_VERSION}.dmg"

if [ -f "$DMG_SOURCE" ]; then
    mv "$DMG_SOURCE" "$DMG_TARGET"
else
    # 兼容性备用寻找
    FOUND_DMG=$(find dist -name "*.dmg" -maxdepth 1 | head -n 1)
    if [ -n "$FOUND_DMG" ]; then
        mv "$FOUND_DMG" "$DMG_TARGET"
    else
        echo "[ERROR] 未能在 dist 目录下找到编译生成的 DMG 包！" >&2
        exit 1
    fi
fi

echo "==> [4/4] 触发本地 Tag 并推送至 GitHub Releases..."
# 打本地 Tag 并推送
git tag -a "$TAG_VERSION" -m "Release $TAG_VERSION"
git push origin "$TAG_VERSION"

echo "正在跨仓库创建 Release 并上传 DMG 到目标仓库 $DIST_REPO ..."
gh release create "$TAG_VERSION" "$DMG_TARGET" \
  --repo "$DIST_REPO" \
  --title "Release $TAG_VERSION" \
  --generate-notes

echo "🎉 发布完成！"
echo "Tag $TAG_VERSION 已推送到开发仓库，DMG 产物已发布到 $DIST_REPO"
