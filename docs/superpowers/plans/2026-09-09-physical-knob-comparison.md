# 首页「与实体旋钮对比」版块实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在首页 `index.html` 的 02 场景之后新增「与实体旋钮对比」版块（5 张优势卡 + 总结条 + 下载 CTA），并同步更新导航与后续版块编号。

**架构：** 纯静态单页修改。复用现有 `.fcard` 卡片样式、`.rv` 入场动画与现有断点体系，仅新增 3 个局部 CSS 类（`.vs-cards` / `.vs-lead` / `.vs-sum`），不改动任何 JS。规格见 `docs/superpowers/specs/2026-09-09-physical-knob-comparison-design.md`。

**技术栈：** 原生 HTML/CSS（单文件站点，无构建系统、无测试框架，验证以浏览器人工检查 + grep 断言为主）。

**注意：** `docs/` 已被 `.gitignore` 忽略，规格与计划仅本地保留；但 `index.html` 的代码变更需要正常 commit。

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `index.html` | 修改 | 新增版块 HTML、新增版块 CSS、导航与版块编号顺延 |

单文件站点，遵循现状（不拆分文件）。CSS 插入点：`/* showcase placeholders */` 样式块结束后、`/* pricing */` 之前。HTML 插入点：`<!-- 02 SCENES -->` 的 `</section>` 之后、`<!-- 03 GET STARTED -->` 之前。

---

### 任务 1：新增版块 CSS

**文件：**
- 修改：`index.html`（`<style>` 内，`/* showcase placeholders */` 块结束后插入）

- [ ] **步骤 1：插入 CSS**

在 `/* showcase placeholders */` 样式块（`.shot p{...}` 行）之后、`/* pricing */` 之前插入：

```css
/* vs physical knobs */
.vs-cards{display:grid;grid-template-columns:1fr 1fr;gap:18px}
.vs-cards .en{display:block;font-family:var(--font-mono);font-size:0.66rem;letter-spacing:0.18em;color:var(--ink-3);margin:2px 0 10px}
.vs-lead{grid-column:1/-1;display:grid;grid-template-columns:1fr 320px;gap:28px;align-items:center;background:linear-gradient(120deg,rgba(255,159,10,0.06),transparent 55%),var(--panel);border-color:rgba(255,159,10,0.22)}
.vs-sum{border:1px dashed rgba(255,159,10,0.3);border-radius:16px;padding:28px 32px;margin-top:22px;text-align:center;background:linear-gradient(180deg,rgba(255,159,10,0.04),transparent 60%)}
.vs-sum p{color:var(--ink-2);font-size:0.98rem;line-height:1.8}
.vs-sum b{color:var(--amber);font-weight:600}
.vs-sum .btn{margin-top:16px}
@media (max-width:680px){
  .vs-cards{grid-template-columns:1fr}
  .vs-lead{grid-template-columns:1fr}
  .vs-sum{padding:24px 20px}
}
```

说明：卡片本体直接复用现有 `.fcard`；`.vs-lead` 只是叠加网格布局与琥珀渐变底；`@media` 内联在本块中，不改动既有媒体查询块。

- [ ] **步骤 2：验证 CSS 存在且无语法遗漏**

运行：`rg -c "vs-cards|vs-lead|vs-sum" index.html`
预期：`3`（三个类名各出现 1 次于 CSS，不含 HTML 部分时为 3；若已做任务 2 则数字更大，此时改用 `rg -c "vs-cards\{" index.html` 应为 `2`（主定义 + 媒体查询））

---

### 任务 2：插入新版块 HTML

**文件：**
- 修改：`index.html`（`<!-- 02 SCENES -->` 区块 `</section>` 之后）

- [ ] **步骤 1：插入完整版块 HTML**

在 `<!-- 02 SCENES -->` 的 `</section>` 与 `<!-- 03 GET STARTED -->` 之间插入：

