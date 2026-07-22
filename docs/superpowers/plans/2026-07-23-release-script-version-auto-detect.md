# 自动检测 project.yml 中的 MARKETING_VERSION 以供本地发布确认 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修改 `scripts/local_release.sh` 脚本，使其在执行时能够自动提取 `PhantomKnob/project.yml` 里的 `MARKETING_VERSION` 并在用户交互时默认使用该版本进行发布。

**架构：**
- 使用 `sed` 语句安全解析 `PhantomKnob/project.yml`。
- 修改提示与默认输入机制，支持回车确认默认版本号。

---

### 任务 1：修改 `local_release.sh` 并验证

**文件：**
- 修改：`scripts/local_release.sh`

- [ ] **步骤 1：修改 local_release.sh 的版本读取和交互逻辑**

在 `scripts/local_release.sh` 中修改获取版本 Tag 的逻辑：
```diff
-echo "==> [2/4] 获取版本 Tag..."
-LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "无")
-echo "本地最近的 Tag 版本为: $LATEST_TAG"
-read -rp "请输入要发布的新版本号 (格式如 v1.0.0): " TAG_VERSION
-
-if [[ ! "$TAG_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
-    echo "[ERROR] 版本号格式必须符合 vX.Y.Z 格式" >&2
-    exit 1
-fi
+echo "==> [2/4] 获取版本 Tag..."
+LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "无")
+echo "本地最近的 Tag 版本为: $LATEST_TAG"
+
+# 提取 project.yml 中的 MARKETING_VERSION 和 CURRENT_PROJECT_VERSION
+PROJ_VERSION=$(sed -n 's/^[[:space:]]*MARKETING_VERSION:[[:space:]]*\([0-9.]*\)/\1/p' PhantomKnob/project.yml | tr -d '[:space:]')
+PROJ_BUILD=$(sed -n 's/^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*\([0-9]*\)/\1/p' PhantomKnob/project.yml | tr -d '[:space:]')
+DEFAULT_TAG="v${PROJ_VERSION}"
+
+echo "project.yml 中的 MARKETING_VERSION 为: $PROJ_VERSION"
+echo "project.yml 中的 CURRENT_PROJECT_VERSION 为: $PROJ_BUILD"
+read -rp "请输入要发布的新版本号 (默认: ${DEFAULT_TAG}，回车直接确认): " TAG_INPUT
+
+if [ -z "$TAG_INPUT" ]; then
+    TAG_VERSION="$DEFAULT_TAG"
+else
+    TAG_VERSION="$TAG_INPUT"
+fi
+
+if [[ ! "$TAG_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
+    echo "[ERROR] 版本号格式必须符合 vX.Y.Z 格式 (当前输入: $TAG_VERSION)" >&2
+    exit 1
+fi
+
+# 计算最新的 Build Number 并回写更新 project.yml
+CLEAN_VERSION="${TAG_VERSION#v}"
+BUILD_NUMBER=$(git rev-list --count HEAD)
+
+SHOULD_UPDATE_YML=false
+if [ "$CLEAN_VERSION" != "$PROJ_VERSION" ]; then
+    SHOULD_UPDATE_YML=true
+fi
+if [ "$BUILD_NUMBER" != "$PROJ_BUILD" ]; then
+    SHOULD_UPDATE_YML=true
+fi
+
+if [ "$SHOULD_UPDATE_YML" = "true" ]; then
+    echo "正在更新 project.yml 中的版本和构建号 (Version: $CLEAN_VERSION, Build: $BUILD_NUMBER)..."
+    sed -i '' "s/\(MARKETING_VERSION:[[:space:]]*\)[0-9.]*/\1${CLEAN_VERSION}/" PhantomKnob/project.yml
+    sed -i '' "s/\(CURRENT_PROJECT_VERSION:[[:space:]]*\)[0-9]*/\1${BUILD_NUMBER}/" PhantomKnob/project.yml
+    
+    echo "正在运行 xcodegen 重新生成项目..."
+    (cd PhantomKnob && xcodegen)
+    
+    echo "正在提交版本和构建号更新并推送至当前分支..."
+    git add PhantomKnob/project.yml
+    if [ -d "PhantomKnob/PhantomKnob.xcodeproj" ]; then
+        git add PhantomKnob/PhantomKnob.xcodeproj
+    fi
+    git commit -m "bump: version to $CLEAN_VERSION ($BUILD_NUMBER)"
+    git push origin "$(git branch --show-current)"
+fi
```

- [ ] **步骤 2：测试提取、替换与自动提交逻辑以验证 correctness**
在 shell 中验证提取、回写、xcodegen 以及 Git 提交和推送逻辑是否通畅。

- [ ] **步骤 3：Commit 变更**
```bash
git add scripts/local_release.sh
git commit -m "feat: auto-bump CURRENT_PROJECT_VERSION and commit version bump before release"
```
