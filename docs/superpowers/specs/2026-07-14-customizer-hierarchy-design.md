# 旋钮定制面板行为项层级层叠与缩进优化设计规范

## 1. 业务目标
为了在定制面板 (Customizer HUD) 中清晰地反映参数之间的逻辑从属关系，对行为属性表单做如下层级展现优化：
1. **就近从属层级设计**：“映射方向 (Clockwise Action)” 仅在 “映射方式 (Output Translation)” 确立后才有物理意义。因此，将“映射方向”在视觉上作为“映射方式”的子属性进行排布。
2. **引导符与缩进层级 (↳ Connector & Indentation)**：
   - **首行缩进**：将“映射方向”的整个输入控制块（包含标签、提示问号和 Picker 容器）整体向右侧缩进 `12pt`。
   - **连接引导符**：在“映射方向”的标签最前方添加低不透明度（`.opacity(0.5)`）的折角箭头 `↳` 引导符，视觉上指向父级“映射方式”。

---

## 2. 界面设计 (UI/UX)
- 在 `singleBehaviorForm`、`doubleBehaviorForm` 以及 `linearBehaviorForm` 三个行为属性子表单中：
  - 映射方向的 Label HStack 头部增加：
    ```swift
    Text("↳")
        .font(.hudLabel)
        .foregroundColor(.hudSecondary.opacity(0.5))
    ```
  - 映射方向的整个 VStack 最下方附加：
    ```swift
    .padding(.leading, 12)
    ```

---

## 3. 详细设计 (Detailed Design)

### 3.1 行为子表单重构示例 (以 singleBehaviorForm 为例)
```swift
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("↳")
                        .font(.hudLabel)
                        .foregroundColor(.hudSecondary.opacity(0.5))
                    Text(String(localized: "hud.clockwiseAction", defaultValue: "Clockwise Action"))
                        .font(.hudLabel)
                        .foregroundColor(.hudSecondary)
                    HUDHelpButton(content: String(localized: "hud.clockwiseAction.help", defaultValue: "Event triggered when rotating the knob clockwise."))
                }
                Picker("", selection: $singleCWAction) {
                    ForEach(directionOptions(for: singleTranslation), id: \.self) { opt in
                        Text(actionDescription(opt)).tag(opt)
                    }
                }
                .onChange(of: singleCWAction) { _ in save() }
            }
            .padding(.leading, 12)
```

---

## 4. 验证计划

### 4.1 手工联调测试
1. 呼出定制面板，进入行为属性部分。
2. 验证“映射方向”的标题前均有灰色的 `↳` 符号引导。
3. 验证“映射方向”的 Picker 及整体模块向右缩进了 `12pt`。
4. 验证缩进后没有引发 HUD 面板的横向溢出或剪裁。
