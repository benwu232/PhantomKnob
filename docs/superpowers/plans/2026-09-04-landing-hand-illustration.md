# 落地页 Hero 幻影手插画 + 旋钮外观对齐 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 落地页右上角交互 demo 与 App 真实外观对齐（去中心圆、针改发光圆点），并叠加一只随旋钮同步旋转的「幻影手」扁平插画（对握：拇指 12 点位、中指 6 点位），删除原两颗粉色指尖圆点，收窄待机摆幅，03 节单旋钮卡片同步更新。

**架构：** 单文件静态页 `redesign/index.html`（内联 CSS/JS/SVG，无构建系统）。手插画为 hero SVG 内新增 `<g id="hand">` 组，通过与 rotor 相同的 `rotate(-angle)` 模型旋转（固定 rest 偏移），指尖接触点即手与旋钮的"焊点"。中心数值为 HTML 绝对定位层，天然位于 SVG 之上，保证中指横过正面时数值可读。

**技术栈：** 原生 HTML/CSS/JS + 内联 SVG（feDropShadow 发光、feGaussianBlur 接触阴影、userSpaceOnUse linearGradient 手腕淡出）。

**目标仓库：** `/Users/wb/work/PhantomKnob`（`main` 分支，`redesign/` 目前未跟踪）

---

## 设计共识（已与用户逐项确认）

- 去中心圆：删除 hero r=19 中心圆
- 指针改圆点：app 同款发光圆点，落在 trail 半径 53 上（app 公式 `r*0.16`，d=220 → r≈8）
- 手插画：扁平填充——浅肤色底 `#f3d3bd` + 略深描边/阴影 `#d9a988`/`#e3b89c`，指尖用页面粉色 `#f2c4cd`
- 握持：**对握**——拇指按 12 点位、中指按 6 点位（直径两端）；中指横跨旋钮面段落做半透明处理（fill-opacity 0.88），中心数值为 HTML 层天然在 SVG 之上，可读性由层叠保证
- 姿态：右手从正上方入画（手腕朝上、指尖向下），手腕向上延伸、末端渐变淡出
- 接触表现：两处指尖接触点加轻微接触阴影（feGaussianBlur）+ 按压光晕（粉色描边圈）
- 旋转跟随：整只手以旋钮中心为轴随旋钮同步旋转（含用户拖动，转倒也跟随）
- 待机摆幅：从 ±70° 收窄到 ±40°（数值 50%↔70%，`value=60+10*sin(t*0.55)`）
- 粉色指尖圆点 #f1/#2：删除
- 03 节：只更新「单旋钮」卡片（去中心圆 + 针改圆点）；双旋钮/CVK 挂起不动（用户后议）

---

## 文件结构

- 修改：`/Users/wb/work/PhantomKnob/redesign/index.html`（唯一改动文件，789 行）
  - `<style>` 段：`.knob-value` 居中（L97）；初始默认值 65%→60%（L107-108）
  - hero SVG 标记：`<defs>` 新增 dotGlow/softBlur/wristFade；删中心圆与 f1/f2；新增 `<g id="hand">`（L274-282）
  - `<script>` 段：hero 圆点替换（L649-650）、删 placeFingers/f1/f2（L646-647, 655-662, 686, 712-713, 730-731）、render 加 hand 旋转、idleLoop 收窄摆幅（L692）、reduced 分支（L743）、`buildKnob("single")` 同步（L593-601）

验证方式说明：本页面无测试框架，纯视觉改动。每个任务以「grep 静态断言 + 浏览器人工核对清单」作为验证步骤，每任务独立 commit，保证可回滚定位。

---

### 任务 1：基线提交

**文件：** 无改动（仅 git 操作）

- [x] **步骤 1：确认工作区干净并把 redesign/ 纳入基线**

```bash
cd /Users/wb/work/PhantomKnob && git status --short
git add redesign/index.html redesign/assets
git commit -m "chore: add landing page redesign baseline before hero hand illustration"
```

预期：`redesign/` 从 untracked 变为已跟踪；后续 diff 只含本次改动。

---

### 任务 2：hero 静态结构改造（defs、删中心圆、数值居中、hand 组挂载）

**文件：** 修改 `redesign/index.html`

- [x] **步骤 1：`.knob-value` 从顶部移到旋钮正中心（L97）**

```css
/* 原 */
.knob-value{position:absolute;top:8px;left:50%;transform:translateX(-50%);text-align:center;pointer-events:none}
/* 改为 */
.knob-value{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);text-align:center;pointer-events:none}
```

说明：该 div 是 absolute 定位层，天然绘制在静态 svg 之上——中指横过中心时「65%」始终盖在手指上方，可读性由层叠保证，无需改 DOM 顺序。