```html
  <!-- 03 VS PHYSICAL KNOBS -->
  <section id="vs">
    <div class="wrap">
      <div class="sec-head rv">
        <div class="sec-index"><span class="num">03 / VS PHYSICAL KNOBS</span><span class="rule"></span></div>
        <h2 class="sec-title">旋钮的尽头，是你的触控板</h2>
        <p class="sec-desc">调色、剪辑、混音需要一颗好旋钮——但这不意味着要花几百甚至上千美元买一台实体控制台。PhantomKnob 把它装进你的触控板。</p>
      </div>
      <div class="vs-cards">
        <div class="fcard rv">
          <div class="fi"><svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2v20M17 7H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg></div>
          <h3>便宜</h3>
          <span class="en">A FRACTION OF THE PRICE</span>
          <p>一台实体控制台动辄几百上千美元。PhantomKnob 免费起步，价格只是它的零头。</p>
        </div>
        <div class="fcard rv">
          <div class="fi"><svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true"><path d="M20.2 3.8a2.2 2.2 0 0 0-3.1 0L8 12.8V16h3.2l9-9a2.2 2.2 0 0 0 0-3.2z"/><path d="M16 5l3 3"/><path d="M3 21c2-4 6-6 9-6"/></svg></div>
          <h3>轻便</h3>
          <span class="en">TRAVEL LIGHT</span>
          <p>无需沉重的额外设备。移动办公时，再也不会为它多背一件行李——旋钮就藏在触控板里。</p>
        </div>
        <div class="fcard rv">
          <div class="fi"><svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="4" width="16" height="16" rx="3"/><path d="M9 9h6M9 13h4"/></svg></div>
          <h3>简约</h3>
          <span class="en">ZERO FOOTPRINT</span>
          <p>无实体、零占用。不占据宝贵的桌面空间，也没有繁琐的供电和线缆问题——桌面依旧极简。</p>
        </div>
        <div class="fcard rv">
          <div class="fi"><svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 12c0-2.2 1.8-4 4-4 3 0 5 8 8 8a4 4 0 0 0 0-8c-3 0-5 8-8 8-2.2 0-4-1.8-4-4z"/></svg></div>
          <h3>数量不限</h3>
          <span class="en">INFINITE KNOBS</span>
          <p>实体旋钮数量有限，一钮一职。PhantomKnob 可定制无限旋钮——光标指哪，旋钮就在哪。</p>
        </div>
        <div class="fcard vs-lead rv">
          <div>
            <div class="fi"><svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8"/><path d="M12 7v5l3 2" stroke-linecap="round"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2"/></svg></div>
            <h3>体验</h3>
            <span class="en">BEYOND PHYSICAL</span>
            <p>单旋钮忠实还原实体旋钮的手感；双环旋钮和无级变速旋钮则超越实体旋钮，带来它给不了的全新体验。</p>
          </div>
          <svg viewBox="0 0 320 120" aria-hidden="true">
            <g fill="none" stroke-width="1.4">
              <circle cx="60" cy="60" r="34" stroke="rgba(10,132,255,0.7)"/><circle cx="60" cy="60" r="3" fill="#0a84ff"/>
              <circle cx="160" cy="60" r="34" stroke="rgba(10,132,255,0.7)"/><circle cx="160" cy="60" r="20" stroke="rgba(48,209,88,0.7)"/>
              <circle cx="266" cy="60" r="34" stroke="rgba(10,132,255,0.7)"/><circle cx="266" cy="60" r="24" stroke="rgba(48,209,88,0.55)" stroke-dasharray="4 4"/><circle cx="266" cy="60" r="14" stroke="rgba(48,209,88,0.7)"/>
            </g>
            <g font-family="IBM Plex Mono,monospace" font-size="8.5" fill="rgba(242,239,231,0.45)" text-anchor="middle">
              <text x="60" y="112">单旋钮 · 模仿</text><text x="160" y="112">双环 · 双速</text><text x="266" y="112">无级变速 · 随心</text>
            </g>
          </svg>
        </div>
      </div>
      <div class="vs-sum rv">
        <p>实体控制台好用，但昂贵又不好带；PhantomKnob 好用，轻便简约，价格还只是它的<b>零头</b>——<br>为什么不先用一下，不够用再升级？</p>
        <a class="btn btn-primary" href="https://github.com/benwu232/PhantomKnob/releases/latest/download/PhantomKnob.dmg">下载免费版</a>
      </div>
    </div>
  </section>
```

- [ ] **步骤 2：验证插入位置与数量**

