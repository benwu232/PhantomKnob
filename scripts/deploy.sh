#!/bin/bash
set -e

# PhantomKnob One-Click Deploy Script
# Usage: ./scripts/deploy.sh <version>
# Example: ./scripts/deploy.sh v0.9.1

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "[ERROR] Please specify a version tag."
    echo "Usage: ./scripts/deploy.sh v0.9.1"
    exit 1
fi

# Ensure version starts with 'v'
if [[ ! "$VERSION" =~ ^v ]]; then
    VERSION="v${VERSION}"
fi

CURRENT_BRANCH=$(git branch --show-current)

echo "==> [0/3] Generating automated bilingual Changelog for $VERSION..."
python3 scripts/generate_changelog.py "$VERSION"
if [ -n "$(git status --porcelain CHANGELOG.md)" ]; then
    echo "==> Committing updated CHANGELOG.md..."
    git add CHANGELOG.md
    git commit -m "docs: auto-generate changelog for $VERSION"
fi

echo "==> [1/3] Merging changes from branch '$CURRENT_BRANCH' into 'main'..."
git checkout main
git merge "$CURRENT_BRANCH" --no-edit
git push origin main

echo "==> [2/3] Creating tag $VERSION and pushing to GitHub..."
if git rev-parse "$VERSION" &>/dev/null; then
    echo "[INFO] Tag $VERSION already exists locally, deleting and recreating..."
    git tag -d "$VERSION"
    git push origin --delete "$VERSION" 2>/dev/null || true
fi

git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"

echo "==> [3/3] Returning to '$CURRENT_BRANCH' branch..."
git checkout "$CURRENT_BRANCH"

echo ""
echo "🎉 一键部署触发成功！"
echo "GitHub Actions 正在后台自动打包、签署并发布 $VERSION 到 GitHub Releases。"
echo "📦 构建设态监控: https://github.com/benwu232/PhantomKnob/actions"
echo "🔗 发布页面: https://github.com/benwu232/PhantomKnob/releases/tag/$VERSION"