- [x] **步骤 2：初始默认值 65% → 60%（与新待机中心一致）**

- L273：`aria-valuenow="65"` → `aria-valuenow="60"`
- L274：`<div class="v" id="hv">65%</div>` → `60%`
- L291：`<span class="val" id="sv">65%</span>` → `60%`
- L107：`.track .fill{...width:65%...}` → `width:60%`
- L108：`.track .thumb{...left:65%...}` → `left:60%`

- [x] **步骤 2.5：同步清理 JS 中的 f1/f2 引用（保证本任务 commit 后页面可用）**

> 修订说明：原计划将 f1/f2 的 JS 清理放在任务 3，但任务 2 删除标记后 `placeFingers` 会因 `getElementById` 返回 null 抛 TypeError、中断动画循环。故清理提前至本任务执行：

- 删 L646-647：`var f1=document.getElementById("f1");` / `var f2=document.getElementById("f2");`
- 删 L655-662：整个 `function placeFingers(a){...}`
- 删 render 内 L686：`placeFingers(-angle);`
- 删 pointerdown 内 L712-713：两行 `f1.setAttribute("opacity","0.95");` / `f2.setAttribute("opacity","0.95");`
- 删 endDrag 内 L730-731：两行 `f1.setAttribute("opacity","0");` / `f2.setAttribute("opacity","0");`

静态断言：`grep -c 'placeFingers\|getElementById("f1")\|getElementById("f2")' redesign/index.html` 预期 0（注意不要用裸 `f1|f2`——会命中 `#f2c4cd` 等色值）。

- [x] **步骤 3：hero SVG 内加 `<defs>`，删中心圆与 f1/f2，挂载空 hand 组**

将 L275-282 的 `<svg viewBox="0 0 220 220" aria-hidden="true">...</svg>` 改为：

```svg
<svg viewBox="0 0 220 220" aria-hidden="true">
  <defs>
    <filter id="dotGlow" x="-120%" y="-120%" width="340%" height="340%">
      <feDropShadow dx="0" dy="0" stdDeviation="2.2" flood-color="#0a84ff" flood-opacity="0.55"/>
    </filter>
    <filter id="softBlur" x="-80%" y="-80%" width="260%" height="260%">
      <feGaussianBlur stdDeviation="2.5"/>
    </filter>
    <linearGradient id="wristFade" gradientUnits="userSpaceOnUse" x1="0" y1="2" x2="0" y2="24">
      <stop offset="0" stop-color="#f3d3bd" stop-opacity="0"/>
      <stop offset="1" stop-color="#f3d3bd" stop-opacity="1"/>
    </linearGradient>
  </defs>
  <circle cx="110" cy="110" r="92" fill="rgba(255,255,255,0.028)" stroke="rgba(255,255,255,0.07)" stroke-width="1"/>
  <path id="htrail" fill="none" stroke="#0a84ff" stroke-opacity="0.65" stroke-width="2.4" stroke-linecap="round" d=""/>
  <g id="rotor"></g>
  <g id="hand" transform="rotate(0 110 110)"></g>
</svg>
```

变更点：删除 r=19 中心圆（原 L279）、删除 `#f1`/`#f2`（原 L280-281）、新增 defs 与空 `#hand` 组（位于 rotor 之后 = 旋钮面之上）。

- [x] **步骤 4：静态断言**

```bash
grep -c 'id="f1"\|id="f2"\|r="19"' /Users/wb/work/PhantomKnob/redesign/index.html   # 预期 0
grep -c 'id="hand"' /Users/wb/work/PhantomKnob/redesign/index.html                  # 预期 1
```

- [x] **步骤 5：浏览器验证**

```bash
open /Users/wb/work/PhantomKnob/redesign/index.html
```

核对：中心圆消失；数值「60% 饱和度」出现在旋钮正中心且清晰；拖动仍正常（圆点暂还是针——下一任务替换）；页面无 JS 报错（console 检查）。

- [x] **步骤 6：Commit**

```bash
cd /Users/wb/work/PhantomKnob && git add redesign/index.html
git commit -m "feat(redesign): center hero knob value, drop center circle and finger dots, add hand group scaffold"
```

---

### 任务 3：JS——针改发光圆点、手随旋钮旋转、待机摆幅收窄、清理 f1/f2

**文件：** 修改 `redesign/index.html`

- [x] **步骤 1：hero 指针换 app 同款发光圆点（L649-650）**

```js
// 原
ticks(rotor,110,110,86,60,12,5,1.55,"#0a84ff",0.55);
needle(rotor,110,110,8,50,"#0a84ff",3);
// 改为（圆点半径按 app 公式 r*0.16，d=220 → r≈8；落在 trail 半径 53 上）
ticks(rotor,110,110,86,60,12,5,1.55,"#0a84ff",0.55);
el("circle",{cx:(110+53).toFixed(1),cy:110,r:8,fill:"#0a84ff",filter:"url(#dotGlow)"},rotor);
```

