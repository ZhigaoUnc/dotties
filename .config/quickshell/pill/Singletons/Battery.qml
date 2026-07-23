pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

/**
 * Laptop-battery state for the pill, sourced from UPower's display device and
 * gated so a desktop without a battery reports `present` false (the hover
 * cluster and 蓄 surface stay hidden). Exposes percentage, charge state, a
 * signed draw/charge wattage, capacity and optional health, plus a formatted
 * time-to-empty/full string. `low` flags a discharging battery at or below 20%.
 */
Singleton {
    id: root

    readonly property int acProfile: Flags.acProfile
    readonly property int batteryProfile: Flags.batteryProfile

    readonly property var dev: UPower.displayDevice

    readonly property bool present: dev !== null && dev.ready && dev.isLaptopBattery && dev.isPresent
    readonly property real frac: dev ? Math.max(0, Math.min(1, dev.percentage)) : 0
    readonly property int pct: Math.round(frac * 100)
    readonly property int state: dev ? dev.state : UPowerDeviceState.Unknown

    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool full: state === UPowerDeviceState.FullyCharged || pct >= 100
    readonly property bool discharging: state === UPowerDeviceState.Discharging
    readonly property bool low: !charging && pct <= 20

    /** True once we've notified for the current low-battery cycle. */
    property bool lowNotified: false

    onLowChanged: {
        if (low && !root.lowNotified) {
            root.lowNotified = true;
            Quickshell.execDetached(["notify-send", "-u", "critical",
                "-a", "Battery", "-i", "battery-low",
                "Battery Low", root.pct + "% remaining"]);
        } else if (!low) {
            root.lowNotified = false;
        }
    }

    readonly property real rateW: !dev ? 0
        : (discharging ? -dev.changeRate : (charging ? dev.changeRate : 0))
    readonly property real capacityWh: dev ? dev.energyCapacity : 0

    readonly property bool healthSupported: dev ? dev.healthSupported : false
    readonly property int health: dev ? Math.round(dev.healthPercentage) : 0

    readonly property bool hasTime: !dev ? false
        : (charging ? dev.timeToFull > 0 : (discharging ? dev.timeToEmpty > 0 : false))
    readonly property string timeStr: !dev ? ""
        : (charging ? fmt(dev.timeToFull) : (discharging ? fmt(dev.timeToEmpty) : ""))

    readonly property string stateLabel: charging ? "Charging"
        : (full ? "On AC · Full"
        : (discharging ? "Discharging" : "On AC"))

    Connections {
        target: typeof UPower !== "undefined" ? UPower : null
        enabled: typeof PowerProfiles !== "undefined"
        function onOnBatteryChanged() {
            var target = UPower.onBattery ? root.batteryProfile : root.acProfile;
            if (target >= 0 && PowerProfiles.profile !== target)
                PowerProfiles.profile = target;
        }
    }

    Connections {
        target: Flags
        enabled: typeof PowerProfiles !== "undefined"
        function onAcProfileChanged() {
            if (typeof UPower !== "undefined" && !UPower.onBattery && root.acProfile >= 0 && PowerProfiles.profile !== root.acProfile)
                PowerProfiles.profile = root.acProfile;
        }
        function onBatteryProfileChanged() {
            if (typeof UPower !== "undefined" && UPower.onBattery && root.batteryProfile >= 0 && PowerProfiles.profile !== root.batteryProfile)
                PowerProfiles.profile = root.batteryProfile;
        }
    }

    function fmt(sec) {
        var s = Math.max(0, Math.round(sec));
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        if (h > 0)
            return h + "h " + m + "m";
        return m + "m";
    }
}