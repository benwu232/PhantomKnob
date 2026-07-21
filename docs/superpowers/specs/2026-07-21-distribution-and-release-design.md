# PhantomKnob 分发与发布设计规格说明书

本文档规定了公共分发仓库（`PhantomKnob`）的结构设计，以及在开发仓库（`phantom_knob_mac`）中配置自动化发布（CI/CD）和本地一键发布（备用）流程的实现计划。

## 目标

为 PhantomKnob 建立一个专业的、面向用户的公共分发仓库，作为用户下载官方安装包的枢纽。同时，打通开发库与分发库之间的发布自动化链路，并配备本地一键打包发布脚本作为备份。

---

## 1. 分发仓库结构设计 (`PhantomKnob`)

公共分发仓库 [PhantomKnob](file:///Users/wb/work/PhantomKnob) 将作为面向用户的纯洁净界面，仅存放分发和宣传相关文件，开发源码保留在 `phantom_knob_mac` 中。

### 1.1 文档结构
*   **[NEW] `README.md`（默认英文版）：** 产品概述、带图标的核心功能介绍、安装指引、演示 GIF 占位符、用户指南以及常见问题解答（FAQ）。
*   **[NEW] `README_zh.md`（中文版）：** 上述内容的本地化中文版本，在默认英文 `README.md` 的顶部提供醒目的切换链接。

### 1.2 README 排版规范
*   **头部展示 (Header)：** 居中展示应用 Logo、应用名称以及 Slogan。
*   **下载徽章 (Download Badge)：** 一个大而显眼的下载按钮，链接始终指向 GitHub Releases 中的最新稳定版 DMG：
    ```markdown
    [![Download DMG](https://img.shields.io/badge/Download-macOS%20DMG-blue?logo=apple&style=for-the-badge)](https://github.com/benwu232/PhantomKnob/releases/latest/download/PhantomKnob.dmg)
    ```
*   **直观演示 (Visual Guide)：** 放置一段 10-15 秒的 Gif 动图，展示用户双指在触控板上旋转调节系统音量或进度条的流畅画面。
*   **核心特性 (Key Features)：** 使用 Emoji 列表展示手势分类器、全局辅助功能控制以及不同 App 的预设规则。
*   **安装与权限说明 (Permissions Guide)：** 重点说明并引导用户如何授予**辅助功能权限 (Accessibility Permissions)**，因为模拟系统控制必须依赖该权限。

---

## 2. GitHub Actions CI/CD 发布工作流

我们将在开发仓库 [phantom_knob_mac](file:///Users/wb/work/phantom_knob_mac) 中建立 GitHub Actions 工作流，以便在打 Tag 时自动编译 App 并发布到公共的 `PhantomKnob` 仓库中。

### 2.1 工作流文件：[NEW] `.github/workflows/release.yml`
*   **触发条件 (Trigger)：** 当向开发仓库推送以 `v` 开头的 Tag 时触发（例如 `git push origin v1.0.0`）。
*   **运行环境 (Runner)：** `macos-latest`。
*   **权限凭证 (Authentication)：** 需要一个拥有 `PhantomKnob` 仓库写入权限的 GitHub 个人访问令牌 (PAT)，在开发仓库的 Secrets 中配置为 `RELEASE_TOKEN`。

### 2.2 编译与代码签名逻辑 (编译弹性设计)
工作流将按以下步骤执行：
1.  **检出代码 (Checkout)：** 获取源码与脚本。
2.  **判断代码签名选项：**
    *   *若 Secrets 中配置了苹果证书：* 自动在虚拟 Mac 中导入 p12 证书，配置临时 Keychain，然后调用 [build_notarize.sh](file:///Users/wb/work/phantom_knob_mac/scripts/build_notarize.sh) 进行完整的签名与公证。
    *   *若缺少证书配置（降级）：* 自动退化为使用 Ad-hoc 签名 (`CODE_SIGN_IDENTITY="-"`)，并直接调用 [package_dmg.sh](file:///Users/wb/work/phantom_knob_mac/scripts/package_dmg.sh) 打包，跳过 Notarization 步骤。
3.  **上传发布 (Publishing)：** 使用 `softprops/action-gh-release` 动作，传入 `RELEASE_TOKEN`，将编译生成的 DMG 文件跨库推送到 `benwu232/PhantomKnob` 仓库的 Release 中。

---

## 3. 本地一键发布脚本 (备用)

为确保发布链路稳健，我们将在开发仓库的 `scripts` 目录中建立本地交互式发布脚本。

### 3.1 脚本流程与要求 (`scripts/local_release.sh`)
*   **前置状态检查：**
    *   验证本地是否安装了 GitHub CLI (`gh`) 且已登录授权（通过 `gh auth status` 验证）。
    *   验证当前 Git 工作区是否干净（无未提交的修改）。
*   **交互式输入：**
    *   提示用户确认并输入要发布的版本 Tag（例如 `v1.0.0`）。
*   **构建与执行：**
    *   执行打包脚本，生成 `.dmg` 格式安装包。
*   **跨库发布：**
    *   自动在本地打上 Git Tag 并推送到 `origin`。
    *   调用 `gh release create` 指令直接向分发库发布 Release：
        ```bash
        gh release create "$TAG" dist/PhantomKnob_v*.dmg --repo benwu232/PhantomKnob --title "Release $TAG" --generate-notes
        ```

---

## 验证计划

### 1. CI/CD 工作流验证
1. 向 `phantom_knob_mac` 推送一个测试 Tag（如 `v0.9.0-test`）。
2. 在 GitHub Actions 页面检查构建日志，验证编译、打包和 Ad-hoc 签名退化逻辑是否成功执行。
3. 验证 `benwu232/PhantomKnob` 仓库中是否成功生成了 Release，且其中包含可下载的 DMG 安装包。
4. 验证完成后，在 GitHub 上手动删除此测试 Release 和 Tag。

### 2. 本地发布脚本验证
1. 在本地运行 `./scripts/local_release.sh`。
2. 验证脚本能否正确识别工作区脏状态或未授权的 `gh` CLI，并进行安全退出提示。