`needle()` 函数保留——03 节双旋钮/CVK 分支仍在使用。

- [x] **步骤 2：~~删除 f1/f2 及 placeFingers~~（已提前至任务 2 步骤 2.5，本任务跳过）**

- 删 L646-647：`var f1=document.getElementById("f1");` / `var f2=document.getElementById("f2");`
- 删 L655-662：整个 `function placeFingers(a){...}`
- 删 render 内 L686：`placeFingers(-angle);`
- 删 pointerdown 内 L712-713：两行 `f1.setAttribute("opacity","0.95");` / `f2.setAttribute("opacity","0.95");`
- 删 endDrag 内 L730-731：两行 `f1.setAttribute("opacity","0");` / `f2.setAttribute("opacity","0");`

- [x] **步骤 3：hand 旋转跟随 + 待机摆幅收窄**

L653 变量区加 REST 常量与 hand 引用：

```js
var hand=document.getElementById("hand");
var REST=60*4;   // 待机中心 value=60 → angle=240，指尖 authored 于 12/6 点位
```

`render()` 内（rotor 旋转行之后）加：

```js
hand.setAttribute("transform","rotate("+(-(angle-REST)).toFixed(2)+" 110 110)");
```

`idleLoop()`（L692）改为：

```js
value=60+10*Math.sin(idleT*0.55);   // 50↔70，角度 200↔280，摆幅 ±40°
```

reduced 分支（L743）改为：

```js
value=60;angle=60*4;startAngle=angle-40;
```

- [x] **步骤 4：静态断言**

```bash
grep -c 'placeFingers\|getElementById("f1")\|getElementById("f2")' /Users/wb/work/PhantomKnob/redesign/index.html  # 预期 0
grep -c 'setAttribute("transform","rotate("+(-(angle-REST))' /Users/wb/work/PhantomKnob/redesign/index.html        # 预期 1
```

- [x] **步骤 5：浏览器验证**

核对：发光圆点出现在 trail 半径上随旋钮转动；待机时数值在 50%↔70% 缓慢摆动、不再大摆；console 无 `f1 is not defined` 类错误；拖动/键盘方向键仍正常。

- [x] **步骤 6：Commit**

```bash
cd /Users/wb/work/PhantomKnob && git add redesign/index.html
git commit -m "feat(redesign): replace hero needle with glowing dot, rotate hand with knob, narrow idle swing"
```

---

### 任务 4：手插画路径（对握·右手·正上方入画·扁平填充）

**文件：** 修改 `redesign/index.html`（填充任务 2 挂载的空 `#hand` 组）

几何基准：rest 姿态下拇指垫 `(106,22)`（r≈88，12 点位微偏左）、中指垫 `(110,196)`（压住刻度环 r≈86）、手背质量在旋钮上方（y≈2-58）、中指沿 x≈110 纵贯正面。

- [x] **步骤 1：填入手插画（整组替换 `<g id="hand" ...></g>`）**

```svg
<g id="hand" transform="rotate(0 110 110)">
  <!-- 指尖按压接触阴影 -->
  <ellipse cx="106" cy="26" rx="11" ry="4.5" fill="rgba(0,0,0,0.30)" filter="url(#softBlur)"/>
  <ellipse cx="110" cy="192" rx="11" ry="4.5" fill="rgba(0,0,0,0.30)" filter="url(#softBlur)"/>
  <!-- 中指：横跨旋钮面，半透明段 -->
  <path d="M104 40 C104 62 105 100 105 150 C105 172 105 184 106 190 C106.5 194.5 108 197.5 110 197.5 C112 197.5 113.5 194.5 114 190 C115 184 115 172 115 150 C115 100 116 62 116 40 Z"
        fill="#f3d3bd" fill-opacity="0.88"/>
  <!-- 手腕 + 手背：顶端渐变淡出（随组旋转，淡出方向始终沿手臂轴向） -->
  <path d="M90 2 C88 14 84 24 80 34 C78 42 80 50 88 54 C96 58 124 58 132 54 C140 50 142 42 140 34 C136 24 132 14 130 2 Z"
        fill="url(#wristFade)" stroke="url(#wristFade)" stroke-width="1.2"/>
  <!-- 手背侧影 -->
  <path d="M84 36 C82 44 85 51 92 53 C88 48 87 42 87 36 Z" fill="#e3b89c" opacity="0.85"/>
  <!-- 拇指：扣在 12 点位外缘 -->
  <path d="M86 32 C88 24 95 17 103 16 C109 15.5 112 19 112 23 C112 27.5 108 30.5 102 31.5 C96 32.5 91 33.5 86 34 Z"
        fill="#f3d3bd" stroke="#d9a988" stroke-width="1.2"/>
  <!-- 指尖（粉色，呼应页面指尖语言 #f2c4cd） -->
  <circle cx="106" cy="22" r="6" fill="#f2c4cd"/>
  <circle cx="110" cy="196" r="6" fill="#f2c4cd"/>
  <!-- 按压光晕 -->
  <circle cx="106" cy="22" r="10.5" fill="none" stroke="rgba(242,196,205,0.45)" stroke-width="1.5"/>
  <circle cx="110" cy="196" r="10.5" fill="none" stroke="rgba(242,196,205,0.45)" stroke-width="1.5"/>
</g>
```

