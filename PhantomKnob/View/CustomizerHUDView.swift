import SwiftUI
import AppKit

struct CustomizerHUDView: View {
    let target: DetectedTarget
    var onLoadExisting: ((KnobConfigType, String) -> Void)? = nil
    
    @State private var themeColor: String = "#0A84FF"
    @State private var configType: KnobConfigType = .single
    @State private var isLoadingConfig: Bool = false

    // 冲突与分叉锁定状态
    @State private var hasConflict: Bool = false
    @State private var selectedParents: Set<Int> = [] // 选中的 parentChain 索引集合
    @State private var lockedDiffIndex: Int? = nil    // 自动锁定的分叉点索引
    @State private var isFirstLoad: Bool = true
    
    @State private var linearOuterColor: String = "#FF9F0A"
    @State private var linearInnerColor: String = "#30D158"
    @State private var isAdvancedExpanded: Bool = false

    private var currentRuleKey: RuleKey {
        let chain = target.parentChain.enumerated().filter {
            selectedParents.contains($0.offset)
        }.map { $0.element }
        return RuleKey(
            bundleID: target.bundleID,
            axRole: target.axRole,
            identifier: target.identifier,
            displayName: target.displayName,
            parentChain: chain.isEmpty ? nil : chain
        )
    }


    
    // 单旋钮
    @State private var singleScale: Double = 1.0
    @State private var singleScaleText: String = "1.0"
    @State private var singleTranslation: InputTranslation = .scrollWheelVertical
    @State private var singleCWAction: String = "scrollUp"
    @State private var singleMinRadius: Double = 10.0
    
    // 双旋钮
    @State private var doubleInnerRadiusMax: Double = 25.0
    @State private var doubleInnerScale: Double = 0.2
    @State private var doubleInnerScaleText: String = "0.2"
    @State private var doubleInnerTranslation: InputTranslation = .arrowKeyUpDown
    @State private var doubleInnerCWAction: String = "arrowUp"
    @State private var doubleInnerMinRadius: Double = 10.0
    
    @State private var doubleMargin: Double = 2.0
    
    @State private var doubleOuterRadiusMin: Double = 27.0
    @State private var doubleOuterRadiusMax: Double = 100.0
    @State private var doubleOuterScale: Double = 1.5
    @State private var doubleOuterScaleText: String = "1.5"
    @State private var doubleOuterTranslation: InputTranslation = .scrollWheelVertical
    @State private var doubleOuterCWAction: String = "scrollUp"
    
    // 线性
    @State private var linearMinRadius: Double = 10.0
    @State private var linearMaxRadius: Double = 35.0
    @State private var linearMinScale: Double = 0.1
    @State private var linearMinScaleText: String = "0.1"
    @State private var linearMaxScale: Double = 3.0
    @State private var linearMaxScaleText: String = "3.0"
    @State private var linearTranslation: InputTranslation = .scrollWheelVertical
    @State private var linearCWAction: String = "scrollUp"
    
    // 物理半径实时指示
    @State private var liveRadius: Double? = nil
    @State private var isPinned: Bool = false
    @State private var commonMinRadius: Double = 10.0
    
    // 双旋钮配色
    @State private var doubleInnerThemeColor: String = "#30D158"
    @State private var doubleOuterThemeColor: String = "#FF9F0A"
    @State private var activeColorTarget: ColorTarget = .global
    
    enum ColorTarget {
        case global
        case doubleInner
        case doubleOuter
    }
    
