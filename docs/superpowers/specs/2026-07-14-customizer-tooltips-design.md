# 旋钮定制面板参数说明 Tooltip 与智能交互设计规范

## 1. 业务目标
为了让用户更好地理解不同旋钮类型的特性以及各项高级参数的几何意义，在旋钮定制面板 (Customizer HUD) 中引入就近提示组件：
1. **就近信息展示 (Context-Aware Tooltips)**：为“旋钮类型”以及各个微调参数（最小响应半径、内外环分界、最大显示半径）右侧增加低调的 `(i)` 信息帮助按钮。
2. **智能 Hover + 点击双重触发**：
   - **自动 Hover 提示**：鼠标悬停在 `(i)` 按钮上超过 **0.5 秒** 时，自动弹出半透明毛玻璃气泡说明。
   - **防误触延迟**：离开悬停区域或未达到 0.5 秒划过时，自动取消显示，避免无意义的弹窗刷屏。
   - **点击切换 (Toggle)**：直接点击 `(i)` 按钮可瞬间打开/关闭气泡说明，保证操作的连贯性。
3. **内容随类型动态更新**：旋钮类型的帮助信息必须根据用户当前选择的类型（单旋钮、双环、无级变速）显示相对应的内容。

---

## 2. 界面设计 (UI/UX)
- **信息图标**：每个受支持的设置项标题右侧显示一个小型的帮助图标（使用系统 SF Symbol `info.circle`），默认不透明度较低（`.opacity(0.4)`），鼠标悬浮或气泡打开时高亮（`.opacity(0.8)`）。
- **气泡样式**：使用 dark 风格的自定义 SwiftUI `.popover`，带圆角，文字排版清晰：
  - **结构**：上面是简单功能描述，下面是参数详细说明（当适用于具体参数时）。
  - **背景色**：匹配 HUD 的深色磨砂玻璃背景，文字为白色与次级半透明白色。
- **触发入口**：
  - **① 旋钮类型** 标题右侧
  - **② 最小响应半径** 标签右侧
  - **③ 内外环分界** 标签右侧（仅双环模式）
  - **④ 最大显示半径** 标签右侧（仅无级变速模式）

---

## 3. 详细设计 (Detailed Design)

### 3.1 帮助文案内容设计 (支持中英双语本地化)

我们将所有的提示文案写入 `Localizable.xcstrings` 并引入对应的本地化 Key。

#### 1. 旋钮类型 (hud.knobType.help)
*   **单旋钮 (Single Knob)**:
    - 简单描述：传统的单点触控模式，模拟标准的物理旋钮，灵敏度恒定。
*   **双环旋钮 (Double-Ring)**:
    - 简单描述：自动双档模式。手指在内环旋转为正常灵敏度，在外环旋转自动切换为精细微调。
*   **无级变速旋钮 (Variable Speed)**:
    - 简单描述：动态灵敏度模式。旋转速度根据手指离旋钮中心的距离连续平滑变化，拉得越远，旋转速度越快。

#### 2. 最小响应半径 (hud.minRadius.help)
*   简单描述：防止旋钮中心误触的安全半径。
*   详细解释：手指触发旋转的最小距离阈值（单位：mm）。小于该半径的微小晃动不会被识别，能有效防止在旋钮中心附近的指针抖动或突变。

#### 3. 内外环分界 (hud.innerRadius.help)
*   简单描述：双环灵敏度档位切换的界限。
*   详细解释：划分“高灵敏度内环”与“低灵敏度外环”的半径分界线。手指旋划半径超过此值时，自动切换为精细调节（通常为 0.1 倍速）。

#### 4. 最大显示半径 (hud.maxRadius.help)
*   简单描述：灵敏度增长的最大几何上限。
*   详细解释：无级变速灵敏度随距离线性增长的上限边界。当手指拉到该半径之外时，旋划速度达到最大倍率，不再继续随距离增加。

### 3.2 智能 Hover / Click 双重触发器组件 (HUDHelpButton)

我们可以为 SwiftUI 封装一个通用的通用组件 `HUDHelpButton`，以保证交互行为在整个 HUD 中完美复用：

```swift
struct HUDHelpButton: View {
    let content: String
    
    @State private var isPresented = false
    @State private var hoverWorkItem: DispatchWorkItem?
    
    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 11))
            .foregroundColor(.white)
            .opacity(isPresented ? 0.8 : 0.4)
            .contentShape(Rectangle()) // 扩大点击/悬浮热区
            .onHover { isHovering in
                if isHovering {
                    // 创建 0.5 秒的延时任务
                    let item = DispatchWorkItem {
                        withAnimation(.easeOut(duration: 0.15)) {
                            self.isPresented = true
                        }
                    }
                    self.hoverWorkItem = item
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
                } else {
                    // 离开时，取消未执行的任务，并直接关闭 popover
                    self.hoverWorkItem?.cancel()
                    self.hoverWorkItem = nil
                    withAnimation(.easeOut(duration: 0.15)) {
                        self.isPresented = false
                    }
                }
            }
            .onTapGesture {
                // 点击立即取反显示状态，不受 Hover 延时干扰
                self.hoverWorkItem?.cancel()
                self.hoverWorkItem = nil
                self.isPresented.toggle()
            }
            .popover(isPresented: $isPresented, arrowEdge: .trailing) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(content)
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
                .padding(10)
                .frame(width: 220)
                .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow).cornerRadius(8))
            }
    }
}
```

---

## 4. 验证计划

### 4.1 单元测试与交互自测
1. **Hover 延迟测试**：鼠标快速划过任意 `(i)` 图标，气泡不应闪烁弹出；停留在图标上超过 0.5s，气泡必须平滑渐现。
2. **Hover 离开测试**：鼠标离开图标，气泡自动隐去。
3. **点击测试**：点击 `(i)` 图标，气泡瞬间弹出，点击外部或再次点击图标，气泡关闭。
4. **动态切换测试**：切换旋钮类型为“双环”或“无级变速”，点击“旋钮类型”旁边的帮助按钮，验证其描述文本与当前选中的旋钮类型完美匹配。
5. **本地化测试**：在英文与中文系统下，分别验证气泡中的提示文案是否正确载入本地化翻译。
