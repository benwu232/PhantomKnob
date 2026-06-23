// PhantomKnob/Storage/RuleLibrary.swift
import Foundation

/// 规则库：查找 ControlRule 的单一入口。
/// 优先级：用户规则（Application Support）> 内置规则（App Bundle）
/// 匹配策略：按精度从高到低，第一条命中即返回。
final class RuleLibrary {
    static let shared = RuleLibrary()

    private var rules: [ControlRule] = []

    internal let myKnobsURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("PhantomKnob", isDirectory: true)
            .appendingPathComponent("my_knobs.json")
    }()

    init() {
        reload()
    }

    /// 重新从磁盘加载规则。
    func reload() {
        var loaded: [ControlRule] = []

        // 如果用户规则文件不存在，自动创建并写入预置规则
        if !FileManager.default.fileExists(atPath: myKnobsURL.path) {
            setupDefaultMyKnobs()
        }
        
        if let myKnobs = loadKnobs(from: myKnobsURL) {
            loaded.append(contentsOf: myKnobs)
        }

        self.rules = loaded
    }

    private func setupDefaultMyKnobs() {
        let defaultRulesJSON = """
        [
          {
            "key": {
              "bundleID": "com.apple.QuickTimePlayerX",
              "axRole": "AXSlider",
              "displayName": "volume"
            },
            "configType": "single",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "arrowKeyUpDown",
              "clockwiseAction": "arrowUp"
            }
          },
          {
            "key": {
              "bundleID": "com.apple.QuickTimePlayerX",
              "axRole": "AXSlider",
              "displayName": "timeline"
            },
            "configType": "double",
            "doubleConfig": {
              "inner": {
                "translation": "arrowKeyLeftRight",
                "minRadius": 10.0,
                "themeColor": "#30D158",
                "unitPerDegree": 10.0,
                "margin": 2.0,
                "maxRadius": 25.0,
                "clockwiseAction": "arrowRight"
              },
              "outer": {
                "translation": "arrowKeyLeftRight",
                "minRadius": 25.0,
                "themeColor": "#FF9F0A",
                "unitPerDegree": 1.5,
                "margin": 2.0,
                "maxRadius": 100.0,
                "clockwiseAction": "arrowRight"
              }
            },
            "themeColor": "#64D2FF"
          },
          {
            "key": {
              "bundleID": "com.apple.FinalCut",
              "axRole": "AXSlider"
            },
            "configType": "single",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "scrollWheelVertical",
              "clockwiseAction": "scrollUp"
            }
          },
          {
            "key": {
              "displayName": "Timeline Zoom",
              "axRole": "AXSlider",
              "bundleID": "com.apple.FinalCut"
            },
            "themeColor": "#34C759",
            "configType": "single",
            "singleConfig": {
              "unitPerDegree": 0.5,
              "translation": "scrollWheelVertical",
              "clockwiseAction": "scrollUp"
            }
          },
          {
            "key": {
              "bundleID": "com.blackmagic-design.DaVinciResolve",
              "displayName": "DaVinci Resolve",
              "axRole": "unknown"
            },
            "configType": "double",
            "doubleConfig": {
              "outer": {
                "translation": "scrollWheelVertical",
                "minRadius": 25.0,
                "themeColor": "#FF9F0A",
                "unitPerDegree": 1.0,
                "margin": 2.0,
                "maxRadius": 100.0,
                "clockwiseAction": "scrollDown"
              },
              "inner": {
                "margin": 2.0,
                "unitPerDegree": 5.0,
                "clockwiseAction": "scrollDown",
                "themeColor": "#30D158",
                "maxRadius": 25.0,
                "minRadius": 10.0,
                "translation": "scrollWheelVertical"
              }
            },
            "themeColor": "#0A84FF"
          },
          {
            "key": {
              "displayName": "ColorWheel",
              "axRole": "AXSlider",
              "bundleID": "com.blackmagic-design.DaVinciResolve"
            },
            "themeColor": "#007AFF",
            "configType": "single",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "scrollWheelVertical",
              "clockwiseAction": "scrollUp"
            }
          },
          {
            "key": {
              "bundleID": "com.blackmagic-design.DaVinciResolve",
              "axRole": "unknown"
            },
            "themeColor": "#007AFF",
            "configType": "single",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "scrollWheelVertical",
              "clockwiseAction": "scrollDown"
            }
          },
          {
            "key": {
              "bundleID": "com.lemon.lvoverseas",
              "axRole": "unknown",
              "displayName": "CapCut"
            },
            "configType": "single",
            "themeColor": "#0A84FF",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "scrollWheelHorizontal",
              "clockwiseAction": "scrollRight",
              "minRadius": 10.0
            }
          },
          {
            "key": {
              "bundleID": "com.lemon.lvoverseas",
              "axRole": "unknown"
            },
            "themeColor": "#FF9500",
            "configType": "single",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "arrowKeyLeftRight",
              "clockwiseAction": "arrowRight"
            }
          },
          {
            "key": {
              "axRole": "AXStaticText",
              "displayName": "MainTimeLineRoot",
              "bundleID": "com.lemon.lvoverseas"
            },
            "configType": "linear",
            "themeColor": "#FFFFFF",
            "linearConfig": {
              "clockwiseAction": "arrowRight",
              "minRadius": 10.0,
              "minScale": 1.0,
              "maxScale": 30.0,
              "maxRadius": 35.0,
              "translation": "arrowKeyLeftRight"
            }
          },
          {
            "key": {
              "axRole": "AXStaticText",
              "bundleID": "com.lemon.lvoverseas",
              "displayName": "automationredValue"
            },
            "configType": "single",
            "themeColor": "#0A84FF",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "arrowKeyUpDown",
              "clockwiseAction": "arrowUp",
              "minRadius": 10.0
            }
          },
          {
            "key": {
              "bundleID": "com.lemon.lvoverseas",
              "axRole": "AXStaticText",
              "displayName": "automationblueValue"
            },
            "configType": "single",
            "themeColor": "#0A84FF",
            "singleConfig": {
              "minRadius": 10.0,
              "clockwiseAction": "arrowUp",
              "unitPerDegree": 1.0,
              "translation": "arrowKeyUpDown"
            }
          },
          {
            "key": {
              "axRole": "AXStaticText",
              "bundleID": "com.lemon.lvoverseas",
              "displayName": "automationgreenValue"
            },
            "configType": "single",
            "themeColor": "#0A84FF",
            "singleConfig": {
              "clockwiseAction": "arrowUp",
              "minRadius": 10.0,
              "translation": "arrowKeyUpDown",
              "unitPerDegree": 1.0
            }
          },
          {
            "key": {
              "bundleID": "com.lemon.lvoverseas",
              "axRole": "AXStaticText",
              "displayName": "automationcolorWheelsSettingGroup"
            },
            "configType": "single",
            "themeColor": "#0A84FF",
            "singleConfig": {
              "translation": "arrowKeyUpDown",
              "minRadius": 10.0,
              "clockwiseAction": "arrowUp",
              "unitPerDegree": 1.0
            }
          },
          {
            "key": {
              "bundleID": "com.lemon.lvoverseas",
              "axRole": "AXStaticText",
              "displayName": "automationpanelSettingGroup1"
            },
            "configType": "single",
            "themeColor": "#0A84FF",
            "singleConfig": {
              "minRadius": 10.0,
              "unitPerDegree": 1.0,
              "translation": "arrowKeyUpDown",
              "clockwiseAction": "arrowUp"
            }
          },
          {
            "key": {
              "displayName": "",
              "bundleID": "com.lemon.lvoverseas",
              "axRole": "AXStaticText"
            },
            "configType": "single",
            "themeColor": "#0A84FF",
            "singleConfig": {
              "minRadius": 10.0,
              "clockwiseAction": "arrowUp",
              "unitPerDegree": 1.0,
              "translation": "arrowKeyUpDown"
            }
          },
          {
            "key": {
              "axRole": "AXStaticText",
              "displayName": "slider",
              "bundleID": "com.lemon.lvoverseas"
            },
            "configType": "single",
            "themeColor": "#0A84FF",
            "singleConfig": {
              "clockwiseAction": "scrollUp",
              "minRadius": 10.0,
              "translation": "scrollWheelVertical",
              "unitPerDegree": 1.0
            }
          },
          {
            "key": {
              "displayName": "Timeline",
              "axRole": "AXSlider",
              "bundleID": "com.lemon.jianyingpro"
            },
            "configType": "double",
            "doubleConfig": {
              "outer": {
                "maxRadius": 80.0,
                "translation": "arrowKeyLeftRight",
                "minRadius": 30.0,
                "margin": 2.0,
                "unitPerDegree": 1.0,
                "clockwiseAction": "arrowRight"
              },
              "inner": {
                "maxRadius": 30.0,
                "translation": "scrollWheelVertical",
                "minRadius": 10.0,
                "margin": 2.0,
                "unitPerDegree": 1.0,
                "clockwiseAction": "scrollUp"
              }
            },
            "themeColor": "#FF5A5F"
          },
          {
            "key": {
              "displayName": "Parameter",
              "axRole": "AXTextField",
              "bundleID": "com.lemon.jianyingpro"
            },
            "configType": "single",
            "themeColor": "#FF5A5F",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "arrowKeyLeftRight",
              "clockwiseAction": "arrowRight"
            }
          },
          {
            "key": {
              "displayName": "Timeline",
              "axRole": "AXSlider",
              "bundleID": "com.lemon.lvoverseas"
            },
            "configType": "double",
            "doubleConfig": {
              "outer": {
                "maxRadius": 80.0,
                "translation": "arrowKeyLeftRight",
                "minRadius": 30.0,
                "margin": 2.0,
                "unitPerDegree": 1.0,
                "clockwiseAction": "arrowRight"
              },
              "inner": {
                "maxRadius": 30.0,
                "translation": "scrollWheelVertical",
                "minRadius": 10.0,
                "margin": 2.0,
                "unitPerDegree": 1.0,
                "clockwiseAction": "scrollUp"
              }
            },
            "themeColor": "#FF5A5F"
          },
          {
            "key": {
              "displayName": "Parameter",
              "axRole": "AXTextField",
              "bundleID": "com.lemon.lvoverseas"
            },
            "configType": "single",
            "themeColor": "#FF5A5F",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "arrowKeyLeftRight",
              "clockwiseAction": "arrowRight"
            }
          },
          {
            "key": {
              "axRole": "unknown",
              "bundleID": "com.lemon.lv"
            },
            "themeColor": "#FF9500",
            "configType": "single",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "arrowKeyLeftRight",
              "clockwiseAction": "arrowRight"
            }
          },
          {
            "key": {
              "axRole": "unknown",
              "bundleID": "com.lemon.lvediting"
            },
            "themeColor": "#FF9500",
            "configType": "single",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "arrowKeyLeftRight",
              "clockwiseAction": "arrowRight"
            }
          },
          {
            "key": {
              "axRole": "unknown",
              "bundleID": "com.lemon.jianying"
            },
            "themeColor": "#FF9500",
            "configType": "single",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "arrowKeyLeftRight",
              "clockwiseAction": "arrowRight"
            }
          },
          {
            "key": {
              "axRole": "unknown",
              "bundleID": "com.lemon.jianyingpro"
            },
            "themeColor": "#FF9500",
            "configType": "single",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "arrowKeyLeftRight",
              "clockwiseAction": "arrowRight"
            }
          },
          {
            "key": {
              "bundleID": "com.phantomknob.controlpanel",
              "axRole": "ControlPanel",
              "identifier": "VolumeKnob"
            },
            "configType": "single",
            "singleConfig": {
              "unitPerDegree": 1.0,
              "translation": "scrollWheelVertical",
              "clockwiseAction": "scrollUp"
            }
          },
          {
            "key": {
              "bundleID": "com.phantomknob.controlpanel",
              "axRole": "ControlPanel",
              "identifier": "DoubleKnob"
            },
            "configType": "double",
            "doubleConfig": {
              "inner": {
                "minRadius": 15.0,
                "maxRadius": 30.0,
                "margin": 2.0,
                "unitPerDegree": 1.0,
                "translation": "scrollWheelVertical",
                "clockwiseAction": "scrollUp"
              },
              "outer": {
                "minRadius": 30.0,
                "maxRadius": 60.0,
                "margin": 2.0,
                "unitPerDegree": 0.1,
                "translation": "scrollWheelVertical",
                "clockwiseAction": "scrollUp"
              }
            }
          },
          {
            "key": {
              "bundleID": "com.phantomknob.controlpanel",
              "axRole": "ControlPanel",
              "identifier": "LinearKnob"
            },
            "configType": "linear",
            "linearConfig": {
              "minRadius": 10.0,
              "maxRadius": 40.0,
              "minScale": 0.1,
              "maxScale": 5.0,
              "translation": "scrollWheelVertical",
              "clockwiseAction": "scrollUp"
            }
          }
        ]
        """
        
        let dir = myKnobsURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if let data = defaultRulesJSON.data(using: .utf8) {
                try data.write(to: myKnobsURL)
                NSLog("[RuleLibrary] Successfully initialized default my_knobs.json rules.")
            }
        } catch {
            NSLog("[RuleLibrary] Failed to initialize default my_knobs.json: \(error)")
        }
    }

    /// 按优先级顺序查找匹配 ruleKey 的第一条规则。
    /// 精度：(parentChain constraint match) > (bundleID + axRole + identifier) > (bundleID + axRole + displayName) > (bundleID + axRole) > (axRole only)
    func lookup(for ruleKey: RuleKey) -> ControlRule? {
        // 1. 最高优先级：携带 parentChain 且满足父链结构校验的专有规则
        if let targetChain = ruleKey.parentChain, !targetChain.isEmpty {
            let matched = rules.first(where: { rule in
                guard let ruleChain = rule.key.parentChain, !ruleChain.isEmpty else { return false }
                return rule.key.bundleID == ruleKey.bundleID &&
                       rule.key.axRole == ruleKey.axRole &&
                       Self.matchParentChain(ruleChain: ruleChain, targetChain: targetChain)
            })
            if let match = matched { return match }
        }

        // 2. 精确 ID 匹配
        if let exact = rules.first(where: {
            $0.key.bundleID == ruleKey.bundleID &&
            $0.key.axRole == ruleKey.axRole &&
            $0.key.identifier != nil &&
            $0.key.identifier == ruleKey.identifier
        }) { return exact }

        // 3. DisplayName 匹配
        if let byDisplayName = rules.first(where: {
            $0.key.bundleID == ruleKey.bundleID &&
            $0.key.axRole == ruleKey.axRole &&
            $0.key.displayName != nil &&
            ruleKey.displayName != nil &&
            $0.key.displayName == ruleKey.displayName
        }) { return byDisplayName }

        // 4. 宽泛匹配（同 app 同 role，identifier/displayName/parentChain 均为 nil 或空）
        if let broad = rules.first(where: {
            $0.key.bundleID == ruleKey.bundleID &&
            $0.key.axRole == ruleKey.axRole &&
            $0.key.identifier == nil &&
            $0.key.displayName == nil &&
            ($0.key.parentChain == nil || $0.key.parentChain?.isEmpty == true)
        }) { return broad }

        // 5. 跨 app 匹配（只匹配 role）
        if let byRole = rules.first(where: {
            $0.key.bundleID.isEmpty &&
            $0.key.axRole == ruleKey.axRole
        }) { return byRole }

        // 6. App 级别未知角色兜底（若当前 app 存在 axRole == "unknown" 的兜底规则）
        if !ruleKey.bundleID.isEmpty && ruleKey.axRole != "unknown" {
            if let appFallback = rules.first(where: {
                $0.key.bundleID == ruleKey.bundleID &&
                $0.key.axRole == "unknown" &&
                $0.key.identifier == nil &&
                $0.key.displayName == nil &&
                ($0.key.parentChain == nil || $0.key.parentChain?.isEmpty == true)
            }) { return appFallback }
        }

        return nil
    }

    /// 校验规则父链约束是否是鼠标实际控件父链的子集序列（从叶到根匹配）
    static func matchParentChain(ruleChain: [ParentNodeInfo], targetChain: [ParentNodeInfo]) -> Bool {
        var targetIdx = 0
        for ruleNode in ruleChain {
            var found = false
            while targetIdx < targetChain.count {
                let targetNode = targetChain[targetIdx]
                targetIdx += 1
                if targetNode.axRole == ruleNode.axRole &&
                   (ruleNode.displayName == nil || targetNode.displayName == ruleNode.displayName) {
                    found = true
                    break
                }
            }
            if !found { return false }
        }
        return true
    }

    func saveRule(_ rule: ControlRule) {
        var loadedUserRules: [ControlRule] = []
        
        // 1. 先尝试读取本地 my_knobs.json
        if FileManager.default.fileExists(atPath: myKnobsURL.path) {
            if let data = try? Data(contentsOf: myKnobsURL),
               let existing = try? JSONDecoder().decode([ControlRule].self, from: data) {
                loadedUserRules = existing
            }
        } else {
            // 确保目录存在
            let dir = myKnobsURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        // 2. 合并或追加：如果在 userRules 里有相同 key 的规则，进行替换，否则追加
        if let index = loadedUserRules.firstIndex(where: { $0.key.matches(rule.key) }) {
            loadedUserRules[index] = rule
        } else {
            loadedUserRules.insert(rule, at: 0) // 高优先级追加
        }
        
        // 3. 序列化写回本地
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(loadedUserRules) {
            try? data.write(to: myKnobsURL)
        }
        
        // 4. 重载内存规则并通知状态机更新
        self.reload()
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ControlRuleDidUpdate"),
            object: nil,
            userInfo: ["rule": rule]
        )
    }

    private func loadKnobs(from url: URL) -> [ControlRule]? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode([ControlRule].self, from: data)
    }
}

// 追加到 RuleLibrary（仅测试用）
#if DEBUG
extension RuleLibrary {
    func injectRulesForTesting(_ rules: [ControlRule]) {
        self.rules = rules
    }
}
#endif