    let colors = [
        "#FF453A", "#FF9F0A", "#FFD60A", "#30D158",
        "#64D2FF", "#0A84FF", "#5E5CE6", "#BF5AF2",
        "#FF375F", "#FF6482", "#34C759", "#00C7BE",
        "#FF9500", "#AF52DE", "#555555", "#FFFFFF"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 控件标识卡片 (Metadata Card) 兼顶栏（含左上角显式关闭按钮）
            HStack(spacing: 10) {
                Button(action: {
                    CustomizerHUDWindowController.shared.hide()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.65))
                }
                .buttonStyle(PlainButtonStyle())
                
                // 🌟 使用 PhantomKnob 品牌标识图标与标题
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 18, height: 18)
                } else {
                    Image(systemName: "slider.horizontal.3")
                        .resizable()
                        .foregroundColor(.orange)
                        .frame(width: 16, height: 16)
                }
                
                Text(String(localized: "hud.title.customizer", defaultValue: "PhantomKnob 旋钮定制"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if let radius = liveRadius {
                    Text("\(Int(radius)) mm")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                
                Button(action: {
                    isPinned.toggle()
                    CustomizerHUDWindowController.shared.isPinned = isPinned
                }) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isPinned ? .blue : .white.opacity(0.65))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // ① 旋钮类型
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "hud.knobType", defaultValue: "旋钮类型"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Picker("", selection: $configType) {
                            Text(String(localized: "hud.single", defaultValue: "Single Knob")).tag(KnobConfigType.single)
                            Text(String(localized: "hud.double", defaultValue: "Double-Ring")).tag(KnobConfigType.double)
                            Text(String(localized: "hud.linear", defaultValue: "Variable Speed")).tag(KnobConfigType.linear)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: configType) { _ in
                            // 切换类型时，自动将当前公共响应半径带入新类型并保存
                            save()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(String(localized: "hud.minRadius", defaultValue: "最小响应半径")).font(.system(size: 11)).foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(commonMinRadius)) mm")
                                .font(.system(size: 11, design: .monospaced))
                        }
                        Slider(value: $commonMinRadius, in: 5.0...15.0, step: 1.0)
                            .onChange(of: commonMinRadius) { _ in
                                save()
                            }
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // ② 旋钮外观
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "hud.section.appearance", defaultValue: "旋钮外观"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        
                        switch configType {
                        case .single:
                            singleAppearanceForm
                        case .double:
                            doubleAppearanceForm
                        case .linear:
                            linearAppearanceForm
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // ③ 旋钮行为
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "hud.section.behavior", defaultValue: "旋钮行为"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        
                        switch configType {
                        case .single:
                            singleBehaviorForm
                        case .double:
                            doubleBehaviorForm
                        case .linear:
                            linearBehaviorForm
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.08))
                    
                    // ④ 辅助信息
                    DisclosureGroup(isExpanded: $isAdvancedExpanded) {
                        VStack(alignment: .leading, spacing: 12) {
                            // 被控应用品牌标识移入辅助信息首行
                            HStack(spacing: 8) {
                                if let icon = appIcon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "app.badge")
                                        .resizable()
                                        .foregroundColor(.white.opacity(0.5))
                                        .frame(width: 20, height: 20)
                                }
                                Text(appName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 6)
                            
                            // 控件定位元数据
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(localized: "hud.locatingIdentifier", defaultValue: "Element Locating Identifier"))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 4) {
                                    metadataRow(label: String(localized: "hud.bundleID", defaultValue: "Bundle ID"), value: target.bundleID)
                                    metadataRow(label: String(localized: "hud.axRole", defaultValue: "AXRole"), value: target.axRole)
                                    metadataRow(label: String(localized: "hud.axIdentifier", defaultValue: "AXIdentifier"), value: target.identifier ?? String(localized: "hud.globalMatch", defaultValue: "Global match"))
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(8)
                            }
                            
                            // 层级链冲突与分叉点配置
                            if !target.parentChain.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(hasConflict 
                                         ? String(localized: "hud.conflictDetected", defaultValue: "⚠️ Element conflict detected (Hierarchy match enabled)") 
                                         : String(localized: "hud.hierarchyFeatures", defaultValue: "Hierarchy features (Check to enable precise targeting)"))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(hasConflict ? .yellow : .secondary)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(0..<target.parentChain.count, id: \.self) { idx in
                                            let parent = target.parentChain[idx]
                                            HStack(spacing: 6) {
                                                Toggle("", isOn: Binding(
                                                    get: { self.selectedParents.contains(idx) },
                                                    set: { isCheck in
                                                        if idx == lockedDiffIndex { return } // 强制锁定的分叉点禁止取消
                                                        if isCheck {
                                                            self.selectedParents.insert(idx)
                                                        } else {
                                                            self.selectedParents.remove(idx)
                                                        }
                                                        loadExisting()
                                                    }
                                                ))
                                                .toggleStyle(.checkbox)
                                                .disabled(idx == lockedDiffIndex)
                                                
                                                Text("\(parent.displayName ?? String(localized: "hud.unnamedControl", defaultValue: "Unnamed Control")) (\(parent.axRole))")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(idx == lockedDiffIndex ? .green : .white)
                                                
                                                if idx == lockedDiffIndex {
                                                    Text(String(localized: "hud.splitDifference", defaultValue: "💡 Split difference point"))
                                                        .font(.system(size: 8))
                                                        .foregroundColor(.green)
                                                        .padding(.horizontal, 4)
                                                        .background(Color.green.opacity(0.1))
                                                        .cornerRadius(4)
                                                }
                                            }
                                            .padding(.vertical, 2)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.top, 4)
                    } label: {
                        Text(String(localized: "hud.section.helper", defaultValue: "辅助信息"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        
        // 底部滚动淡出羽化渐变阴影蒙层，提示用户下方还有未展示内容
        LinearGradient(
            gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.4)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 12)
        .padding(.top, -12)
        .allowsHitTesting(false)
    }
    .padding(16)
        .onAppear {
            self.isPinned = CustomizerHUDWindowController.shared.isPinned
            loadExisting()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CustomizerRadiusDidUpdate"))) { notification in
            if let r = notification.userInfo?["radius"] as? Double {
                self.liveRadius = r
            } else {
                self.liveRadius = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSColorPanel.colorDidChangeNotification)) { notification in
            print("[CustomizerHUDView] NSColorPanel.colorDidChangeNotification received, object: \(String(describing: notification.object))")
            if let panel = notification.object as? NSColorPanel {
                let color = panel.color
                print("[CustomizerHUDView] panel color: \(color), hex: \(String(describing: color.toHex()))")
                if let hex = color.toHex() {
                    switch activeColorTarget {
                    case .global:
                        self.themeColor = hex
                    case .doubleInner:
                        self.doubleInnerThemeColor = hex
                    case .doubleOuter:
                        self.doubleOuterThemeColor = hex
                    }
                    save()
                }
            }
        }
        .onChange(of: target.ruleKey) { _ in
            loadExisting()
        }
        .onDisappear {
            save()
        }
    }
    
    // MARK: - WYSIWYG 预览组件与手势


    
    // MARK: - 模式子表单实现
    
    // MARK: - 外观子表单实现
    
    private var singleAppearanceForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 配色定制
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "hud.themeColor", defaultValue: "Theme Color"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.65))
                
                HStack(spacing: 5) {
                    ForEach(colors, id: \.self) { colorHex in
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: themeColor == colorHex ? 1.5 : 0)
                            )
                            .onTapGesture {
                                themeColor = colorHex
                                save()
                            }
                    }
                }
                
                Button(action: {
                    activeColorTarget = .global
                    NSColorPanel.shared.color = NSColor(Color(hex: themeColor))
                    NSColorPanel.shared.orderFront(nil)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: themeColor))
                        Text(String(localized: "hud.customColor", defaultValue: "Custom Color…"))
                            .font(.system(size: 11))
                        Spacer()
                        Text(themeColor)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var doubleAppearanceForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ⚙️ 边界与迟滞范围
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "hud.doubleBoundarySettings", defaultValue: "⚙️ Boundary & Hysteresis Margin"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "hud.boundaryRadius", defaultValue: "Boundary Radius")).font(.system(size: 11))
                        Spacer()
                        Text("\(Int(doubleInnerRadiusMax)) mm")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    Slider(value: $doubleInnerRadiusMax, in: 10.0...40.0, step: 1.0)
                        .onChange(of: doubleInnerRadiusMax) { next in
                            doubleOuterRadiusMin = next
                            save()
                        }
                    
                    HStack {
                        Text(String(localized: "hud.hysteresisMargin", defaultValue: "Hysteresis Margin")).font(.system(size: 11))
                        Spacer()
                        Text("\(Int(doubleMargin)) mm")
                            .font(.system(size: 11, design: .monospaced))
                    }
                    Slider(value: $doubleMargin, in: 0.0...10.0, step: 1.0)
                        .onChange(of: doubleMargin) { next in
                            save()
                        }
                }
                .padding(10)
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            
            // 外圈配色
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "hud.doubleOuterColor", defaultValue: "🟠 外环颜色"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
                
                HStack(spacing: 5) {
                    ForEach(colors, id: \.self) { colorHex in
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: doubleOuterThemeColor == colorHex ? 1.5 : 0)
                            )
                            .onTapGesture {
                                doubleOuterThemeColor = colorHex
                                save()
                            }
                    }
                }
                
                Button(action: {
                    activeColorTarget = .doubleOuter
                    NSColorPanel.shared.color = NSColor(Color(hex: doubleOuterThemeColor))
                    NSColorPanel.shared.orderFront(nil)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: doubleOuterThemeColor))
                        Text(String(localized: "hud.customOuterColor", defaultValue: "Custom outer color..."))
                            .font(.system(size: 11))
                        Spacer()
                        Text(doubleOuterThemeColor)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 内圈配色
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "hud.doubleInnerColor", defaultValue: "🟢 内环颜色"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.green)
                
                HStack(spacing: 5) {
                    ForEach(colors, id: \.self) { colorHex in
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: doubleInnerThemeColor == colorHex ? 1.5 : 0)
                            )
                            .onTapGesture {
                                doubleInnerThemeColor = colorHex
                                save()
                            }
                    }
                }
                
                Button(action: {
                    activeColorTarget = .doubleInner
                    NSColorPanel.shared.color = NSColor(Color(hex: doubleInnerThemeColor))
                    NSColorPanel.shared.orderFront(nil)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: doubleInnerThemeColor))
                        Text(String(localized: "hud.customInnerColor", defaultValue: "Custom inner color..."))
                            .font(.system(size: 11))
                        Spacer()
                        Text(doubleInnerThemeColor)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var linearAppearanceForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 外圈配色
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "hud.linearOuterColor", defaultValue: "🟠 外环颜色"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.orange)
                
                HStack(spacing: 5) {
                    ForEach(colors, id: \.self) { colorHex in
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: linearOuterColor == colorHex ? 1.5 : 0)
                            )
                            .onTapGesture {
                                linearOuterColor = colorHex
                                save()
                            }
                    }
                }
                
                Button(action: {
                    activeColorTarget = .global
                    NSColorPanel.shared.color = NSColor(Color(hex: linearOuterColor))
                    NSColorPanel.shared.orderFront(nil)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: linearOuterColor))
                        Text(String(localized: "hud.customOuterColor", defaultValue: "Custom outer color..."))
                            .font(.system(size: 11))
                        Spacer()
                        Text(linearOuterColor)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 内圈配色
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "hud.linearInnerColor", defaultValue: "🟢 内环颜色"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.green)
                
                HStack(spacing: 5) {
                    ForEach(colors, id: \.self) { colorHex in
                        Circle()
                            .fill(Color(hex: colorHex))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: linearInnerColor == colorHex ? 1.5 : 0)
                            )
                            .onTapGesture {
                                linearInnerColor = colorHex
                                save()
                            }
                    }
                }
                
                Button(action: {
                    activeColorTarget = .doubleInner
                    NSColorPanel.shared.color = NSColor(Color(hex: linearInnerColor))
                    NSColorPanel.shared.orderFront(nil)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: linearInnerColor))
                        Text(String(localized: "hud.customInnerColor", defaultValue: "Custom inner color..."))
                            .font(.system(size: 11))
                        Spacer()
                        Text(linearInnerColor)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 最大显示半径
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    let text = String(format: String(localized: "hud.maxRadiusLabel", defaultValue: "最大显示半径: %d mm"), Int(linearMaxRadius))
                    Text(text).font(.system(size: 11))
                    Spacer()
                    Slider(value: $linearMaxRadius, in: 25.0...50.0, step: 1.0)
                        .frame(width: 180)
                        .onChange(of: linearMaxRadius) { _ in save() }
                }
            }
        }
    }
    
    // MARK: - 行为子表单实现
    
    private var singleBehaviorForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "hud.outputTranslation", defaultValue: "Output Translation"))
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                Picker("", selection: $singleTranslation) {
                    ForEach(InputTranslation.allCases, id: \.self) { trans in
                        Text(transDescription(trans)).tag(trans)
                    }
                }
                .onChange(of: singleTranslation) { next in
                    singleCWAction = defaultAction(for: next)
                    save()
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "hud.clockwiseAction", defaultValue: "Clockwise Action"))
                    .font(.system(size: 11))
                Picker("", selection: $singleCWAction) {
                    ForEach(directionOptions(for: singleTranslation), id: \.self) { opt in
                        Text(actionDescription(opt)).tag(opt)
                    }
                }
                .onChange(of: singleCWAction) { _ in save() }
            }
            
            HStack {
                Text(String(localized: "hud.unitPerDegree", defaultValue: "Unit per degree"))
                    .font(.system(size: 11))
                Spacer()
                TextField("", text: $singleScaleText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: singleScaleText) { next in
                        if let val = Double(next) {
                            singleScale = val
                            save()
                        }
                    }
            }
        }
    }
    
    private var doubleBehaviorForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(String(localized: "hud.outputTranslationPicker", defaultValue: "Output Translation"), selection: $doubleInnerTranslation) {
                ForEach(InputTranslation.allCases, id: \.self) { trans in
                    Text(transDescription(trans)).tag(trans)
                }
            }
            .onChange(of: doubleInnerTranslation) { next in
                doubleInnerCWAction = defaultAction(for: next)
                save()
            }
            
            Picker(String(localized: "hud.clockwiseActionPicker", defaultValue: "Clockwise Action"), selection: $doubleInnerCWAction) {
                ForEach(directionOptions(for: doubleInnerTranslation), id: \.self) { opt in
                    Text(actionDescription(opt)).tag(opt)
                }
            }
            .onChange(of: doubleInnerCWAction) { _ in save() }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(localized: "hud.doubleOuterScaleLabel", defaultValue: "外环灵敏度:"))
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Spacer()
                    TextField("", text: $doubleOuterScaleText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: doubleOuterScaleText) { next in
                            if let val = Double(next) {
                                doubleOuterScale = val
                                save()
                            }
                        }
                }
                
                HStack {
                    Text(String(localized: "hud.doubleInnerScaleLabel", defaultValue: "内环灵敏度:"))
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Spacer()
                    TextField("", text: $doubleInnerScaleText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: doubleInnerScaleText) { next in
                            if let val = Double(next) {
                                doubleInnerScale = val
                                save()
                            }
                        }
                }
            }
        }
    }
    
    private var linearBehaviorForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(String(localized: "hud.outputTranslationPicker", defaultValue: "Output Translation"), selection: $linearTranslation) {
                ForEach(InputTranslation.allCases, id: \.self) { trans in
                    Text(transDescription(trans)).tag(trans)
                }
            }
            .onChange(of: linearTranslation) { next in
                linearCWAction = defaultAction(for: next)
                save()
            }
            
            Picker(String(localized: "hud.clockwiseActionPicker", defaultValue: "Clockwise Action"), selection: $linearCWAction) {
                ForEach(directionOptions(for: linearTranslation), id: \.self) { opt in
                    Text(actionDescription(opt)).tag(opt)
                }
            }
            .onChange(of: linearCWAction) { _ in save() }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(localized: "hud.linearInnerScaleLabel", defaultValue: "最小半径对应灵敏度:"))
                        .font(.system(size: 11))
                    Spacer()
                    TextField("", text: $linearMaxScaleText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: linearMaxScaleText) { next in
                            if let val = Double(next) {
                                linearMaxScale = val
                                save()
                            }
                        }
                }
                HStack {
                    Text(String(localized: "hud.linearOuterScaleLabel", defaultValue: "最大半径对应灵敏度:"))
                        .font(.system(size: 11))
                    Spacer()
                    TextField("", text: $linearMinScaleText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: linearMinScaleText) { next in
                            if let val = Double(next) {
                                linearMinScale = val
                                save()
                            }
                        }
                }
            }
        }
    }
    
    // MARK: - 模型逻辑适配与加载保存
    
    private func resetToDefaults() {
        self.themeColor = "#0A84FF"
        self.configType = .single
        
        self.singleScale = 1.0
        self.singleScaleText = "1.0"
        self.singleTranslation = .scrollWheelVertical
        self.singleCWAction = "scrollUp"
        self.singleMinRadius = 10.0
        
        self.doubleInnerRadiusMax = 25.0
        self.doubleInnerScale = 5.0
        self.doubleInnerScaleText = "5.0"
        self.doubleInnerTranslation = .arrowKeyUpDown
        self.doubleInnerCWAction = "arrowUp"
        self.doubleInnerThemeColor = "#30D158"
        self.doubleInnerMinRadius = 10.0
        
        self.doubleMargin = 2.0
        
        self.doubleOuterRadiusMin = 25.0
        self.doubleOuterRadiusMax = 100.0
        self.doubleOuterScale = 1.0
        self.doubleOuterScaleText = "1.0"
        self.doubleOuterTranslation = .scrollWheelVertical
        self.doubleOuterCWAction = "scrollUp"
        self.doubleOuterThemeColor = "#FF9F0A"
        
        self.linearMinRadius = 10.0
        self.linearMaxRadius = 35.0
        self.linearMinScale = 1.0
        self.linearMinScaleText = "1.0"
        self.linearMaxScale = 30.0
        self.linearMaxScaleText = "30.0"
        self.linearTranslation = .scrollWheelVertical
        self.linearCWAction = "scrollUp"
        self.linearOuterColor = "#FF9F0A"
        self.linearInnerColor = "#30D158"
        
        self.activeColorTarget = .global
    }

    private func loadExisting() {
        isLoadingConfig = true
        resetToDefaults()
        
        // 首次加载时进行冲突比对，并自动计算分叉点
        if isFirstLoad {
            isFirstLoad = false
            detectConflictAndDiff()
        }
        
        if let existing = RuleLibrary.shared.lookup(for: currentRuleKey) {
            self.themeColor = existing.themeColor ?? "#0A84FF"
            self.configType = existing.configType
            
            if let single = existing.singleConfig {
                self.singleScale = single.unitPerDegree
                self.singleScaleText = String(format: "%.4g", single.unitPerDegree)
                self.singleTranslation = single.translation
                self.singleCWAction = single.clockwiseAction
                self.singleMinRadius = single.minRadius ?? 10.0
            }
            if let d = existing.doubleConfig {
                self.doubleInnerRadiusMax = d.inner.maxRadius
                self.doubleInnerScale = d.inner.unitPerDegree
                self.doubleInnerScaleText = String(format: "%.4g", d.inner.unitPerDegree)
                self.doubleInnerTranslation = d.inner.translation
                self.doubleInnerCWAction = d.inner.clockwiseAction
                self.doubleInnerThemeColor = d.inner.themeColor ?? "#30D158"
                self.doubleInnerMinRadius = d.inner.minRadius
                
                self.doubleMargin = d.inner.margin
                
                self.doubleOuterRadiusMin = d.inner.maxRadius
                self.doubleOuterRadiusMax = d.outer.maxRadius
                self.doubleOuterScale = d.outer.unitPerDegree
                self.doubleOuterScaleText = String(format: "%.4g", d.outer.unitPerDegree)
                self.doubleOuterTranslation = d.outer.translation
                self.doubleOuterCWAction = d.outer.clockwiseAction
                self.doubleOuterThemeColor = d.outer.themeColor ?? "#FF9F0A"
            }
            if let l = existing.linearConfig {
                self.linearMinRadius = l.minRadius
                self.linearMaxRadius = l.maxRadius
                self.linearMinScale = l.minScale
                self.linearMinScaleText = String(format: "%.4g", l.minScale)
                self.linearMaxScale = l.maxScale
                self.linearMaxScaleText = String(format: "%.4g", l.maxScale)
                self.linearTranslation = l.translation
                self.linearCWAction = l.clockwiseAction
                self.linearOuterColor = l.outerThemeColor ?? existing.themeColor ?? "#FF9F0A"
                self.linearInnerColor = l.innerThemeColor ?? existing.themeColor ?? "#30D158"
            }
        }
        
        switch self.configType {
        case .single:
            self.commonMinRadius = self.singleMinRadius
        case .double:
            self.commonMinRadius = self.doubleInnerMinRadius
        case .linear:
            self.commonMinRadius = self.linearMinRadius
        }
        
        onLoadExisting?(self.configType, self.themeColor)
        
        DispatchQueue.main.async {
            self.isLoadingConfig = false
        }
    }
    
    private func save() {
        guard !isLoadingConfig else { return }
        
        self.singleMinRadius = self.commonMinRadius
        self.doubleInnerMinRadius = self.commonMinRadius
        self.linearMinRadius = self.commonMinRadius
        
        var rule = ControlRule(key: currentRuleKey, themeColor: themeColor, configType: configType)
        
        switch configType {
        case .single:
            rule.singleConfig = SingleKnobConfig(
                unitPerDegree: singleScale,
                translation: singleTranslation,
                clockwiseAction: singleCWAction,
                minRadius: singleMinRadius
            )
        case .double:
            rule.doubleConfig = DoubleKnobConfig(
                inner: VirtualKnobConfig(minRadius: doubleInnerMinRadius, maxRadius: doubleInnerRadiusMax, margin: doubleMargin, unitPerDegree: doubleInnerScale, translation: doubleInnerTranslation, clockwiseAction: doubleInnerCWAction, themeColor: doubleInnerThemeColor),
                outer: VirtualKnobConfig(minRadius: doubleInnerRadiusMax, maxRadius: doubleOuterRadiusMax, margin: doubleMargin, unitPerDegree: doubleOuterScale, translation: doubleInnerTranslation, clockwiseAction: doubleInnerCWAction, themeColor: doubleOuterThemeColor)
            )
        case .linear:
            rule.linearConfig = LinearKnobConfig(
                minRadius: linearMinRadius,
                maxRadius: linearMaxRadius,
                minScale: linearMinScale,
                maxScale: linearMaxScale,
                translation: linearTranslation,
                clockwiseAction: linearCWAction,
                outerThemeColor: linearOuterColor,
                innerThemeColor: linearInnerColor
            )
            rule.themeColor = linearOuterColor
        }
        
        RuleLibrary.shared.saveRule(rule)
    }

    private func detectConflictAndDiff() {
        // 检查是否有匹配相同基础 Key 的规则存在
        let lookupKey = RuleKey(bundleID: target.bundleID, axRole: target.axRole, identifier: target.identifier, displayName: target.displayName)
        if let existing = RuleLibrary.shared.lookup(for: lookupKey) {
            self.hasConflict = true
            
            // 自动比对两条 parentChain，找出第一个发生变动的层级作为强制绑定的“分叉点”
            let existingChain = existing.key.parentChain ?? []
            var foundDiff = false
            
            for i in 0..<min(existingChain.count, target.parentChain.count) {
                if existingChain[i].axRole != target.parentChain[i].axRole ||
                   existingChain[i].displayName != target.parentChain[i].displayName {
                    self.lockedDiffIndex = i
                    self.selectedParents.insert(i) // 强制勾选分叉点
                    foundDiff = true
                    break
                }
            }
            
            // 若链条长度前缀完全相同，以最近一个有命名的节点作为差异点
            if !foundDiff {
                if let nameIdx = target.parentChain.firstIndex(where: { $0.displayName != nil }) {
                    self.lockedDiffIndex = nameIdx
                    self.selectedParents.insert(nameIdx)
                }
            }
        } else {
            self.hasConflict = false
            self.selectedParents.removeAll()
            self.lockedDiffIndex = nil
        }
    }
    
    // MARK: - 辅助文本解析
    
    private func transDescription(_ trans: InputTranslation) -> String {
        switch trans {
        case .axWrite: return "无障碍直接写入"
        case .scrollWheelVertical: return "垂直滚轮"
        case .scrollWheelHorizontal: return "水平滚轮"
        case .arrowKeyUpDown: return "上下方向键"
        case .arrowKeyLeftRight: return "左右方向键"
        case .swipeVertical: return "双指上下滑动"
        case .swipeHorizontal: return "双指左右滑动"
        }
    }
    
    private func defaultAction(for trans: InputTranslation) -> String {
        switch trans {
        case .arrowKeyUpDown: return "arrowUp"
        case .arrowKeyLeftRight: return "arrowRight"
        case .scrollWheelVertical: return "scrollUp"
        case .scrollWheelHorizontal: return "scrollRight"
        case .swipeVertical: return "swipeUp"
        case .swipeHorizontal: return "swipeRight"
        case .axWrite: return "increase"
        }
    }
    
    private func directionOptions(for trans: InputTranslation) -> [String] {
        switch trans {
        case .arrowKeyUpDown: return ["arrowUp", "arrowDown"]
        case .arrowKeyLeftRight: return ["arrowRight", "arrowLeft"]
        case .scrollWheelVertical: return ["scrollUp", "scrollDown"]
        case .scrollWheelHorizontal: return ["scrollRight", "scrollLeft"]
        case .swipeVertical: return ["swipeUp", "swipeDown"]
        case .swipeHorizontal: return ["swipeRight", "swipeLeft"]
        case .axWrite: return ["increase", "decrease"]
        }
    }
    
    private func actionDescription(_ action: String) -> String {
        switch action {
        case "arrowUp": return "向上按键"
        case "arrowDown": return "向下按键"
        case "arrowRight": return "向右按键"
        case "arrowLeft": return "向左按键"
        case "scrollUp": return "向上滚动"
        case "scrollDown": return "向下滚动"
        case "scrollRight": return "向右滚动"
        case "scrollLeft": return "向左滚动"
        case "swipeUp": return "向上轻扫"
        case "swipeDown": return "向下轻扫"
        case "swipeRight": return "向右轻扫"
        case "swipeLeft": return "向左轻扫"
        case "increase": return "递增值"
        case "decrease": return "递减值"
        default: return action
        }
    }
    
    private var appName: String {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleID) {
            let name = FileManager.default.displayName(atPath: appURL.path)
            return name.replacingOccurrences(of: ".app", with: "")
        }
        return target.bundleID
    }
    
    private var appIcon: NSImage? {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 32, height: 32)
            return icon
        }
        return nil
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }


}

extension NSColor {
    func toHex() -> String? {
        guard let rgbColor = self.usingColorSpace(.sRGB) else { return nil }
        let r = Int(min(max(rgbColor.redComponent, 0.0), 1.0) * 255.0)
        let g = Int(min(max(rgbColor.greenComponent, 0.0), 1.0) * 255.0)
        let b = Int(min(max(rgbColor.blueComponent, 0.0), 1.0) * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension Color {
    func toHex() -> String? {
        return NSColor(self).toHex()
    }
}



