# PhantomKnob 图标与状态栏视觉设计规格说明书

本规格说明书定义了 PhantomKnob 的应用程序图标（Logo）以及状态栏（StatusBar）图标的视觉结构、状态配色方案与技术实现标准。

---

## 1. 核心视觉设计理念

根据触控板手势模拟旋钮的核心心智模型，图标采用 **“2D 极简几何外环 + 触点 + 指针”** 的设计。
为确保在不同运行状态与系统外观下拥有极致的层级清晰度，整体采用**烘焙阴影**与**系统级动态染色**方案。

---

## 2. 应用程序官方 Logo 设计 (App Logo)

Logo 应用于 Dock 栏、Launchpad 和系统设置中。采用 2D 弥散投影结构以建立悬浮高度感：

```
+---------------------------------------------+
|                                             |
|                   ( 触点 1 )                |
|                 * * * * * *                 |
|             *                 *             |
|           *       /             *           |
|         *        / 指针           *         |
|        *        o                  *        |
|         *                         *         |
|           *                     *           |
|             *                 *             |
|                 * * * * * *                 |
|                   ( 触点 2 )                |
|                                             |
|        - - - - - - - - - - - - - - -        |
|       ( 烘焙双重弥散阴影, Y轴下偏 15px )     |
+---------------------------------------------+
```

### 图层结构与规范
* **背景底座**：一个纯圆形的深灰色圆盘（`#141821`），带有一些微弱的半透明磨砂玻璃质感和 1px 细白边缘。
* **物理浮空（烘焙阴影）**：直接在输出的静态图片中渲染两层阴影：
  1. **环境光遮蔽阴影**：半径 5px，不透明度 40% 的深色阴影。
  2. **重力投射阴影**：半径 35px，不透明度 25% 的弥散阴影，Y 轴向下偏移 15 像素（模拟旋钮悬浮在底盒之上的物理深度）。
* **全息触点与指针**：
  * **触点**：圆周外侧 180° 对称排列的两个小圆形触点，象征触控板上的双指。
  * **指针**：从中心圆核向右上延伸的棒状指针。
  * **色彩**：采用发光青色（Cyan，`#00E5FF`）到紫色（Purple，`#BD10E0`）的渐变发光霓虹色。

---

## 3. 状态栏图标设计规格 (Status Bar Icons)

状态栏图标尺寸极其微缩（16px x 16px），故进行几何简化以确保在状态栏的狭小空间中也具有极致的辨识度。

### 三状态映射图样

| 状态文件名称 | 几何元素结构 | 代表的语义 |
| :--- | :--- | :--- |
| **`statusbar_inactive`** | 细圆环 + 竖直向上指针（**无**指面触点点） | **未激活**：程序在后台静默。 |
| **`statusbar_activated`** | 细圆环 + 竖直向上指针（**无**指面触点点） | **已激活**：幻影就绪，等待双指触摸。 |
| **`statusbar_knobing`** | 细圆环 + 右倾斜45°指针 + 圆周对称双触点 | **操作中**：双指正在旋转手势模拟。 |

---

## 4. 技术实现方案与着色代码规范 (方案乙)

为了自适应 macOS 系统的深色（Dark Mode）与浅色（Light Mode）菜单栏，并保障完美对比度，不直接使用彩色 PNG，而是采用**纯白单色模板图 + 运行期系统内容染色（Content Tinting）**：

### 4.1 资源打包规范
* 将 `statusbar_inactive.png`、`statusbar_activated.png`、`statusbar_knobing.png` 打包为纯白色底（Alpha 通道承载透明度）的图像资源。
* 放入 `/Assets.xcassets/StatusBar/` 中，并在 Xcode 中将其 `Render As` 属性声明为 `Template Image`（代码中对应 `isTemplate = true`）。

### 4.2 运行期染色逻辑（Swift 伪代码）
在 `StatusBarController.swift` 中，通过改变 `NSStatusItem.button` 的 `contentTintColor` 实现高保真着色：

```swift
func updateStatusBarIcon(for state: KnobGlobalState) {
    guard let button = statusItem?.button else { return }
    
    // 1. 切换对应的单色模板图
    let imageName: String
    switch state {
    case .inactive:
        imageName = "statusbar_inactive"
    case .activated:
        imageName = "statusbar_activated"
    case .knobing, .cooling:
        imageName = "statusbar_knobing"
    case .customizing:
        imageName = "statusbar_inactive"
    }
    
    button.image = NSImage(named: imageName)
    button.image?.isTemplate = true
    
    // 2. 根据“方案乙”应用对应的系统内容色彩染色
    switch state {
    case .inactive:
        // 未激活：系统自适应灰色
        button.contentTintColor = .systemGray
    case .activated:
        // 已激活就绪：系统青色/冰蓝色 (Cyan)
        button.contentTintColor = .systemCyan
    case .knobing, .cooling:
        // 操作中：系统绿色 (Green)
        button.contentTintColor = .systemGreen
    case .customizing:
        button.contentTintColor = .systemGray
    }
}
```

---

## 5. 验收标准与测试验证

### 5.1 视觉验收
- [ ] 应用程序 Logo (AppIcon) 在 Dock 栏浅色壁纸下阴影对比清晰，展现悬浮高度感。
- [ ] 应用程序 Logo 在 Launchpad 深色底色下，青-紫霓虹色依然鲜明可见。

### 5.2 状态栏对比度验证
- [ ] **系统深色菜单栏测试**：Inactive（灰色）、Activated（青色）、Knobing（绿色）均清晰可见，对比度大于 4.5:1。
- [ ] **系统浅色菜单栏测试**：Inactive（深灰）、Activated（深青）、Knobing（深绿）均自动加深，对比度依然符合要求。
