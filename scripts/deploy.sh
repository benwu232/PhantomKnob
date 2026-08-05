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

CLEAN_VERSION="${VERSION#v}"
CURRENT_BRANCH=$(git branch --show-current)

# Step 0: Check dirty working tree
if [ -n "$(git status --porcelain | grep -v 'CHANGELOG.md\|appcast.xml')" ]; then
    echo "[ERROR] Git working tree has uncommitted changes. Please commit or stash them first."
    git status --short
    exit 1
fi

echo "==> [1/4] Updating version and build number in project.yml..."
BUILD_NUMBER=$(git rev-list --count HEAD)
sed -i '' "s/\(MARKETING_VERSION:[[:space:]]*\)[0-9.]*/\1${CLEAN_VERSION}/" PhantomKnob/project.yml
sed -i '' "s/\(CURRENT_PROJECT_VERSION:[[:space:]]*\)[0-9]*/\1${BUILD_NUMBER}/" PhantomKnob/project.yml

if command -v xcodegen &>/dev/null; then
    echo "==> Regenerating Xcode project with xcodegen..."
    (cd PhantomKnob && xcodegen)
fi

echo "==> [2/4] Generating automated bilingual Changelog & appcast.xml for $VERSION..."
python3 scripts/generate_changelog.py "$VERSION"

PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")
cat <<EOF > appcast.xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>PhantomKnob Updates</title>
    <link>https://github.com/benwu232/PhantomKnob/releases</link>
    <description>Most recent updates for PhantomKnob.</description>
    <language>en</language>
    <item>
      <title>PhantomKnob ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${CLEAN_VERSION}</sparkle:version>
      <sparkle:shortVersionString>${CLEAN_VERSION}</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>https://github.com/benwu232/PhantomKnob/releases/tag/${VERSION}</sparkle:releaseNotesLink>
      <enclosure url="https://github.com/benwu232/PhantomKnob/releases/download/${VERSION}/PhantomKnob_${VERSION}.dmg"
                 sparkle:version="${CLEAN_VERSION}"
                 sparkle:shortVersionString="${CLEAN_VERSION}"
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

git add PhantomKnob/project.yml CHANGELOG.md appcast.xml
if [ -d "PhantomKnob/PhantomKnob.xcodeproj" ]; then
    git add PhantomKnob/PhantomKnob.xcodeproj
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "==> Committing release updates (Version $CLEAN_VERSION, Build $BUILD_NUMBER)..."
    git commit -m "bump: version to $CLEAN_VERSION ($BUILD_NUMBER)"
fi

echo "==> [3/4] Merging changes from branch '$CURRENT_BRANCH' into 'main'..."
git checkout main
git merge "$CURRENT_BRANCH" --no-edit
git push origin main

echo "==> [4/4] Creating tag $VERSION and pushing to GitHub..."
if git rev-parse "$VERSION" &>/dev/null; then
    echo "[INFO] Tag $VERSION already exists locally, deleting and recreating..."
    git tag -d "$VERSION"
    git push origin --delete "$VERSION" 2>/dev/null || true
fi

git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"

echo "==> Returning to '$CURRENT_BRANCH' branch..."
git checkout "$CURRENT_BRANCH"

echo ""
echo "🎉 一键部署触发成功！"
echo "📦 应用版本: $CLEAN_VERSION (Build $BUILD_NUMBER)"
echo "🚀 GitHub Actions 正在后台自动打包、签署并发布 $VERSION 到 GitHub Releases。"
echo "🔗 构建设态监控: https://github.com/benwu232/PhantomKnob/actions"
echo "🔗 发布页面: https://github.com/benwu232/PhantomKnob/releases/tag/$VERSION"
