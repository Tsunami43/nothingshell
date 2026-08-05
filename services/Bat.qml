pragma Singleton

// Battery (laptop only), via UPower's display device.
import Quickshell
import Quickshell.Services.UPower

Singleton {
    readonly property bool has:      UPower.displayDevice?.isLaptopBattery ?? false
    readonly property int  percent:  Math.round(UPower.displayDevice?.percentage ?? 0)
    readonly property bool charging: (UPower.displayDevice?.state ?? 0) === UPowerDeviceState.Charging
}
