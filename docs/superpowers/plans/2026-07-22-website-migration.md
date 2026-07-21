# PhantomKnob 官网迁移与分发部署实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将静态官网资源从开发仓库 `phantom_knob_mac` 彻底迁移到公共分发仓库 `PhantomKnob` 根目录，更新落地页最新 DMG 下载直链，并清理开发库中的网站残留文件。

**架构：**
1. 复制并调整 `website/` 下所有静态文件（`index.html` 等）至 `/Users/wb/work/PhantomKnob` 根目录；
2. 修正 `index.html` 中的下载链接，指向 `https://github.com/benwu232/PhantomKnob/releases/latest/download/PhantomKnob.dmg`；
3. 从开发库 `phantom_knob_mac` 中使用 `git rm` 干净移除 `website/` 目录；
4. 提交两个仓库的更改。

**技术栈：** HTML, CSS, JavaScript, Git

---

### 任务 1：迁移官网资源至分发仓库并更新直链接

**文件：**
- 新增：`/Users/wb/work/PhantomKnob/index.html`
- 新增：`/Users/wb/work/PhantomKnob/style.css`
- 新增：`/Users/wb/work/PhantomKnob/privacy.html`
- 新增：`/Users/wb/work/PhantomKnob/terms.html`
- 新增：`/Users/wb/work/PhantomKnob/icon_compare.html`
- 新增：`/Users/wb/work/PhantomKnob/assets/`

- [ ] **步骤 1：复制网站资源至分发仓库**

在 Shell 中执行命令：
```bash
cp -R /Users/wb/work/phantom_knob_mac/website/* /Users/wb/work/PhantomKnob/
```

- [ ] **步骤 2：更新下载直链接**

在 `/Users/wb/work/PhantomKnob/index.html` 中：
将 Hero 区域下载按钮与定价区域 Free Edition 下载按钮的 `href` 修改为 GitHub Release 最新 DMG 链接。

修改前：
```html
<a href="#pricing" class="btn-primary">
    ...
    Download Free Edition
</a>
...
<a href="downloads/PhantomKnob.dmg" class="plan-btn free" id="free-download-btn">Download DMG</a>
```

修改后：
```html
<a href="https://github.com/benwu232/PhantomKnob/releases/latest/download/PhantomKnob.dmg" class="btn-primary">
    ...
    Download Free Edition
</a>
...
<a href="https://github.com/benwu232/PhantomKnob/releases/latest/download/PhantomKnob.dmg" class="plan-btn free" id="free-download-btn">Download DMG</a>
```

- [ ] **步骤 3：验证资源文件完整性**

在 Shell 中运行：
```bash
ls -la /Users/wb/work/PhantomKnob/index.html /Users/wb/work/PhantomKnob/style.css /Users/wb/work/PhantomKnob/assets
```
预期：文件全部正常存在。

- [ ] **步骤 4：在分发仓库中提交 Git Commit**

在 Shell 中运行：
```bash
git -C /Users/wb/work/PhantomKnob add index.html style.css privacy.html terms.html icon_compare.html assets/
git -C /Users/wb/work/PhantomKnob commit -m "feat: migrate website landing page files and update release download links"
```

---

### 任务 2：清理开发仓库中已迁移的网站目录

**文件：**
- 删除：`/Users/wb/work/phantom_knob_mac/website/`

- [ ] **步骤 1：使用 Git 彻底删除开发仓库中的 website 文件夹**

在 Shell 中运行：
```bash
git -C /Users/wb/work/phantom_knob_mac rm -r website
```

- [ ] **步骤 2：验证开发库 Git 状态**

在 Shell 中运行：
```bash
git -C /Users/wb/work/phantom_knob_mac status
```
预期：显示 `deleted: website/...`，工作区干净无未跟踪的保留项。

- [ ] **步骤 3：在开发仓库中提交 Commit**

在 Shell 中运行：
```bash
git -C /Users/wb/work/phantom_knob_mac commit -m "refactor: remove website directory following migration to public PhantomKnob repo"
```
