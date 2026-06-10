import Foundation
import CoreAudio

class AudioControlService {
    func getVolume() -> Float? {
        var deviceID = AudioDeviceID(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr else { return nil }
        
        var volume = Float(0.0)
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volSize = UInt32(MemoryLayout<Float>.size)
        let volStatus = AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &volSize, &volume)
        
        // Fallback to channel 0 if main channel check fails
        if volStatus != noErr {
            volAddress.mElement = 0
            let volStatus2 = AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &volSize, &volume)
            if volStatus2 == noErr {
                return volume
            }
            return nil
        }
        return volume
    }
    
    func setVolume(_ volume: Float) -> Bool {
        var deviceID = AudioDeviceID(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr else { return false }
        
        var vol = max(0.0, min(1.0, volume))
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let volSize = UInt32(MemoryLayout<Float>.size)
        var volStatus = AudioObjectSetPropertyData(deviceID, &volAddress, 0, nil, volSize, &vol)
        
        // Fallback to channel 0 if main channel write fails
        if volStatus != noErr {
            volAddress.mElement = 0
            volStatus = AudioObjectSetPropertyData(deviceID, &volAddress, 0, nil, volSize, &vol)
        }
        return volStatus == noErr
    }
}
