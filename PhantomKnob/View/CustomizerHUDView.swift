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
        VStack(alignment: .leading, spacing: 14) {
            // 控件标识卡片 (Metadata Card)
            HStack(spacing: 12) {
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "app.badge")
                        .resizable()
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.displayName.isEmpty ? "未命名控件" : target.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    Text("\(appName) · \(target.axRole)")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if let radius = liveRadius {
                    Text("\(Int(radius)) mm")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            Divider().background(Color.white.opacity(0.1))
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. 旋钮类型 (置于最顶)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("旋钮类型")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                        Picker("", selection: $configType) {
                            Text("单旋钮").tag(KnobConfigType.single)
                            Text("双旋钮").tag(KnobConfigType.double)
                            Text("线性半径").tag(KnobConfigType.linear)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: configType) { _ in save() }
                    }
                    
                    // 2. 不同模式子表单 (内含配色)
                    switch configType {
                    case .single:
                        singleSubForm
                    case .double:
                        doubleSubForm
                    case .linear:
                        linearSubForm
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // 3. 控件定位元数据 (Uniquely Identifying Info)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("控件定位唯一标识")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 4) {
                            metadataRow(label: "应用 ID (Bundle ID)", value: target.bundleID)
                            metadataRow(label: "元素角色 (AXRole)", value: target.axRole)
                            metadataRow(label: "元素标识 (AXIdentifier)", value: target.identifier ?? "全局匹配 (匹配该 App 内所有此类控件)")
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(8)
                    }

                    if !target.parentChain.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(hasConflict ? "⚠️ 控件标识冲突 (已自动启用层级定位匹配)" : "层级定位特征 (可勾选以进行深度精确定位)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(hasConflict ? .yellow : .gray)
                            
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
                                        
                                        Text("\(parent.displayName ?? "未命名容器") (\(parent.axRole))")
                                            .font(.system(size: 10))
                                            .foregroundColor(idx == lockedDiffIndex ? .green : .white)
                                        
                                        if idx == lockedDiffIndex {
                                            Text("💡 分叉区分点")
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
            }
        }
        .padding(16)
        .onAppear {
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
    }
    
    // MARK: - 模式子表单实现
    
    private var singleSubForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 配色定制
            VStack(alignment: .leading, spacing: 6) {
                Text("主题颜色")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                
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
                        Text("自定义颜色...")
                            .font(.system(size: 11))
                        Spacer()
                        Text(themeColor)
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
            .padding(.bottom, 6)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("最小响应半径").font(.system(size: 11)).foregroundColor(.gray)
                    Spacer()
                    Text("\(Int(singleMinRadius)) mm")
                        .font(.system(size: 11, design: .monospaced))
                }
                Slider(value: $singleMinRadius, in: 5.0...15.0, step: 1.0)
                    .onChange(of: singleMinRadius) { _ in
                        save()
                    }
            }
            .padding(.bottom, 6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("输出映射方式")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
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
                Text("顺时针旋转时触发")
                    .font(.system(size: 11))
                Picker("", selection: $singleCWAction) {
                    ForEach(directionOptions(for: singleTranslation), id: \.self) { opt in
                        Text(actionDescription(opt)).tag(opt)
                    }
                }
                .onChange(of: singleCWAction) { _ in save() }
            }
            
            HStack {
                Text("步长(每度旋转对应的输出变化量)")
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
    
    private var doubleSubForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ⚙️ 切换边界与迟滞范围
            VStack(alignment: .leading, spacing: 10) {
                Text("⚙️ 切换边界与迟滞范围")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("切换边界半径 (Boundary)").font(.system(size: 11))
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
                        Text("迟滞带宽度 (Margin)").font(.system(size: 11))
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
            
            // 外圈旋钮 (粗调) 配置卡片
            VStack(alignment: .leading, spacing: 8) {
                Text("🟠 外圈旋钮")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.orange)
                
                // 外圈配色
                VStack(alignment: .leading, spacing: 6) {
                    Text("主题颜色")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                    
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
                            Text("自定义外圈颜色...")
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
                .padding(.bottom, 4)
                
                HStack {
                    Text("响应半径").font(.system(size: 11))
                    Spacer()
                    Text("> \(Int(doubleInnerRadiusMax)) mm")
                        .font(.system(size: 11, design: .monospaced))
                }
                
                Picker("输出映射", selection: $doubleOuterTranslation) {
                    ForEach(InputTranslation.allCases, id: \.self) { trans in
                        Text(transDescription(trans)).tag(trans)
                    }
                }
                .onChange(of: doubleOuterTranslation) { next in
                    doubleOuterCWAction = defaultAction(for: next)
                    save()
                }
                
                Picker("顺时针触发", selection: $doubleOuterCWAction) {
                    ForEach(directionOptions(for: doubleOuterTranslation), id: \.self) { opt in
                        Text(actionDescription(opt)).tag(opt)
                    }
                }
                .onChange(of: doubleOuterCWAction) { _ in save() }
                
                HStack {
                    Text("步长(每度旋转对应的输出变化量)")
                        .font(.system(size: 11))
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
            }
            .padding(8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            // 内圈旋钮 (微调) 配置卡片
            VStack(alignment: .leading, spacing: 8) {
                Text("🟢 内圈旋钮")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.green)
                
                // 内圈配色
                VStack(alignment: .leading, spacing: 6) {
                    Text("主题颜色")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                    
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
                            Text("自定义内圈颜色...")
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
                .padding(.bottom, 4)
                
                HStack {
                    Text("响应半径").font(.system(size: 11))
                    Spacer()
                    Text("\(Int(doubleInnerMinRadius)) mm ~ \(Int(doubleInnerRadiusMax)) mm")
                        .font(.system(size: 11, design: .monospaced))
                }
                
                Slider(value: $doubleInnerMinRadius, in: 5.0...15.0, step: 1.0)
                    .onChange(of: doubleInnerMinRadius) { _ in
                        save()
                    }
                
                Picker("输出映射", selection: $doubleInnerTranslation) {
                    ForEach(InputTranslation.allCases, id: \.self) { trans in
                        Text(transDescription(trans)).tag(trans)
                    }
                }
                .onChange(of: doubleInnerTranslation) { next in
                    doubleInnerCWAction = defaultAction(for: next)
                    save()
                }
                
                Picker("顺时针触发", selection: $doubleInnerCWAction) {
                    ForEach(directionOptions(for: doubleInnerTranslation), id: \.self) { opt in
                        Text(actionDescription(opt)).tag(opt)
                    }
                }
                .onChange(of: doubleInnerCWAction) { _ in save() }
                
                HStack {
                    Text("步长(每度旋转对应的输出变化量)")
                        .font(.system(size: 11))
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
            .padding(8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private var linearSubForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 配色定制
            VStack(alignment: .leading, spacing: 6) {
                Text("主题颜色")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
                
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
                        Text("自定义颜色...")
                            .font(.system(size: 11))
                        Spacer()
                        Text(themeColor)
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
            .padding(.bottom, 6)
            
            Picker("输出映射", selection: $linearTranslation) {
                ForEach(InputTranslation.allCases, id: \.self) { trans in
                    Text(transDescription(trans)).tag(trans)
                }
            }
            .onChange(of: linearTranslation) { next in
                linearCWAction = defaultAction(for: next)
                save()
            }
            
            Picker("顺时针触发", selection: $linearCWAction) {
                ForEach(directionOptions(for: linearTranslation), id: \.self) { opt in
                    Text(actionDescription(opt)).tag(opt)
                }
            }
            .onChange(of: linearCWAction) { _ in save() }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("响应半径范围").font(.system(size: 11, weight: .semibold))
                HStack {
                    Text("最小半径: \(Int(linearMinRadius)) mm")
                    Spacer()
                    Slider(value: $linearMinRadius, in: 5.0...20.0, step: 1.0)
                        .frame(width: 180)
                        .onChange(of: linearMinRadius) { _ in save() }
                }
                HStack {
                    Text("最大半径: \(Int(linearMaxRadius)) mm")
                    Spacer()
                    Slider(value: $linearMaxRadius, in: 25.0...50.0, step: 1.0)
                        .frame(width: 180)
                        .onChange(of: linearMaxRadius) { _ in save() }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("步长(每度旋转对应的输出变化量)范围").font(.system(size: 11, weight: .semibold))
                HStack {
                    Text("最小变化量:")
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
                HStack {
                    Text("最大变化量:")
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
        self.doubleInnerScale = 0.2
        self.doubleInnerScaleText = "0.2"
        self.doubleInnerTranslation = .arrowKeyUpDown
        self.doubleInnerCWAction = "arrowUp"
        self.doubleInnerThemeColor = "#30D158"
        self.doubleInnerMinRadius = 10.0
        
        self.doubleMargin = 2.0
        
        self.doubleOuterRadiusMin = 25.0
        self.doubleOuterRadiusMax = 100.0
        self.doubleOuterScale = 1.5
        self.doubleOuterScaleText = "1.5"
        self.doubleOuterTranslation = .scrollWheelVertical
        self.doubleOuterCWAction = "scrollUp"
        self.doubleOuterThemeColor = "#FF9F0A"
        
        self.linearMinRadius = 10.0
        self.linearMaxRadius = 35.0
        self.linearMinScale = 0.1
        self.linearMinScaleText = "0.1"
        self.linearMaxScale = 3.0
        self.linearMaxScaleText = "3.0"
        self.linearTranslation = .scrollWheelVertical
        self.linearCWAction = "scrollUp"
        
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
            }
        }
        onLoadExisting?(self.configType, self.themeColor)
        
        DispatchQueue.main.async {
            self.isLoadingConfig = false
        }
    }
    
    private func save() {
        guard !isLoadingConfig else { return }
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
                outer: VirtualKnobConfig(minRadius: doubleInnerRadiusMax, maxRadius: doubleOuterRadiusMax, margin: doubleMargin, unitPerDegree: doubleOuterScale, translation: doubleOuterTranslation, clockwiseAction: doubleOuterCWAction, themeColor: doubleOuterThemeColor)
            )
        case .linear:
            rule.linearConfig = LinearKnobConfig(
                minRadius: linearMinRadius,
                maxRadius: linearMaxRadius,
                minScale: linearMinScale,
                maxScale: linearMaxScale,
                translation: linearTranslation,
                clockwiseAction: linearCWAction
            )
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
                .foregroundColor(.gray)
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

