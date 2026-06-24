import Foundation
import ServiceManagement

final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()
    
    private init() {}
    
    /// 当前是否已注册为登录项
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
    
    /// 开启开机启动
    func enable() throws {
        try SMAppService.mainApp.register()
    }
    
    /// 关闭开机启动
    func disable() throws {
        try SMAppService.mainApp.unregister()
    }
}