绘制顺序即 z 序：接触阴影（贴在旋钮上）→ 中指 → 手腕手背 → 侧影 → 拇指 → 粉色指尖垫 → 光晕。

- [x] **步骤 2：浏览器验证（本任务是视觉核心，允许微调 path 数值后重验）**

```bash
open /Users/wb/work/PhantomKnob/redesign/index.html
```

核对清单：
1. 手背从上方入画、顶端自然淡出，无硬切边；
2. 拇指垫压在 12 点位外缘、中指垫压在 6 点位刻度环上，接触阴影与光晕可见且不脏；
3. 中指横过正面呈半透明（刻度微微透出），中心「60% 饱和度」完全可读（文字在手指上方）；
4. 待机时手以旋钮中心为轴 ±40° 缓摆，像手腕拧动；
5. 按住拖动任意角度：手与刻度、trail、圆点完全同步旋转（转倒也跟随）；
6. 拖动全程不再出现粉色指尖圆点。

- [x] **步骤 3：Commit**

```bash
cd /Users/wb/work/PhantomKnob && git add redesign/index.html
git commit -m "feat(redesign): add phantom hand illustration gripping hero knob (flat style, pinch-across grip)"
```

---

### 任务 5：03 节「单旋钮」卡片同步（双旋钮/CVK 挂起不动）

**文件：** 修改 `redesign/index.html`（`buildKnob` 的 `single` 分支，L593-601）

- [x] **步骤 1：去中心圆 + 针改发光圆点**

```js
if(type==="single"){
  var g=el("g",{},svg);
  ticks(g,cx,cy,r,60,r*0.14,5,1.55,blue,0.55);
  var rot=el("g",{transform:"rotate(-38 "+cx+" "+cy+")"},svg);
  el("circle",{cx:(cx+r*0.62).toFixed(1),cy:cy,r:8,fill:blue,filter:"url(#dotGlow)"},rot);
  var t=el("text",{x:cx,y:cy+24,"text-anchor":"middle","font-family":"IBM Plex Mono,monospace","font-size":9,fill:"rgba(255,255,255,0.4)"},svg);
  t.textContent="1.0x";
}
```

变更点：删除 `el("circle",{cx:cx,cy:cy,r:19,...})` 一行；`needle(rot,...)` 换为 r=8 发光圆点（r*0.62≈53.3，与 hero 同语义）。`double`/`cvk` 分支与 `needle()` 函数一律不动。

- [x] **步骤 2：浏览器验证**

核对：03 节单旋钮卡片 = 无中心圆 + 蓝色发光圆点；双环旋钮与 CVK 卡片与改动前完全一致。

- [x] **步骤 3：Commit**

```bash
cd /Users/wb/work/PhantomKnob && git add redesign/index.html
git commit -m "feat(redesign): align single-knob card illustration with app (dot indicator, no center circle)"
```

---

### 任务 6：整页回归验证

- [x] **步骤 1：桌面宽度全页走查**

```bash
open /Users/wb/work/PhantomKnob/redesign/index.html
```

清单：hero 拖动手感与视觉；键盘 ↑↓←→ 调节时手同步转；`∠` 读数、chips、假滑条与数值联动正常；03 节三卡片（单=新样式，双/CVK=原样）；FAQ、定价、页脚无回归。

- [x] **步骤 2：prefers-reduced-motion 验证**

DevTools → Rendering → Emulate `prefers-reduced-motion: reduce` 后刷新：页面静止、手停在 rest 姿态（指尖 12/6 点位）、trail 呈静态短弧、数值 60%。

- [x] **步骤 3：窄屏验证（≤680px）**

DevTools 响应式 375px：holder 缩至 250px，手与旋钮等比缩放无越界、无穿帮；中心数值不溢出。

- [x] **步骤 4：最终提交（如有微调）**

```bash
cd /Users/wb/work/PhantomKnob && git add redesign/index.html
git commit -m "polish(redesign): final tuning pass for hero hand illustration"
```
