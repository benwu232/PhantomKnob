import SwiftUI
import AppKit

struct CustomizerHUDView: View {
    let target: DetectedTarget
    
    @State private var themeColor: String = "#0A84FF"
    @State private var configType: KnobConfigType = .single
    
    // 单旋钮
    @State private var singleScale: Double = 1.0
    @State private var singleScaleText: String = "1.0"
    @State private var singleTranslation: InputTranslation = .scrollWheelVertical
    @State private var singleCWAction: String = "scrollUp"
    
    // 双旋钮
    @State private var doubleInnerRadiusMax: Double = 25.0
    @State private var doubleInnerScale: Double = 0.2
    @State private var doubleInnerScaleText: String = "0.2"
    @State private var doubleInnerTranslation: InputTranslation = .arrowKeyUpDown
    @State private var doubleInnerCWAction: String = "arrowUp"
    
    @State private var doubleMargin: Double = 2.0
    
    @State private var doubleOuterRadiusMin: Double = 27.0
    @State private var doubleOuterRadiusMax: Double = 100.0
    @State private var doubleOuterScale: Double = 1.5
    @State private var doubleOuterScaleText: String = "1.5"
    @State private var doubleOuterTranslation: InputTranslation = .scrollWheelVertical
    @State private var doubleOuterCWAction: String = "scrollUp"
    
    // 线性
    @State private var linearMinRadius: Double = 5.0
    @State private var linearMaxRadius: Double = 60.0
    @State private var linearMinScale: Double = 0.1
    @State private var linearMinScaleText: String = "0.1"
    @State private var linearMaxScale: Double = 3.0
    @State private var linearMaxScaleText: String = "3.0"
    @State private var linearTranslation: InputTranslation = .scrollWheelVertical
    @State private var linearCWAction: String = "scrollUp"
    
    // 物理半径实时指示
    @State private var liveRadius: Double? = nil
    
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
                    // 0. 控件定位元数据 (Uniquely Identifying Info)
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
                    
