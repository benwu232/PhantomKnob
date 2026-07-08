# PhantomKnob 图标与状态栏视觉设计规格说明书

本规格说明书定义了 PhantomKnob 的应用程序图标（Logo）以及状态栏（StatusBar）图标的视觉结构、状态配色方案与技术实现标准。

---

## 1. 核心视觉设计理念

根据触控板手势模拟旋钮的核心心智模型，图标采用 **“2D 极简几何外环 + 触点 + 指针”** 的设计。
为确保在不同运行状态与系统外观下拥有极致的层级清晰度，整体采用**烘焙阴影**与**系统级动态染色**方案。

---

## 2. 应用程序官方 Logo 设计 (App Logo - 方案 A 全息拟物)

Logo 应用于 Dock 栏、Launchpad 和系统设置中。采用三层立体空间结构，强调“物理触感（底盘）”与“全息旋钮（悬浮）”的虚实结合：

```
+---------------------------------------------+
|                                             |
|          [ 顶层：加粗 2D 浮空旋钮 ]           |
|                 * * * * * *                 |
|             *                 *             |
|           *  \                  *           |
|         *     \ 指针 (左旋 45°)  *          |
|          [ 顶层：皮肤色触点 + 接触阴影 ]     |
|          (触点1: 45°)         (触点2: -135°) |
|             [O]                  [O]         |
|      (叠在旋钮上)             (叠在旋钮上)     |
|                                             |
|        =============================        |
|        - - [ 中层：2D 粗外环全息旋钮 ] - -    |
|        =============================        |
|                                             |
|        - - - ( 弥散悬浮阴影投射 ) - - -      |
|                                             |
|    - - - - - - - - - - - - - - - - - - -    |
|    [ 底层：磨砂玻璃触控板 + 触电触觉涟漪 ]  |
+---------------------------------------------+
```

### 四层图层结构与规范
* **第一层（底层 - 触控板与触觉涟漪）**：
  * **触控板底盘**：一个大圆角的方形底盘，具有磨砂玻璃（`#1F222B`）质感和高对比度边框高光，模拟 MacBook 的触控板。
  * **触觉涟漪**：从两个触点在底盘垂直投影对应的坐标向外辐射 2 圈半透明同心圆波纹，代表触觉马达（Haptics）的电磁震动反馈。
* **第二层（中层 - 物理悬浮阴影）**：
  * 悬浮旋钮的圆环和指针在底层投射一层双重弥散阴影，阴影 Y 轴向下偏移 15px-25px，模拟悬浮高度。
* **第三层（中顶层 - 2D 全息旋钮）**：
  * **粗圆环**：旋钮的外围圆环线宽加粗（占直径的 8%），拥有极佳的饱满度。
  * **中心指针**：旋钮去除中心的圆点（空心镂空）。指针线条与圆周外环**完全脱离（相隔 25% 间距）**，从 60% 半径处向中心 20% 半径处延伸，**指向左上方 45° (135° 位置)**，线宽为 6%。
  * **色彩**：采用高饱和度的发光青色（Cyan，`#00E5FF`）到靛蓝色（Indigo，`#4B0082`）的渐变霓虹发光。
* **第四层（顶层 - 触点与 3D 光学微触感）**：
  * **手势触点**：两个发光的**淡皮肤色（`#FFCAD4`）**大圆形触点（尺寸占大小的 7%）直接叠在旋钮圆环上方（45° 和 -135° 位置），象征手指直接触碰抓握着悬浮圆环。
  * **接触阴影（Contact Shadow）**：每个触点在圆盘和圆环上投下极小的向下偏位的锐利黑色遮蔽阴影，建立清晰的按压贴合度。
  * **3D 微光泽**：每个触点上绘制一圈半透明的微缩白色月牙形边缘高光，模拟手指指甲或指尖的反光立体感。

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
