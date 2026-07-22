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
+# 提取 project.yml 中的 MARKETING_VERSION
+PROJ_VERSION=$(sed -n 's/^[[:space:]]*MARKETING_VERSION:[[:space:]]*\([0-9.]*\)/\1/p' PhantomKnob/project.yml | tr -d '[:space:]')
+DEFAULT_TAG="v${PROJ_VERSION}"
+
+echo "project.yml 中的 MARKETING_VERSION 为: $PROJ_VERSION"
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
+# 如果用户输入了不同的版本号，则自动更新 project.yml
+CLEAN_VERSION="${TAG_VERSION#v}"
+if [ "$CLEAN_VERSION" != "$PROJ_VERSION" ]; then
+    echo "检测到不同的版本号，正在将 project.yml 中的 MARKETING_VERSION 更新为: $CLEAN_VERSION"
+    sed -i '' "s/\(MARKETING_VERSION:[[:space:]]*\)[0-9.]*/\1${CLEAN_VERSION}/" PhantomKnob/project.yml
+    
+    echo "正在运行 xcodegen 重新生成项目..."
+    (cd PhantomKnob && xcodegen)
+fi
```

- [ ] **步骤 2：测试提取与替换逻辑以验证 correctness**
在 shell 中直接运行提取和 sed 替换以及 xcodegen 命令，确保其能正常回写并构建项目。

- [ ] **步骤 3：Commit 变更**
```bash
git add scripts/local_release.sh
git commit -m "feat: auto-detect and write custom version to project.yml in local_release.sh"
```
