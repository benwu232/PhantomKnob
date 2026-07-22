# 2026-07-23 用户指南第一页设备检测与旋钮手势引导动画设计文档

本文档描述在用户指南（User Guide）第一页中，当进入“设备检测与基本旋钮操作”步骤时，增加光标移动引导动画与双指旋转轨迹引导动画的技术实现方案，帮助用户更直观地学习并掌握双指旋转手势。

## 1. 业务目标与用户体验 (Goals & UX)

* **精确的操作路径引导**：将原本静态的手部绘图替换为两个具有强视觉引导作用的动态阶段：
  * **第一阶段：引导鼠标移入**。当鼠标未处于练习旋钮上方时，显示一个从右下角向旋钮中心平滑滑动的半透明鼠标光标动画。
  * **第二阶段：引导双指旋转**。一旦鼠标悬停至旋钮上方，光标动画隐去，立即切换为两个对称的蓝色“触控点”及旋转弧线轨道，模拟两指贴合触控板并作往复旋转的微动动画。
* **零干扰的实际操作体验**：一旦用户手指开始接触触控板（即手势状态变为 active），所有引导动画立即淡出消失，避免遮挡和干扰用户的实际操作。

---

## 2. 技术设计与组件实现 (Technical Design)

### 2.1 交互状态流控制

在 `UserGuideView.swift` 中，结合 `UserGuideViewModel` 的如下状态控制动画的显示和隐藏：
* `viewModel.hovered`: 鼠标当前是否悬浮在音量练习旋钮上方。
* `viewModel.isGestureActive`: 用户当前是否在触控板上作双指旋转操作（手指是否贴合在触控板上）。
* `viewModel.isTouchpadDetected`: 触控板绝对坐标能力是否检测成功。

状态切换逻辑如下表所示：

| `isTouchpadDetected` | `isGestureActive` | `hovered` | 展示内容 |
| :--- | :--- | :--- | :--- |
| `true` | - | - | **无引导动画**（已检测成功，提示下一步） |
| `false` | `true` | - | **无引导动画**（用户正在旋转，隐去干扰） |
| `false` | `false` | `false` | **阶段一动画** (`CursorGuideAnimationView`) |
| `false` | `false` | `true` | **阶段二动画** (`TwoFingerRotationGuideView`) |

### 2.2 核心组件变更

#### [MODIFY] [UserGuideView.swift](file:///Users/wb/work/phantom_knob_mac/PhantomKnob/View/UserGuideView.swift)

1. **重构 `CursorGuideAnimationView`**：
   * 将原来的静态缩放/偏移手势图换成从右下角往旋钮圆心平移的光标幻影。
2. **新增 `TwoFingerRotationGuideView`**：
   * 实现一个由两条对称运动的蓝色触控点、旋转圆弧虚线轨道和中心微旋箭头组成的 SwiftUI 动画视图。
3. **更新 `step1View` 布局**：
   * 在练习旋钮的 `ZStack` 容器内嵌入状态控制的条件渲染。

---

## 3. 核心代码设计参考

### 3.1 `CursorGuideAnimationView` 结构
```swift
struct CursorGuideAnimationView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "cursorarrow")
            .font(.system(size: 28))
            .foregroundColor(.blue)
            .shadow(color: .blue.opacity(0.4), radius: 4)
            .offset(x: isAnimating ? 25 : 85, y: isAnimating ? -25 : -85)
            .opacity(isAnimating ? 1.0 : 0.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}
```

### 3.2 `TwoFingerRotationGuideView` 结构
```swift
struct TwoFingerRotationGuideView: View {
    @State private var rotationAngle: Double = -25.0
    
    private let skinColorStart = Color(red: 252/255, green: 230/255, blue: 210/255)
    private let skinColorEnd = Color(red: 220/255, green: 163/255, blue: 130/255)
    
    var body: some View {
        ZStack {
            // 背景圆环轨道
            Circle()
                .stroke(
                    Color.white.opacity(0.12),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 6])
                )
                .frame(width: 90, height: 90)
            
            // 触控点 1（肉色指尖）
            Circle()
                .fill(
                    RadialGradient(
                        colors: [skinColorStart, skinColorEnd],
                        center: .center,
                        startRadius: 0,
                        endRadius: 8
                    )
                )
                .frame(width: 16, height: 16)
                .shadow(color: skinColorEnd.opacity(0.4), radius: 3, x: 0, y: 1.5)
                .offset(y: -45)
                .rotationEffect(.degrees(rotationAngle))
            
            // 触控点 2（肉色指尖）
            Circle()
                .fill(
                    RadialGradient(
                        colors: [skinColorStart, skinColorEnd],
                        center: .center,
                        startRadius: 0,
                        endRadius: 8
                    )
                )
                .frame(width: 16, height: 16)
                .shadow(color: skinColorEnd.opacity(0.4), radius: 3, x: 0, y: 1.5)
                .offset(y: 45)
                .rotationEffect(.degrees(rotationAngle))
        }
        .frame(width: 120, height: 120)
        .scaleEffect(1.2) // 放大 1.2 倍以贴合聚焦状态下的旋钮圆周
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.6)
                .repeatForever(autoreverses: true)
            ) {
                rotationAngle = 25.0
            }
        }
    }
}
```

---

## 4. 验证计划 (Verification Plan)

### 4.1 自动测试
* 运行 `xcodebuild test` 验证已有测试集无 Regression。

### 4.2 手动验证
1. 打开新手指南进入第 1 步。
2. 验证鼠标在旋钮外部时，是否循环播放光标从右下向圆心滑动的动画。
3. 将鼠标移动到旋钮上方，验证光标动画是否立即切换为双指旋转轨迹动画。
4. 手指贴上触控板，验证所有引导动画是否立即消失；手指抬起后（如未完成检测）动画是否恢复显示。
5. 完成手势检测（3次样本），验证状态指示条变为绿色成功打勾状态，且任何引导动画均不再出现。