运行：`rg -n "id=\"vs\"|VS PHYSICAL KNOBS|BEYOND PHYSICAL" index.html`
预期：`id="vs"` 1 处、`VS PHYSICAL KNOBS` 1 处、`BEYOND PHYSICAL` 1 处，且 `id="vs"` 位于 `id="scenes"` 与 `id="start"` 之间。

运行：`rg -n "section id=" index.html`
预期：依次出现 `features` → `scenes` → `vs` → `start` → `principle` → `trust` → `pricing` → `faq`，顺序正确。

---

### 任务 3：导航与版块编号顺延

**文件：**
- 修改：`index.html`（`<nav>` 区、以及 START/PRINCIPLE/TRUST/PRICING/FAQ 五个版块的 `.sec-index .num`）

- [ ] **步骤 1：更新导航**

将导航中 7 个链接替换为 8 个（新增「对比」，序号顺延）：

```html
      <a href="#features"><span class="n">01</span>功能</a>
      <a href="#scenes"><span class="n">02</span>场景</a>
      <a href="#vs"><span class="n">03</span>对比</a>
      <a href="#start"><span class="n">04</span>上手</a>
      <a href="#principle"><span class="n">05</span>原理</a>
      <a href="#trust"><span class="n">06</span>安全</a>
      <a href="#pricing"><span class="n">07</span>定价</a>
      <a href="#faq"><span class="n">08</span>FAQ</a>
```

- [ ] **步骤 2：顺延后续版块编号（共 5 处）**

| 原文 | 改为 |
|------|------|
| `03 / START` | `04 / START` |
| `04 / PRINCIPLE` | `05 / PRINCIPLE` |
| `05 / TRUST` | `06 / TRUST` |
| `06 / PRICING` | `07 / PRICING` |
| `07 / FAQ` | `08 / FAQ` |

注意逐个精确替换（旧编号与新编号存在交叉，直接全局替换会互相污染；按从大到小的顺序替换：先改 `07 / FAQ`→`08 / FAQ`，再 `06 / PRICING`→`07 / PRICING`，依次类推）。

- [ ] **步骤 3：验证编号一致性**

运行：`rg -o "<span class=\"n\">0[0-9]</span>" index.html`
预期：按顺序输出 `01 02 03 04 05 06 07 08`（共 8 个）。

运行：`rg -o "0[0-9] / (FEATURES|SCENES|VS PHYSICAL KNOBS|START|PRINCIPLE|TRUST|PRICING|FAQ)" index.html`
预期：依次输出 `01 / FEATURES`、`02 / SCENES`、`03 / VS PHYSICAL KNOBS`、`04 / START`、`05 / PRINCIPLE`、`06 / TRUST`、`07 / PRICING`、`08 / FAQ`，各 1 次、无重复无缺漏。

---

### 任务 4：浏览器验收（对照规格第 6 节）

**文件：** 无修改，纯验证

- [ ] **步骤 1：本地打开页面**

运行：`open index.html`

- [ ] **步骤 2：逐条核对验收标准**

1. 新版块出现在 02 场景之后，5 张卡文案与规格 3.2 表格逐字一致。
2. 导航 8 个条目；点击「对比」平滑滚动到新版块（`html{scroll-behavior:smooth}` 已有）。
3. 窗口宽度 >680px：4 张卡两列 + 压轴卡全宽（左文右图示）；≤680px 全部单列，无横向滚动条。
4. 滚动到新版块时各元素有淡入上移的 `.rv` 入场动画。
5. 后续版块（上手/原理/安全/定价/FAQ）编号正确、锚点可达、样式无回归；hero 旋钮演示与 FAQ 交互正常。

- [ ] **步骤 3：Commit**

```bash
git add index.html
git commit -m "feat(site): add VS physical-knobs comparison section"
```

---

## 自检记录

1. **规格覆盖度：** 规格 §2 位置与导航 → 任务 3；§3.1 版块头、§3.2 五张卡、§3.3 总结条 → 任务 2；§4 视觉与交互（CSS/响应式/.rv）→ 任务 1；§6 验收 → 任务 4。无遗漏。
2. **占位符扫描：** 所有代码步骤均含完整代码；无 TODO/待定。
3. **类型一致性：** CSS 类名（`vs-cards` / `vs-lead` / `vs-sum` / `.en`）在任务 1 与任务 2 中一一对应；DMG 链接与现有下载按钮一致。
