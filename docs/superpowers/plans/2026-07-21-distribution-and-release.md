# PhantomKnob 分发与发布流程实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在分发仓库中配置精美、支持中英文的多语言 README，并在开发仓库中配置 GitHub Actions 跨仓库自动发布和本地一键发布（备用）流程。

**架构：**
1. 采用类似 `opencode` 页面版式，使用 `<picture>` 自适应深色/浅色 Logo 样式，提供中英文 README 文件；
2. 编写开发库中的 GitHub Actions 工作流，触发 Tag 推送时，在 `macos-latest` 上提取版本构建，支持有证书时的完整发布，无证书时自动降级 Ad-hoc 打包，并通过 PAT 将产物发布到外部的分发仓库；
3. 编写 `scripts/local_release.sh`，封装本地验证、打 Tag 和 GitHub CLI 跨库发布流程。

**技术栈：** Shell, GitHub Actions, GitHub CLI, Xcode Command Line Tools.

---

### 任务 1：设计分发仓库 README (中英文版)

*   [ ] **步骤 1.1：创建并编辑英文 [README.md](file:///Users/wb/work/PhantomKnob/README.md)**
    写入以下内容：
    ```markdown
    <p align="center">
      <a href="https://github.com/benwu232/PhantomKnob">
        <picture>
          <img src="https://raw.githubusercontent.com/benwu232/PhantomKnob/master/README_assets/logo.png" alt="PhantomKnob Logo" width="128">
        </picture>
      </a>
    </p>
    <p align="center"><b>PhantomKnob</b> - Smooth physical-dial simulation using trackpad rotation gestures on macOS.</p>
    
    <p align="center">
      <a href="README.md">English</a> |
      <a href="README_zh.md">简体中文</a>
    </p>
    
    <p align="center">
      <a href="https://github.com/benwu232/PhantomKnob/releases/latest/download/PhantomKnob.dmg">
        <img alt="Download DMG" src="https://img.shields.io/badge/Download-macOS%20DMG-blue?logo=apple&style=for-the-badge" />
      </a>
    </p>
    
    <p align="center">
      <!-- A placeholder for demonstration GIF -->
      <i>[Demo GIF showing trackpad knob gestures in action will be loaded here]</i>
    </p>
    
    ---
    
    ### Key Features
    *   🎛️ **Physical Knob Simulation:** Uses absolute 2-finger touch locations on trackpads to detect rotational gestures.
    *   🌍 **Global Accessibility Control:** Hotkey-triggered overlay helps you control sliders (Volume, Brightness, scrollbars) anywhere under your mouse cursor.
    *   ⚡ **Intelligent Detection Mode:** Active vibration feedback and smart detection sequence ensure hardware compatibility.
    
    ### Installation
    1.  **Download** the latest `.dmg` install package from the button above.
    2.  **Drag and drop** `PhantomKnob.app` to your `/Applications` folder.
    3.  **Launch** it and grant **Accessibility Permissions** (辅助功能权限) in System Settings when prompted.
    
    ### License
    This software is released under the MIT License.
    ```

*   [ ] **步骤 1.2：创建并编辑中文 [README_zh.md](file:///Users/wb/work/PhantomKnob/README_zh.md)**
    写入对应的中文内容。

*   [ ] **步骤 1.3：Commit 提交分发库的修改**
    ```bash
    git -C /Users/wb/work/PhantomKnob add README.md README_zh.md
    git -C /Users/wb/work/PhantomKnob commit -m "docs: initialize user-facing README files"
    ```

---

### 任务 2：创建 GitHub Actions 发布工作流

*   [ ] **步骤 2.1：在开发库中创建 [.github/workflows/release.yml](file:///Users/wb/work/phantom_knob_mac/.github/workflows/release.yml)**
    代码内容：
    ```yaml
    name: Build & Auto Release

    on:
      push:
        tags:
          - 'v*'

    jobs:
      build-and-release:
        name: Build and Release App
        runs-on: macos-latest
        steps:
          - name: Checkout Code
            uses: actions/checkout@v3

          - name: Set up Xcode
            run: sudo xcode-select -s /Applications/Xcode.app

          - name: Determine Code Signing
            id: sign_step
            run: |
              if [ -n "${{ secrets.APPLE_CERTIFICATE_P12 }}" ]; then
                echo "has_cert=true" >> $GITHUB_OUTPUT
              else
                echo "has_cert=false" >> $GITHUB_OUTPUT
              fi

          - name: Build App (Fallback Ad-hoc or Notarized)
            env:
              APPLE_CERT: ${{ secrets.APPLE_CERTIFICATE_P12 }}
              APPLE_CERT_PASS: ${{ secrets.APPLE_CERTIFICATE_PASS }}
              APPLE_ID: ${{ secrets.APPLE_ID }}
              APPLE_ID_PASS: ${{ secrets.APPLE_ID_PASSWORD }}
              APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
            run: |
              if [ "${{ steps.sign_step.outputs.has_cert }}" = "true" ]; then
                KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
                KEYCHAIN_PASSWORD=$(openssl rand -base64 12)
                security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
                security default-keychain -s "$KEYCHAIN_PATH"
                security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
                
                echo "$APPLE_CERT" | base64 --decode > $RUNNER_TEMP/cert.p12
                security import $RUNNER_TEMP/cert.p12 -k "$KEYCHAIN_PATH" -P "$APPLE_CERT_PASS" -T /usr/bin/codesign -T /usr/bin/xcodebuild
                security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
                
                export EXPORT_NOTARY_PASSWORD="$APPLE_ID_PASS"
                export SIGNING_IDENTITY="Developer ID Application: Your Name ($APPLE_TEAM_ID)"
                export DEVELOPMENT_TEAM="$APPLE_TEAM_ID"
                export APPLE_ID="$APPLE_ID"
                ./scripts/build_notarize.sh
              else
                echo "[INFO] No signing certificates found in Secrets. Building with Ad-hoc signing."
                BUILD_NUMBER=$(git rev-list --count HEAD)
                /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "PhantomKnob/Info.plist"
                
                xcodebuild archive \
                  -project PhantomKnob/PhantomKnob.xcodeproj \
                  -scheme PhantomKnob \
                  -configuration Release \
                  -archivePath build/PhantomKnob.xcarchive \
                  CODE_SIGN_STYLE="Manual" \
                  CODE_SIGN_IDENTITY="-" \
                  ENABLE_HARDENED_RUNTIME="YES"
                
                xcodebuild -exportArchive \
                  -archivePath build/PhantomKnob.xcarchive \
                  -exportOptionsPlist <(cat <<EOF
                {
                    "method": "developer-id",
                    "signingStyle": "manual",
                    "signingCertificate": "-",
                    "compileBitcode": false
                }
                EOF
                ) \
                  -exportPath build/Exported
                
                mkdir -p dist
                bash ./scripts/package_dmg.sh build/Exported/PhantomKnob.app dist/PhantomKnob.dmg
                TAG_NAME=${GITHUB_REF_NAME}
                mv dist/PhantomKnob.dmg dist/PhantomKnob_${TAG_NAME}.dmg
              fi

          - name: Push Release to Distribution Repo
            uses: softprops/action-gh-release@v1
            with:
              repository: benwu232/PhantomKnob
              token: ${{ secrets.RELEASE_TOKEN }}
              files: dist/*.dmg
              generate_release_notes: true
    ```

*   [ ] **步骤 2.2：提交 Workflows 并推送到源仓库**
    ```bash
    git add .github/workflows/release.yml
    git commit -m "ci: add GitHub Actions release workflow"
    ```

---

### 任务 3：创建本地一键发布脚本

*   [ ] **步骤 3.1：在开发库中创建 [scripts/local_release.sh](file:///Users/wb/work/phantom_knob_mac/scripts/local_release.sh)**
    代码内容：
    ```bash
    #!/bin/bash
    set -euo pipefail

    DIST_REPO="benwu232/PhantomKnob"

    echo "==> [1/4] 验证发布环境与工具..."
    if ! command -v gh &> /dev/null; then
        echo "[ERROR] 未检测到 github-cli (gh)。请先安装 gh (brew install gh)。" >&2
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        echo "[ERROR] gh 未授权登录。请运行 'gh auth login'。" >&2
        exit 1
    fi

    if [ -n "$(git status --porcelain)" ]; then
        echo "[ERROR] Git 工作区不干净，请先提交或 stash 所有修改。" >&2
        exit 1
    fi

    echo "==> [2/4] 获取版本 Tag..."
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "无")
    echo "最近的 Tag 版本为: $LATEST_TAG"
    read -rp "请输入要发布的新版本号 (例如 v1.0.0): " TAG_VERSION

    if [[ ! "$TAG_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        echo "[ERROR] 版本号格式必须符合 vX.Y.Z 格式" >&2
        exit 1
    fi

    if git rev-parse "$TAG_VERSION" &>/dev/null; then
        echo "[ERROR] Tag $TAG_VERSION 已存在！" >&2
        exit 1
    fi

    echo "==> [3/4] 编译构建 DMG 安装包..."
    ./scripts/build_notarize.sh

    DMG_SOURCE="dist/PhantomKnob_v1.0.dmg"
    DMG_TARGET="dist/PhantomKnob_${TAG_VERSION}.dmg"

    if [ -f "$DMG_SOURCE" ]; then
        mv "$DMG_SOURCE" "$DMG_TARGET"
    else
        FOUND_DMG=$(find dist -name "*.dmg" -maxdepth 1 | head -n 1)
        if [ -n "$FOUND_DMG" ]; then
            mv "$FOUND_DMG" "$DMG_TARGET"
        else
            echo "[ERROR] 未能在 dist 目录下找到编译生成的 DMG 包！" >&2
            exit 1
        fi
    fi

    echo "==> [4/4] 触发本地 Tag 并推送至 GitHub Releases..."
    git tag -a "$TAG_VERSION" -m "Release $TAG_VERSION"
    git push origin "$TAG_VERSION"

    echo "正在跨仓库创建 Release 并上传 DMG 到 $DIST_REPO ..."
    gh release create "$TAG_VERSION" "$DMG_TARGET" \
      --repo "$DIST_REPO" \
      --title "Release $TAG_VERSION" \
      --generate-notes

    echo "🎉 发布成功！已推送 Tag $TAG_VERSION 并发布到 $DIST_REPO"
    ```

*   [ ] **步骤 3.2：赋予执行权限并提交**
    ```bash
    chmod +x scripts/local_release.sh
    git add scripts/local_release.sh
    git commit -m "feat: add local release runner script"
    ```

---

## 验证计划

### 1. 本地发布环境校验
*   执行 `scripts/local_release.sh`，在提示输入版本时，输入 `Ctrl+C` 退出，观察其前置校验（Git 工作区检查、`gh` 登录验证）是否生效。

### 2. CI/CD 测试发布
*   在本地推一个带后缀的测试 Tag（例如 `git tag v0.0.0-test && git push origin v0.0.0-test`）。
*   在 GitHub Actions 上查看工作流运行状态，确认其能否自动降级打包并发布至 `PhantomKnob`。
*   删除测试 Release 和 Tag：
    ```bash
    git tag -d v0.0.0-test
    git push origin --delete v0.0.0-test
    ```
