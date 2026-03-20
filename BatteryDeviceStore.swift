import Foundation
import IOBluetooth
import IOKit.ps

enum DeviceType: String {
    case mac = "mac"
    case airpods = "airpods"
    case mouse = "mouse"
    case keyboard = "keyboard"
    case trackpad = "trackpad"
    case other = "other"
    
    var icon: String {
        switch self {
        case .mac: return "laptopcomputer"
        case .airpods: return "airpods"
        case .mouse: return "computermouse"
        case .keyboard: return "keyboard"
        case .trackpad: return "trackpad"
        case .other: return "battery.100"
        }
    }
}

struct DeviceBattery: Identifiable {
    let id: String
    let name: String
    let type: DeviceType
    let level: Int  // 0-100
    let isCharging: Bool
    
    var icon: String { type.icon }
    var levelColor: String {
        if level > 50 { return "#34D399" }
        if level > 20 { return "#FBBF24" }
        return "#EF4444"
    }
}

@MainActor
final class BatteryDeviceStore: ObservableObject {
    static let shared = BatteryDeviceStore()
    
    @Published var devices: [DeviceBattery] = []
    
    private var timer: Timer?
    
    private init() {}
    
    func startMonitoring() {
        fetchDevices()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.fetchDevices() }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func fetchDevices() {
        var result: [DeviceBattery] = []
        
        // 1. Mac internal battery
        if let macBattery = getMacBattery() {
            result.append(macBattery)
        }
        
        // 2. Bluetooth devices
        result.append(contentsOf: getBluetoothDevices())
        
        devices = result
    }
    
    private func getMacBattery() -> DeviceBattery? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as! [CFTypeRef]
        
        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
               let type = info[kIOPSTypeKey] as? String,
               type == kIOPSInternalBatteryType,
               let capacity = info[kIOPSCurrentCapacityKey] as? Int {
                let isCharging = (info[kIOPSIsChargingKey] as? Bool) ?? false
                return DeviceBattery(id: "mac", name: "MacBook", type: .mac, level: capacity, isCharging: isCharging)
            }
        }
        return nil
    }
    
    private func getBluetoothDevices() -> [DeviceBattery] {
        var result: [DeviceBattery] = []
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return result
        }
        
        for device in pairedDevices {
            guard device.isConnected() else { continue }
            
            // Get battery level via IOBluetooth
            // Battery percentage is available as a property on some devices
            var batteryLevel: Int = -1
            if let battery = device.value(forKey: "batteryPercent") as? Int {
                batteryLevel = battery
            } else if let battery = device.value(forKey: "BatteryPercent") as? Int {
                batteryLevel = battery
            }
            
            guard batteryLevel >= 0 else { continue }
            
            let name = device.name ?? "Unknown Device"
            let type = classifyDevice(device)
            result.append(DeviceBattery(
                id: device.addressString ?? UUID().uuidString,
                name: name,
                type: type,
                level: batteryLevel,
                isCharging: false
            ))
        }
        return result
    }
    
    private func classifyDevice(_ device: IOBluetoothDevice) -> DeviceType {
        let name = (device.name ?? "").lowercased()
        if name.contains("airpod") { return .airpods }
        if name.contains("mouse") || name.contains("mx") { return .mouse }
        if name.contains("keyboard") { return .keyboard }
        if name.contains("trackpad") || name.contains("magic") { return .trackpad }
        return .other
    }
}