                    // 1. 配色定制
                    VStack(alignment: .leading, spacing: 6) {
                        Text("主题颜色")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                            ForEach(colors, id: \.self) { colorHex in
                                Circle()
                                    .fill(Color(hex: colorHex))
                                    .frame(width: 18, height: 18)
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
                        .padding(.top, 4)
                    }
                    
                    // 2. 模式选择
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
                    
                    // 3. 不同模式子表单
                    switch configType {
                    case .single:
                        singleSubForm
                    case .double:
                        doubleSubForm
                    case .linear:
                        linearSubForm
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
                    self.themeColor = hex
                    save()
                }
            }
        }
    }
    
    // MARK: - 模式子表单实现
    
    private var singleSubForm: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            
            HStack {
                Text("每度变化量")
                    .font(.system(size: 11)).foregroundColor(.white)
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
                    .foregroundColor(.orange)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: singleScaleText) { next in
                        if let val = Double(next) {
                            singleScale = val
                            save()
                        }
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("顺时针旋转时触发")
                    .font(.system(size: 11)).foregroundColor(.white)
                Picker("", selection: $singleCWAction) {
                    ForEach(directionOptions(for: singleTranslation), id: \.self) { opt in
                        Text(actionDescription(opt)).tag(opt)
                    }
                }
                .onChange(of: singleCWAction) { _ in save() }
            }
        }
    }
    
    private var doubleSubForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 内圈
            VStack(alignment: .leading, spacing: 8) {
                Text("🟢 内圈旋钮 (微调)")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.green)
                HStack {
                    Text("响应半径").font(.system(size: 11))
                    Spacer()
                    Text("5.0 mm ~ \(Int(doubleInnerRadiusMax)) mm")
                        .font(.system(size: 11, design: .monospaced))
                }
                Slider(value: $doubleInnerRadiusMax, in: 10.0...40.0, step: 1.0)
                    .onChange(of: doubleInnerRadiusMax) { next in
                        doubleOuterRadiusMin = next + doubleMargin
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
                    Text("每度变化量")
                        .font(.system(size: 11)).foregroundColor(.white)
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
                        .foregroundColor(.orange)
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
            
            // 保护带宽度
            VStack(alignment: .leading, spacing: 8) {
                Text("⚙️ 保护带宽度 (Margin)")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                HStack {
                    Text("宽度: \(Int(doubleMargin)) mm")
                    Spacer()
                    Slider(value: $doubleMargin, in: 0.0...10.0, step: 1.0)
                        .frame(width: 150)
                        .onChange(of: doubleMargin) { next in
                            doubleOuterRadiusMin = doubleInnerRadiusMax + next
                            save()
                        }
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            // 外圈
            VStack(alignment: .leading, spacing: 8) {
                Text("🟠 外圈旋钮 (粗调)")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.orange)
                HStack {
                    Text("响应半径").font(.system(size: 11))
                    Spacer()
                    Text("\(Int(doubleOuterRadiusMin)) mm ~ 100 mm")
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
                    Text("每度变化量")
                        .font(.system(size: 11)).foregroundColor(.white)
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
                        .foregroundColor(.orange)
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
        }
    }
    
    private var linearSubForm: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    Slider(value: $linearMinRadius, in: 5.0...30.0, step: 1.0)
                        .frame(width: 180)
                        .onChange(of: linearMinRadius) { _ in save() }
                }
                HStack {
                    Text("最大半径: \(Int(linearMaxRadius)) mm")
                    Spacer()
                    Slider(value: $linearMaxRadius, in: 35.0...100.0, step: 1.0)
                        .frame(width: 180)
                        .onChange(of: linearMaxRadius) { _ in save() }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("每度变化量范围").font(.system(size: 11, weight: .semibold))
                HStack {
                    Text("最小变化量:")
                        .font(.system(size: 11)).foregroundColor(.white)
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
                        .foregroundColor(.orange)
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
                        .font(.system(size: 11)).foregroundColor(.white)
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
                        .foregroundColor(.orange)
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
    
    private func loadExisting() {
        if let existing = RuleLibrary.shared.lookup(for: target.ruleKey) {
            self.themeColor = existing.themeColor ?? "#0A84FF"
            self.configType = existing.configType
            
            if let single = existing.singleConfig {
                self.singleScale = single.unitPerDegree
                self.singleScaleText = String(format: "%.4g", single.unitPerDegree)
                self.singleTranslation = single.translation
                self.singleCWAction = single.clockwiseAction
            }
            if let d = existing.doubleConfig {
                self.doubleInnerRadiusMax = d.inner.maxRadius
                self.doubleInnerScale = d.inner.unitPerDegree
                self.doubleInnerScaleText = String(format: "%.4g", d.inner.unitPerDegree)
                self.doubleInnerTranslation = d.inner.translation
                self.doubleInnerCWAction = d.inner.clockwiseAction
                
                self.doubleMargin = d.inner.margin
                
                self.doubleOuterRadiusMin = d.outer.minRadius
                self.doubleOuterRadiusMax = d.outer.maxRadius
                self.doubleOuterScale = d.outer.unitPerDegree
                self.doubleOuterScaleText = String(format: "%.4g", d.outer.unitPerDegree)
                self.doubleOuterTranslation = d.outer.translation
                self.doubleOuterCWAction = d.outer.clockwiseAction
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
    }
    
    private func save() {
        var rule = ControlRule(key: target.ruleKey, themeColor: themeColor, configType: configType)
        
        switch configType {
        case .single:
            rule.singleConfig = SingleKnobConfig(
                unitPerDegree: singleScale,
                translation: singleTranslation,
                clockwiseAction: singleCWAction
            )
        case .double:
            rule.doubleConfig = DoubleKnobConfig(
                inner: VirtualKnobConfig(minRadius: 5.0, maxRadius: doubleInnerRadiusMax, margin: doubleMargin, unitPerDegree: doubleInnerScale, translation: doubleInnerTranslation, clockwiseAction: doubleInnerCWAction),
                outer: VirtualKnobConfig(minRadius: doubleInnerRadiusMax + doubleMargin, maxRadius: doubleOuterRadiusMax, margin: doubleMargin, unitPerDegree: doubleOuterScale, translation: doubleOuterTranslation, clockwiseAction: doubleOuterCWAction)
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

