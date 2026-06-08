// PhantomKnob/Service/ScaleResolver.swift
import Foundation

struct ScaleResolver {
    static func resolveHysteresis(radius: Double, zones: [RadiusZone], currentZoneIndex: inout Int) -> Double? {
        guard !zones.isEmpty else { return 1.0 }
        
        // 校验死区限制
        if radius < zones[0].minRadius {
            return nil
        }
        
        if zones.count == 1 { return zones[0].scale }
        
        let i = currentZoneIndex
        if i >= 0 && i < zones.count {
            let effectiveMin = zones[i].minRadius - zones[i].margin
            let effectiveMax = zones[i].maxRadius + zones[i].margin
            
            if radius >= effectiveMin && radius <= effectiveMax {
                return zones[i].scale
            }
        }
        
        // 超出缓冲区，寻找落入标准区间的 Zone
        for j in 0..<zones.count {
            if radius >= zones[j].minRadius && radius <= zones[j].maxRadius {
                currentZoneIndex = j
                return zones[j].scale
            }
        }
        
        // 若完全不落入任何区间，返回最近的边界
        if radius < zones[0].minRadius {
            currentZoneIndex = 0
            return zones[0].scale
        } else {
            currentZoneIndex = zones.count - 1
            return zones[currentZoneIndex].scale
        }
    }

    static func resolveLinear(radius: Double, config: ScaleConfigLinear) -> Double? {
        if radius < config.minRadius { return nil }
        if radius >= config.maxRadius { return config.maxScale }
        let ratio = (radius - config.minRadius) / (config.maxRadius - config.minRadius)
        return config.minScale + ratio * (config.maxScale - config.minScale)
    }
}
