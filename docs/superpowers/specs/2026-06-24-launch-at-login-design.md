# 开机启动功能设计规格

## 背景

PhantomKnob 是一个菜单栏工具（`LSUIElement = true`），用户希望登录 Mac 后无需手动启动即可开始使用旋钮手势控制功能。本规格描述"开机启动"（Launch at Login）功能的设计。

## 范围

- 非 App Store 分发，非沙盒（`app-sandbox = false`）
- 最低 macOS 版本提升至 13.0
- 仅在设置界面提供开关，不在菜单栏添加入口

## 核心决策

### 实现方式：SMAppService（macOS 13+）

使用 `ServiceManagement` 框架的 `SMAppService.mainApp` API：

- `SMAppService.mainApp.register()` — 注册为登录项
- `SMAppService.mainApp.unregister()` — 取消注册
- `SMAppService.mainApp.status` — 查询当前状态（`.enabled` / `.notRegistered` 等）

**放弃 LaunchAgent plist 方案**：需要手动写文件、处理路径、调用 `launchctl`，且 macOS 13 已不推荐。

**状态来源唯一性**：不使用 UserDefaults 缓存状态，始终以 `SMAppService.mainApp.status` 为唯一真相来源，避免系统状态与应用状态不同步。

## 组件设计

### LaunchAtLoginService

**文件**：`PhantomKnob/Service/LaunchAtLoginService.swift`

**职责**：封装 `SMAppService.mainApp`，提供应用内统一接入点。

**接口**：

```swift
import ServiceManagement

final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()
    private init() {}

    /// 当前是否已注册为登录项（以系统状态为准）
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 开启开机启动，失败时抛出错误
    func enable() throws {
        try SMAppService.mainApp.register()
    }

    /// 关闭开机启动，失败时抛出错误
    func disable() throws {
        try SMAppService.mainApp.unregister()
    }
}
```

**错误处理**：`enable()` / `disable()` 直接将 SMAppService 的错误向上抛出，由调用方（SettingsView）负责展示给用户。

### SettingsView 变更

**文件**：`PhantomKnob/View/SettingsView.swift`

在 `GeneralSettingsView` 的"启动"区域（已存在的 `skipUserGuideOnStartup` 所在 section）新增一个 Toggle：

```
┌─────────────────────────────────────────────────────────┐
│ 启动                                                      │
│                                                           │
│  ✓  登录时自动启动                                         │
│  ✓  启动时显示使用引导                                     │
└─────────────────────────────────────────────────────────┘
```

Toggle 绑定逻辑：
- **读取**：`LaunchAtLoginService.shared.isEnabled`
- **写入**：调用 `enable()` 或 `disable()`，失败时弹 `NSAlert` 展示错误信息
- **刷新时机**：`onAppear` 时重新读取，与系统状态同步

## 最低版本更新

| 文件 | 变更 |
|------|------|
| `Info.plist` | `LSMinimumSystemVersion`: `12.0` → `13.0` |
| `project.yml` | `deploymentTarget` 同步更新为 `13.0` |

## 不在此次范围内

- 菜单栏菜单项入口
- 首次启动引导中的提示
- 单元测试（SMAppService 依赖系统状态，无法在测试环境 mock）
- 多用户场景（当前单用户场景下 `SMAppService.mainApp` 已满足需求）
