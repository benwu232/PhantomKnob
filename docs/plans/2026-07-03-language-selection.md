# 语言选择设置 (Language Selection in Settings) 实现计划

在设置常规（General）界面添加简体中文和英文的语言选择，并实现自动重启应用的逻辑。

## 架构：
利用 `UserDefaults` 的 `AppleLanguages` 键来覆盖应用的本地化首选项，并在语言变更时提示用户使用 `NSWorkspace.shared.openApplication` 无缝重启自身。

---

### 任务 1：创建 AppLanguageManager

**文件：**
- 创建：`PhantomKnob/Service/AppLanguageManager.swift`
- 测试：`PhantomKnob/PhantomKnobTests/AppLanguageManagerTests.swift`

- [ ] **步骤 1：编写 AppLanguageManager 的基础测试**
- [ ] **步骤 2：创建 AppLanguageManager 实现类**
- [ ] **步骤 3：运行测试验证逻辑正确性**
- [ ] **步骤 4：Commit**

---

### 任务 2：集成启动项与更新设置界面

**文件：**
- 修改：`PhantomKnob/App/PhantomKnobApp.swift`
- 修改：`PhantomKnob/View/SettingsView.swift`

- [ ] **步骤 1：在 PhantomKnobApp 启动 init() 中应用语言覆盖**
- [ ] **步骤 2：在 SettingsView 常规面板中增加 Language 区域与 Picker UI**
- [ ] **步骤 3：在 Picker 绑定的 binding 中实现弹窗和重启逻辑**
- [ ] **步骤 4：Commit**

---

### 任务 3：配置本地化资源与进行端到端手动验证

**文件：**
- 修改：`PhantomKnob/Localizable.xcstrings`

- [ ] **步骤 1：在 Localizable.xcstrings 中追加新增的界面文本和弹窗提示文本的本地化键值对**
- [ ] **步骤 2：运行并打包/编译应用，手动切换语言，验证立即重启和延迟重启的功能表现**
- [ ] **步骤 3：Commit**
