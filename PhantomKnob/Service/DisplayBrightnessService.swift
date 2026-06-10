import Foundation
import CoreGraphics

class DisplayBrightnessService {
    private typealias GetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32
    
    private var getBrightnessSym: GetBrightnessFunc?
    private var setBrightnessSym: SetBrightnessFunc?
    
    init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) {
            if let getSym = dlsym(handle, "DisplayServicesGetLinearBrightness") {
                getBrightnessSym = unsafeBitCast(getSym, to: GetBrightnessFunc.self)
            }
            if let setSym = dlsym(handle, "DisplayServicesSetLinearBrightness") {
                setBrightnessSym = unsafeBitCast(setSym, to: SetBrightnessFunc.self)
            }
        }
    }
    
    func getBrightness() -> Float? {
        let displayID = CGMainDisplayID()
        var val: Float = 0.0
        if let getSym = getBrightnessSym {
            let res = getSym(displayID, &val)
            if res == 0 {
                return val
            }
        }
        return nil
    }
    
    func setBrightness(_ brightness: Float) -> Bool {
        let displayID = CGMainDisplayID()
        let targetBrightness = max(0.0, min(1.0, brightness))
        if let setSym = setBrightnessSym {
            let res = setSym(displayID, targetBrightness)
            return res == 0
        }
        return false
    }
}
