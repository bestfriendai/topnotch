import AppKit
import AudioToolbox
import IOKit.ps
import OSLog

/// Manages battery monitoring via IOKit power source notifications.
/// Owns the IOPSNotificationCreateRunLoopSource lifecycle and updates
/// NotchState.battery as the power state changes.
final class BatteryCoordinator {
    private let state: NotchState
    private var batteryRunLoopSource: CFRunLoopSource?
    private var batteryMonitorContext: UnsafeMutableRawPointer?
    private var lastChargingState = false

    init(state: NotchState) {
        self.state = state
    }

    deinit {
        if let source = batteryRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        if let ctx = batteryMonitorContext {
            Unmanaged<BatteryCoordinator>.fromOpaque(ctx).release()
        }
    }

    // MARK: - Public API

    func start() {
        updateBatteryInfo()
        lastChargingState = state.battery.info.isCharging

        let context = Unmanaged.passRetained(self).toOpaque()
        batteryMonitorContext = context
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let coordinator = Unmanaged<BatteryCoordinator>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { [weak coordinator] in coordinator?.checkBatteryChanges() }
        }, context)?.takeRetainedValue() {
            batteryRunLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        } else {
            Unmanaged<BatteryCoordinator>.fromOpaque(context).release()
            batteryMonitorContext = nil
        }
    }

    // MARK: - Private

    private func checkBatteryChanges() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else { return }

        let isCharging = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let wasCharging = lastChargingState
        lastChargingState = isCharging

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let capacity = info[kIOPSCurrentCapacityKey] as? Int { self.state.battery.info.level = capacity }
            self.state.battery.info.isCharging = isCharging
            if let time = info[kIOPSTimeToEmptyKey] as? Int, time > 0 { self.state.battery.info.timeRemaining = time }
            else if let time = info[kIOPSTimeToFullChargeKey] as? Int, time > 0 { self.state.battery.info.timeRemaining = time }
            else { self.state.battery.info.timeRemaining = nil }

            guard UserDefaults.standard.object(forKey: "showBatteryIndicator") as? Bool ?? true else { return }
            if isCharging && !wasCharging { self.triggerCharging(started: true) }
            else if !isCharging && wasCharging { self.triggerCharging(started: false) }
        }
    }

    private func updateBatteryInfo() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else { return }

        let isCharging = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let capacity = info[kIOPSCurrentCapacityKey] as? Int { self.state.battery.info.level = capacity }
            self.state.battery.info.isCharging = isCharging
        }
        lastChargingState = isCharging
    }

    private func triggerCharging(started: Bool) {
        if started {
            AppLogger.battery.info("Charging started — battery \(self.state.battery.info.level, privacy: .public)%")
            state.battery.showChargingAnimation = true
            state.isExpanded = true
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            playSound("Blow", volume: 0.4, fallback: 1004)
            NotificationCenter.default.post(
                name: NSNotification.Name("TopNotch.ChargingStarted"),
                object: nil,
                userInfo: ["level": state.battery.info.level]
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self else { return }
                self.state.battery.showChargingAnimation = false
                if !self.state.isHovered && !self.state.youtube.isShowingPlayer { self.state.isExpanded = false }
            }
        } else {
            state.battery.showUnplugAnimation = true
            state.isExpanded = true
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            playSound("Pop", volume: 0.35, fallback: 1057)
            NotificationCenter.default.post(
                name: NSNotification.Name("TopNotch.ChargingEnded"),
                object: nil,
                userInfo: ["level": state.battery.info.level]
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self else { return }
                self.state.battery.showUnplugAnimation = false
                if !self.state.isHovered && !self.state.youtube.isShowingPlayer { self.state.isExpanded = false }
            }
        }
    }

    private func playSound(_ name: String, volume: Float, fallback: UInt32) {
        guard UserDefaults.standard.object(forKey: "chargingSoundEnabled") as? Bool ?? true else { return }
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.volume = volume
            sound.play()
        } else {
            AudioServicesPlaySystemSound(fallback)
        }
    }
}
