# 首页 Slogan 与副标题优化 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 更新英文和中文首页的 Hero 区域主副标题文案，突出手势创新、物理旋钮模拟与双环/无级变速特性。

**架构：** 直接修改 HTML 文件中的 Hero 区域标签、主标题 (`h1.hero-title`) 和副标题 (`p.hero-desc`) 节点，无需修改 CSS 或 JavaScript。

**技术栈：** HTML5

---

### 任务 1：更新中文首页文案

**文件：**
- 修改：`index_zh.html`

- [ ] **步骤 1：修改主副标题文案**
  替换 `index_zh.html` 中的主标题与副标题文案。

  目标代码位置（从：`A gesture you've never tried...` 修改为新文案）：
  ```html
  <div class="section-tag">一种你从未尝试过的手势</div>
  <h1 class="hero-title">幻影旋钮，自然手势。<span>快速精准，全新体验。</span></h1>
  <p class="hero-desc">PhantomKnob 使用创新技术把触控板体验带入全新维度。无需外接硬件，即可在触控板上像使用实体旋钮一样用旋转手势快速精确地调整数值。而独创的双环旋钮与无级变速旋钮更突破了物理限制，为您带来超越实体旋钮的全新体验。</p>
  ```

- [ ] **步骤 2：验证渲染与布局**
  在本地浏览器预览 `http://localhost:8765/index_zh.html`，确保：
  1. 主标题和副标题已正确更新。
  2. 页面布局无崩坏，多行文本自动换行正常。

- [ ] **步骤 3：Commit 变更**
  ```bash
  git add index_zh.html
  git commit -m "marketing: update Chinese homepage slogan and subtitle"
  ```

---

### 任务 2：更新英文首页文案

**文件：**
- 修改：`index.html`

- [ ] **步骤 1：修改英文主副标题文案**
  替换 `index.html` 中的主标题与副标题文案。

  目标代码位置：
  ```html
  <div class="section-tag">A gesture you've never tried</div>
  <h1 class="hero-title">Phantom Knob: Natural Gestures. <span>Fast & Precise. Reimagined.</span></h1>
  <p class="hero-desc">PhantomKnob elevates your trackpad to a whole new dimension. Without any external hardware, simple rotation gestures let you adjust parameters quickly and precisely &mdash; just like using a physical knob. With our unique double-ring and continuously variable knobs, we bring you superior experiences beyond physical constraints.</p>
  ```

- [ ] **步骤 2：验证渲染与布局**
  在本地浏览器预览 `http://localhost:8765/index.html`，确保：
  1. 英文主标题和副标题正确显示。
  2. 样式及文字包裹完全正常。

- [ ] **步骤 3：Commit 变更**
  ```bash
  git add index.html
  git commit -m "marketing: update English homepage slogan and subtitle"
  ```
