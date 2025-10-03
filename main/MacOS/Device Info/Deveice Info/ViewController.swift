import Cocoa
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import CoreAudio
import Foundation
import CoreBluetooth
import SystemConfiguration
import UserNotifications

// MARK: - 裝置類型枚舉
enum DeviceType: String, CaseIterable {
    case usb = "USB"
    case bluetooth = "藍牙"
    case network = "網路"
    case audio = "音訊"
    case display = "顯示器"
    case storage = "儲存裝置"
    case pci = "PCI"
    
    var icon: String {
        switch self {
        case .usb: return "🔌"
        case .bluetooth: return "📶"
        case .network: return "🌐"
        case .audio: return "🔊"
        case .display: return "🖥"
        case .storage: return "💾"
        case .pci: return "🎛"
        }
    }
}

// MARK: - 通用裝置協定
protocol Device {
    var name: String { get }
    var type: DeviceType { get }
    var identifier: String { get }
    var status: String { get }
    var manufacturer: String? { get }
    var model: String? { get }
    var serialNumber: String? { get }
    var driverInfo: String? { get }
    var connectionInfo: String { get }
    var detailInfo: [String: String] { get }
}

// MARK: - USB 裝置
struct USBDevice: Device {
    let name: String
    let vendorID: UInt16
    let productID: UInt16
    let locationID: UInt32
    let serialNumber: String?
    let manufacturer: String?
    let model: String?
    let speed: String
    let powerRequirement: Int
    let driverInfo: String?
    
    var type: DeviceType { .usb }
    var identifier: String { String(format: "USB_%04X_%04X", vendorID, productID) }
    var status: String { "已連接" }
    var connectionInfo: String { speed }
    
    var detailInfo: [String: String] {
        var info: [String: String] = [
            "裝置類型": "USB裝置",
            "廠商ID": String(format: "0x%04X", vendorID),
            "產品ID": String(format: "0x%04X", productID),
            "位置ID": String(format: "0x%08X", locationID),
            "連接速度": speed,
            "電源需求": "\(powerRequirement) mA"
        ]
        if let manufacturer = manufacturer {
            info["製造商"] = manufacturer
        }
        if let serialNumber = serialNumber {
            info["序號"] = serialNumber
        }
        if let model = model {
            info["型號"] = model
        }
        if let driverInfo = driverInfo {
            info["驅動程式"] = driverInfo
        }
        return info
    }
}

// MARK: - 藍牙裝置
struct BluetoothDevice: Device {
    let name: String
    let identifier: String
    let rssi: Int
    let isConnected: Bool
    let deviceClass: String
    let manufacturer: String?
    let model: String?
    let serialNumber: String?
    let services: [String]
    
    var type: DeviceType { .bluetooth }
    var status: String { isConnected ? "已連接" : "已配對" }
    var driverInfo: String? { "CoreBluetooth Framework" }
    var connectionInfo: String { "RSSI: \(rssi) dBm" }
    
    var detailInfo: [String: String] {
        var info: [String: String] = [
            "裝置類型": "藍牙裝置",
            "裝置ID": identifier,
            "裝置類別": deviceClass,
            "訊號強度": "\(rssi) dBm",
            "連接狀態": status,
            "服務數量": "\(services.count)"
        ]
        if let manufacturer = manufacturer {
            info["製造商"] = manufacturer
        }
        if !services.isEmpty {
            info["支援服務"] = services.joined(separator: ", ")
        }
        return info
    }
}

// MARK: - 網路介面
struct NetworkInterface: Device {
    let name: String
    let interfaceName: String
    let hardwareAddress: String?
    let ipAddress: String?
    let subnetMask: String?
    let isActive: Bool
    let mtu: Int
    let speed: String?
    let manufacturer: String?
    let model: String?
    
    var type: DeviceType { .network }
    var identifier: String { interfaceName }
    var status: String { isActive ? "已啟用" : "已停用" }
    var serialNumber: String? { hardwareAddress }
    var driverInfo: String? { "System Network Driver" }
    var connectionInfo: String { speed ?? "未知速度" }
    
    var detailInfo: [String: String] {
        var info: [String: String] = [
            "裝置類型": "網路介面",
            "介面名稱": interfaceName,
            "MTU": "\(mtu)",
            "狀態": status
        ]
        if let hardwareAddress = hardwareAddress {
            info["MAC位址"] = hardwareAddress
        }
        if let ipAddress = ipAddress {
            info["IP位址"] = ipAddress
        }
        if let subnetMask = subnetMask {
            info["子網路遮罩"] = subnetMask
        }
        if let speed = speed {
            info["連接速度"] = speed
        }
        if let model = model {
            info["型號"] = model
        }
        return info
    }
}

// MARK: - 音訊裝置
struct AudioDevice: Device {
    let name: String
    let uid: String
    let isInput: Bool
    let isOutput: Bool
    let sampleRate: Double
    let channels: Int
    let manufacturer: String?
    let model: String?
    
    var type: DeviceType { .audio }
    var identifier: String { uid }
    var status: String { "可用" }
    var serialNumber: String? { nil }
    var driverInfo: String? { "CoreAudio Driver" }
    var connectionInfo: String {
        var types: [String] = []
        if isInput { types.append("輸入") }
        if isOutput { types.append("輸出") }
        return types.joined(separator: "/")
    }
    
    var detailInfo: [String: String] {
        var info: [String: String] = [
            "裝置類型": "音訊裝置",
            "裝置ID": uid,
            "取樣率": "\(Int(sampleRate)) Hz",
            "聲道數": "\(channels)",
            "功能": connectionInfo
        ]
        if let manufacturer = manufacturer {
            info["製造商"] = manufacturer
        }
        if let model = model {
            info["型號"] = model
        }
        return info
    }
}

// MARK: - 顯示器裝置
struct DisplayDevice: Device {
    let name: String
    let displayID: UInt32
    let vendorID: UInt32
    let modelID: UInt32
    let serialNumber: String?
    let resolution: String
    let refreshRate: Double
    let isBuiltIn: Bool
    let manufacturer: String?
    let model: String?
    
    var type: DeviceType { .display }
    var identifier: String { String(displayID) }
    var status: String { "已連接" }
    var driverInfo: String? { "Display Driver" }
    var connectionInfo: String { isBuiltIn ? "內建" : "外接" }
    
    var detailInfo: [String: String] {
        var info: [String: String] = [
            "裝置類型": "顯示器",
            "顯示器ID": String(displayID),
            "解析度": resolution,
            "更新率": "\(Int(refreshRate)) Hz",
            "連接類型": connectionInfo
        ]
        if let manufacturer = manufacturer {
            info["製造商"] = manufacturer
        }
        if let model = model {
            info["型號"] = model
        }
        if let serialNumber = serialNumber {
            info["序號"] = serialNumber
        }
        info["廠商ID"] = String(format: "0x%08X", vendorID)
        info["型號ID"] = String(format: "0x%08X", modelID)
        return info
    }
}

// MARK: - 儲存裝置
struct StorageDevice: Device {
    let name: String
    let bsdName: String
    let volumeName: String?
    let fileSystem: String?
    let capacity: UInt64
    let freeSpace: UInt64
    let isRemovable: Bool
    let isInternal: Bool
    let `protocol`: String
    let manufacturer: String?
    let model: String?
    let serialNumber: String?
    
    var type: DeviceType { .storage }
    var identifier: String { bsdName }
    var status: String { "已掛載" }
    var driverInfo: String? { fileSystem }
    var connectionInfo: String { `protocol` }
    
    var detailInfo: [String: String] {
        var info: [String: String] = [
            "裝置類型": "儲存裝置",
            "BSD名稱": bsdName,
            "容量": formatBytes(capacity),
            "可用空間": formatBytes(freeSpace),
            "使用率": String(format: "%.1f%%", Double(capacity - freeSpace) / Double(capacity) * 100),
            "連接協定": `protocol`,
            "可移除": isRemovable ? "是" : "否",
            "內部裝置": isInternal ? "是" : "否"
        ]
        if let volumeName = volumeName {
            info["磁碟區名稱"] = volumeName
        }
        if let fileSystem = fileSystem {
            info["檔案系統"] = fileSystem
        }
        if let manufacturer = manufacturer {
            info["製造商"] = manufacturer
        }
        if let model = model {
            info["型號"] = model
        }
        if let serialNumber = serialNumber {
            info["序號"] = serialNumber
        }
        return info
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - 裝置管理器
class DeviceManager: NSObject {
    static let shared = DeviceManager()
    
    private var usbMonitor: USBMonitor?
    private var bluetoothManager: CBCentralManager?
    private var updateTimer: Timer?
    
    weak var delegate: DeviceManagerDelegate?
    
    private override init() {
        super.init()
        setupMonitoring()
    }
    
    private func setupMonitoring() {
        // 設置 USB 監控
        usbMonitor = USBMonitor()
        usbMonitor?.delegate = self
        
        // 設置藍牙監控
        bluetoothManager = CBCentralManager(delegate: self, queue: nil)
        
        // 設置定期更新計時器（每5秒更新一次）
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.updateAllDevices()
        }
    }
    
    func updateAllDevices() {
        DispatchQueue.main.async {
            self.delegate?.deviceManagerDidUpdateDevices()
        }
    }
    
    // MARK: - 獲取各類裝置
    
    func getAllDevices() -> [Device] {
        var allDevices: [Device] = []
        
        allDevices.append(contentsOf: getUSBDevices())
        allDevices.append(contentsOf: getNetworkInterfaces())
        allDevices.append(contentsOf: getAudioDevices())
        allDevices.append(contentsOf: getDisplayDevices())
        allDevices.append(contentsOf: getStorageDevices())
        allDevices.append(contentsOf: getBluetoothDevices())
        
        return allDevices
    }
    
    func getDevicesByType(_ type: DeviceType) -> [Device] {
        switch type {
        case .usb:
            return getUSBDevices()
        case .bluetooth:
            return getBluetoothDevices()
        case .network:
            return getNetworkInterfaces()
        case .audio:
            return getAudioDevices()
        case .display:
            return getDisplayDevices()
        case .storage:
            return getStorageDevices()
        case .pci:
            return [] // PCI 裝置需要更深入的系統存取
        }
    }
    
    private func getUSBDevices() -> [Device] {
        return usbMonitor?.getAllUSBDevices() ?? []
    }
    
    private func getBluetoothDevices() -> [Device] {
        // 這裡需要實際的藍牙掃描實作
        // 為了示範，返回模擬資料
        return []
    }
    
    private func getNetworkInterfaces() -> [Device] {
        var interfaces: [NetworkInterface] = []
        
        let interfaceNames = SCNetworkInterfaceCopyAll()
        if let cfArray = interfaceNames as? [SCNetworkInterface] {
            for interface in cfArray {
                if let name = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String?,
                   let bsdName = SCNetworkInterfaceGetBSDName(interface) as String? {
                    
                    let hardwareAddress = SCNetworkInterfaceGetHardwareAddressString(interface) as String?
                    let isActive = SCNetworkInterfaceGetInterfaceType(interface) != nil
                    
                    let networkInterface = NetworkInterface(
                        name: name,
                        interfaceName: bsdName,
                        hardwareAddress: hardwareAddress,
                        ipAddress: getIPAddress(for: bsdName),
                        subnetMask: nil,
                        isActive: isActive,
                        mtu: 1500,
                        speed: getInterfaceSpeed(bsdName),
                        manufacturer: nil,
                        model: nil
                    )
                    interfaces.append(networkInterface)
                }
            }
        }
        
        return interfaces
    }
    
    private func getAudioDevices() -> [Device] {
        var devices: [AudioDevice] = []
        
        // 使用 CoreAudio 獲取音訊裝置
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &audioDevices)
        
        for deviceID in audioDevices {
            if let name = getAudioDeviceName(deviceID) {
                let device = AudioDevice(
                    name: name,
                    uid: getAudioDeviceUID(deviceID) ?? "",
                    isInput: hasAudioInput(deviceID),
                    isOutput: hasAudioOutput(deviceID),
                    sampleRate: getAudioSampleRate(deviceID),
                    channels: getAudioChannels(deviceID),
                    manufacturer: getAudioDeviceManufacturer(deviceID),
                    model: nil
                )
                devices.append(device)
            }
        }
        
        return devices
    }
    
    private func getDisplayDevices() -> [Device] {
        var displays: [DisplayDevice] = []
        
        var displayCount: UInt32 = 0
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        
        CGGetOnlineDisplayList(16, &displayIDs, &displayCount)
        
        for i in 0..<Int(displayCount) {
            let displayID = displayIDs[i]
            let name = getDisplayName(displayID) ?? "顯示器 \(i + 1)"
            
            let width = CGDisplayPixelsWide(displayID)
            let height = CGDisplayPixelsHigh(displayID)
            let resolution = "\(width) x \(height)"
            
            let mode = CGDisplayCopyDisplayMode(displayID)
            let refreshRate = mode?.refreshRate ?? 60.0
            
            let display = DisplayDevice(
                name: name,
                displayID: displayID,
                vendorID: CGDisplayVendorNumber(displayID),
                modelID: CGDisplayModelNumber(displayID),
                serialNumber: nil,
                resolution: resolution,
                refreshRate: refreshRate,
                isBuiltIn: CGDisplayIsBuiltin(displayID) != 0,
                manufacturer: nil,
                model: nil
            )
            displays.append(display)
        }
        
        return displays
    }
    
    private func getStorageDevices() -> [Device] {
        var devices: [StorageDevice] = []
        
        let fileManager = FileManager.default
        
        // 獲取所有掛載的磁碟區
        if let urls = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsInternalKey
        ]) {
            for url in urls {
                do {
                    let values = try url.resourceValues(forKeys: [
                        .volumeNameKey,
                        .volumeTotalCapacityKey,
                        .volumeAvailableCapacityKey,
                        .volumeIsRemovableKey,
                        .volumeIsInternalKey
                    ])
                    
                    if let name = values.volumeName,
                       let capacity = values.volumeTotalCapacity,
                       let freeSpace = values.volumeAvailableCapacity {
                        
                        let device = StorageDevice(
                            name: name,
                            bsdName: url.path,
                            volumeName: name,
                            fileSystem: nil,
                            capacity: UInt64(capacity),
                            freeSpace: UInt64(freeSpace),
                            isRemovable: values.volumeIsRemovable ?? false,
                            isInternal: values.volumeIsInternal ?? true,
                            protocol: "Unknown",
                            manufacturer: nil,
                            model: nil,
                            serialNumber: nil
                        )
                        devices.append(device)
                    }
                } catch {
                    print("Error getting volume info: \(error)")
                }
            }
        }
        
        return devices
    }
    
    // MARK: - Helper Methods
    
    private func getIPAddress(for interface: String) -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: (interface?.ifa_name)!)
                    if name == interface {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                   &hostname, socklen_t(hostname.count),
                                   nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
    
    private func getInterfaceSpeed(_ interface: String) -> String? {
        // 這需要使用更底層的 API 來獲取實際速度
        // 簡化實作
        if interface.hasPrefix("en") {
            return "1 Gbps"
        } else if interface.hasPrefix("wi") {
            return "Wi-Fi"
        }
        return nil
    }
    
    private func getAudioDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var name: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        
        let result = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &name)
        
        if result == noErr, let name = name as String? {
            return name
        }
        
        return nil
    }
    
    private func getAudioDeviceUID(_ deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var uid: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        
        let result = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &uid)
        
        if result == noErr, let uid = uid as String? {
            return uid
        }
        
        return nil
    }
    
    private func getAudioDeviceManufacturer(_ deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceManufacturerCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var manufacturer: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        
        let result = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &manufacturer)
        
        if result == noErr, let manufacturer = manufacturer as String? {
            return manufacturer
        }
        
        return nil
    }
    
    private func hasAudioInput(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let result = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        
        return result == noErr && dataSize > 0
    }
    
    private func hasAudioOutput(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let result = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        
        return result == noErr && dataSize > 0
    }
    
    private func getAudioSampleRate(_ deviceID: AudioDeviceID) -> Double {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var sampleRate: Float64 = 0
        var dataSize = UInt32(MemoryLayout<Float64>.size)
        
        AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &sampleRate)
        
        return sampleRate
    }
    
    private func getAudioChannels(_ deviceID: AudioDeviceID) -> Int {
        // 簡化實作，實際需要更複雜的邏輯
        return 2
    }
    
    private func getDisplayName(_ displayID: CGDirectDisplayID) -> String? {
        // 這需要使用 IOKit 來獲取顯示器名稱
        // 簡化實作
        if CGDisplayIsBuiltin(displayID) != 0 {
            return "內建顯示器"
        }
        return nil
    }
}
// MARK: - USB 監控管理器（修復版）
class USBMonitor: NSObject {
    private var notificationPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    
    weak var delegate: USBMonitorDelegate?
    
    override init() {
        super.init()
        setupMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func setupMonitoring() {
        // 創建通知埠
        let masterPort: mach_port_t
        if #available(macOS 12.0, *) {
            masterPort = kIOMainPortDefault
        } else {
            masterPort = kIOMasterPortDefault
        }
        
        notificationPort = IONotificationPortCreate(masterPort)
        guard let notificationPort = notificationPort else { return }
        
        let runLoopSource = IONotificationPortGetRunLoopSource(notificationPort)?.takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        
        // 設置裝置添加通知
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        IOServiceAddMatchingNotification(
            notificationPort,
            kIOFirstMatchNotification,
            matchingDict,
            deviceAdded,
            selfPtr,
            &addedIterator
        )
        
        // 處理已存在的裝置
        deviceAdded(refCon: selfPtr, iterator: addedIterator)
        
        // 設置裝置移除通知
        let terminatedDict = IOServiceMatching(kIOUSBDeviceClassName)
        IOServiceAddMatchingNotification(
            notificationPort,
            kIOTerminatedNotification,
            terminatedDict,
            deviceRemoved,
            selfPtr,
            &removedIterator
        )
        
        deviceRemoved(refCon: selfPtr, iterator: removedIterator)
    }
    
    private func stopMonitoring() {
        if addedIterator != 0 {
            IOObjectRelease(addedIterator)
        }
        if removedIterator != 0 {
            IOObjectRelease(removedIterator)
        }
        if let notificationPort = notificationPort {
            IONotificationPortDestroy(notificationPort)
        }
    }
    
    // 獲取所有當前連接的 USB 裝置
    func getAllUSBDevices() -> [USBDevice] {
        var devices: [USBDevice] = []
        
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        var iterator: io_iterator_t = 0
        
        let masterPort: mach_port_t
        if #available(macOS 12.0, *) {
            masterPort = kIOMainPortDefault
        } else {
            masterPort = kIOMasterPortDefault
        }
        
        guard IOServiceGetMatchingServices(masterPort, matchingDict, &iterator) == KERN_SUCCESS else {
            return devices
        }
        
        defer { IOObjectRelease(iterator) }
        
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            
            if let device = createUSBDevice(from: service) {
                devices.append(device)
            }
        }
        
        return devices
    }
    
    func createUSBDevice(from service: io_service_t) -> USBDevice? {
        var name = ""
        var vendorID: UInt16 = 0
        var productID: UInt16 = 0
        var locationID: UInt32 = 0
        var serialNumber: String?
        var manufacturer: String?
        var model: String?
        var speed = "未知"
        var powerRequirement = 0
        var driverInfo: String?
        
        // 獲取裝置名稱
        if let deviceName = getStringProperty(from: service, key: "USB Product Name") {
            name = deviceName
            model = deviceName
        }
        
        // 獲取廠商資訊
        manufacturer = getStringProperty(from: service, key: "USB Vendor Name")
        serialNumber = getStringProperty(from: service, key: "USB Serial Number")
        
        // 獲取數值屬性
        vendorID = UInt16(getNumberProperty(from: service, key: "idVendor"))
        productID = UInt16(getNumberProperty(from: service, key: "idProduct"))
        locationID = UInt32(getNumberProperty(from: service, key: "locationID"))
        powerRequirement = Int(getNumberProperty(from: service, key: "MaxPowerRequested"))
        
        // 獲取速度資訊
        let deviceSpeed = getNumberProperty(from: service, key: "Device Speed")
        switch deviceSpeed {
        case 0:
            speed = "低速 (1.5 Mbps)"
        case 1:
            speed = "全速 (12 Mbps)"
        case 2:
            speed = "高速 (480 Mbps)"
        case 3:
            speed = "超高速 (5 Gbps)"
        case 4:
            speed = "超高速+ (10 Gbps)"
        default:
            speed = "未知速度"
        }
        
        // 檢查驅動程式資訊
        if let driverName = getStringProperty(from: service, key: "IOProviderClass") {
            driverInfo = driverName
        } else {
            driverInfo = "系統 USB 驅動程式"
        }
        
        return USBDevice(
            name: name.isEmpty ? "未知 USB 裝置" : name,
            vendorID: vendorID,
            productID: productID,
            locationID: locationID,
            serialNumber: serialNumber,
            manufacturer: manufacturer,
            model: model,
            speed: speed,
            powerRequirement: powerRequirement,
            driverInfo: driverInfo
        )
    }
    
    private func getStringProperty(from service: io_service_t, key: String) -> String? {
        guard let property = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        
        if CFGetTypeID(property.takeUnretainedValue()) == CFStringGetTypeID() {
            return property.takeRetainedValue() as? String
        }
        
        return nil
    }
    
    private func getNumberProperty(from service: io_service_t, key: String) -> Int {
        guard let property = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
            return 0
        }
        
        if CFGetTypeID(property.takeUnretainedValue()) == CFNumberGetTypeID() {
            let cfNumber = property.takeRetainedValue() as! CFNumber
            var value: Int = 0
            CFNumberGetValue(cfNumber, .intType, &value)
            return value
        }
        
        return 0
    }
}

// MARK: - USB 監控委託協定
protocol USBMonitorDelegate: AnyObject {
    func usbDeviceConnected(_ device: USBDevice)
    func usbDeviceDisconnected()
}

// MARK: - C 回調函數
func deviceAdded(refCon: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
    let monitor = Unmanaged<USBMonitor>.fromOpaque(refCon!).takeUnretainedValue()
    
    while case let service = IOIteratorNext(iterator), service != 0 {
        defer { IOObjectRelease(service) }
        
        if let device = monitor.createUSBDevice(from: service) {
            DispatchQueue.main.async {
                monitor.delegate?.usbDeviceConnected(device)
            }
        }
    }
}

func deviceRemoved(refCon: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
    let monitor = Unmanaged<USBMonitor>.fromOpaque(refCon!).takeUnretainedValue()
    
    while case let service = IOIteratorNext(iterator), service != 0 {
        IOObjectRelease(service)
        
        DispatchQueue.main.async {
            monitor.delegate?.usbDeviceDisconnected()
        }
    }
}
// MARK: - 裝置管理器委託
protocol DeviceManagerDelegate: AnyObject {
    func deviceManagerDidUpdateDevices()
    func deviceConnected(_ device: Device)
    func deviceDisconnected(_ device: Device)
}

// MARK: - USB 監控委託擴展
extension DeviceManager: USBMonitorDelegate {
    func usbDeviceConnected(_ device: USBDevice) {
        delegate?.deviceConnected(device)
    }
    
    func usbDeviceDisconnected() {
        delegate?.deviceManagerDidUpdateDevices()
    }
}

// MARK: - 藍牙管理器委託
extension DeviceManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // 可以開始掃描藍牙裝置
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // 處理發現的藍牙裝置
    }
}
// MARK: - 增強版視窗控制器
class EnhancedViewController: NSViewController {
    
    // MARK: - UI Components
    @IBOutlet weak var splitView: NSSplitView!
    @IBOutlet weak var categoryOutlineView: NSOutlineView!
    @IBOutlet weak var deviceTableView: NSTableView!
    @IBOutlet weak var detailTextView: NSTextView!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var deviceCountLabel: NSTextField!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var filterPopUpButton: NSPopUpButton!
    
    // MARK: - Properties
    private let deviceManager = DeviceManager.shared
    private var allDevices: [Device] = []
    private var filteredDevices: [Device] = []
    private var selectedCategory: DeviceType?
    private var searchText = ""
    
    // Category tree structure
    private var deviceCategories: [(type: DeviceType, devices: [Device])] = []
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupSplitView()
        setupCategoryView()
        setupDeviceTable()
        setupDetailView()
        setupNotifications()
        
        // 設置裝置管理器委託
        deviceManager.delegate = self
        
        // 初始載入
        refreshAllDevices()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.window?.title = "macOS 裝置管理員"
        
        // 設置狀態標籤
        statusLabel.stringValue = "正在載入裝置..."
        statusLabel.textColor = .systemBlue
        
        // 設置搜尋欄位
        searchField.placeholderString = "搜尋裝置..."
        searchField.delegate = self
        
        // 設置篩選按鈕
        setupFilterMenu()
        
        // 設置重新整理按鈕
        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "重新整理")
        refreshButton.bezelStyle = .regularSquare
        refreshButton.isBordered = true
    }
    
    private func setupSplitView() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        
        // 設定預設分割比例
        if splitView.subviews.count >= 3 {
            splitView.setPosition(200, ofDividerAt: 0) // 左側分類面板寬度
            splitView.setPosition(view.frame.width - 300, ofDividerAt: 1) // 右側詳細面板寬度
        }
    }
    
    private func setupCategoryView() {
        // 設置分類大綱視圖
        categoryOutlineView.delegate = self
        categoryOutlineView.dataSource = self
        categoryOutlineView.headerView = nil
        
        // 添加圖示和名稱欄位
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CategoryColumn"))
        column.title = "裝置類別"
        column.width = 180
        categoryOutlineView.addTableColumn(column)
        categoryOutlineView.outlineTableColumn = column
        
        // 設置樣式
        categoryOutlineView.floatsGroupRows = false
        categoryOutlineView.rowSizeStyle = .default
        categoryOutlineView.focusRingType = .none
        categoryOutlineView.selectionHighlightStyle = .regular
    }
    
    private func setupDeviceTable() {
        deviceTableView.delegate = self
        deviceTableView.dataSource = self
        deviceTableView.allowsMultipleSelection = false
        deviceTableView.usesAlternatingRowBackgroundColors = true
        deviceTableView.gridStyleMask = .solidHorizontalGridLineMask
        deviceTableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        
        // 清除現有欄位
        deviceTableView.tableColumns.forEach { deviceTableView.removeTableColumn($0) }
        
        // 添加欄位
        addTableColumn(identifier: "icon", title: "", width: 30, minWidth: 30, maxWidth: 30)
        addTableColumn(identifier: "name", title: "名稱", width: 250, minWidth: 150, maxWidth: 400)
        addTableColumn(identifier: "type", title: "類型", width: 80, minWidth: 60, maxWidth: 120)
        addTableColumn(identifier: "status", title: "狀態", width: 80, minWidth: 60, maxWidth: 120)
        addTableColumn(identifier: "manufacturer", title: "製造商", width: 150, minWidth: 100, maxWidth: 250)
        addTableColumn(identifier: "connection", title: "連接資訊", width: 150, minWidth: 100, maxWidth: 300)
        addTableColumn(identifier: "driver", title: "驅動程式", width: 200, minWidth: 150, maxWidth: 350)
    }
    
    private func addTableColumn(identifier: String, title: String, width: CGFloat, minWidth: CGFloat, maxWidth: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        column.minWidth = minWidth
        column.maxWidth = maxWidth
        column.resizingMask = [.autoresizingMask, .userResizingMask]
        deviceTableView.addTableColumn(column)
    }
    
    private func setupDetailView() {
        // 設置詳細資訊文字視圖
        detailTextView.isEditable = false
        detailTextView.isSelectable = true
        detailTextView.isRichText = true
        detailTextView.font = NSFont.systemFont(ofSize: 12)
        detailTextView.textContainerInset = NSSize(width: 10, height: 10)
        detailTextView.backgroundColor = NSColor.controlBackgroundColor
        
        // 設置預設文字
        detailTextView.string = "選擇一個裝置以查看詳細資訊"
    }
    
    private func setupFilterMenu() {
        filterPopUpButton.removeAllItems()
        filterPopUpButton.addItem(withTitle: "所有裝置")
        filterPopUpButton.menu?.addItem(NSMenuItem.separator())
        
        for type in DeviceType.allCases {
            filterPopUpButton.addItem(withTitle: "\(type.icon) \(type.rawValue)")
        }
        
        filterPopUpButton.target = self
        filterPopUpButton.action = #selector(filterChanged(_:))
    }
    
    private func setupNotifications() {
        // 請求系統通知權限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("通知權限已授予")
            }
        }
    }
    
    // MARK: - Data Management
    private func refreshAllDevices() {
        statusLabel.stringValue = "正在掃描裝置..."
        statusLabel.textColor = .systemBlue
        
        DispatchQueue.global(qos: .userInitiated).async {
            let devices = self.deviceManager.getAllDevices()
            
            DispatchQueue.main.async {
                self.allDevices = devices
                self.updateDeviceCategories()
                self.applyFilter()
                self.categoryOutlineView.reloadData()
                self.categoryOutlineView.expandItem(nil, expandChildren: true)
                self.updateStatusBar()
            }
        }
    }
    
    private func updateDeviceCategories() {
        deviceCategories.removeAll()
        
        // 按類型分組裝置
        for type in DeviceType.allCases {
            let devices = allDevices.filter { $0.type == type }
            if !devices.isEmpty {
                deviceCategories.append((type: type, devices: devices))
            }
        }
    }
    
    private func applyFilter() {
        filteredDevices = allDevices
        
        // 應用類別篩選
        if let selectedCategory = selectedCategory {
            filteredDevices = filteredDevices.filter { $0.type == selectedCategory }
        }
        
        // 應用搜尋篩選
        if !searchText.isEmpty {
            filteredDevices = filteredDevices.filter { device in
                device.name.localizedCaseInsensitiveContains(searchText) ||
                (device.manufacturer?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (device.model?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        deviceTableView.reloadData()
    }
    
    private func updateStatusBar() {
        let totalCount = allDevices.count
        let displayedCount = filteredDevices.count
        
        if displayedCount == totalCount {
            deviceCountLabel.stringValue = "共 \(totalCount) 個裝置"
        } else {
            deviceCountLabel.stringValue = "顯示 \(displayedCount) / \(totalCount) 個裝置"
        }
        
        statusLabel.stringValue = "就緒"
        statusLabel.textColor = .systemGreen
    }
    
    private func showDeviceDetails(_ device: Device) {
        let details = NSMutableAttributedString()
        
        // 標題
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: NSColor.labelColor
        ]
        details.append(NSAttributedString(string: "\(device.name)\n\n", attributes: titleAttributes))
        
        // 基本資訊
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        
        details.append(NSAttributedString(string: "基本資訊\n", attributes: headerAttributes))
        details.append(NSAttributedString(string: "裝置類型: \(device.type.rawValue)\n", attributes: normalAttributes))
        details.append(NSAttributedString(string: "狀態: \(device.status)\n", attributes: normalAttributes))
        details.append(NSAttributedString(string: "連接資訊: \(device.connectionInfo)\n", attributes: normalAttributes))
        
        if let manufacturer = device.manufacturer {
            details.append(NSAttributedString(string: "製造商: \(manufacturer)\n", attributes: normalAttributes))
        }
        if let model = device.model {
            details.append(NSAttributedString(string: "型號: \(model)\n", attributes: normalAttributes))
        }
        if let serialNumber = device.serialNumber {
            details.append(NSAttributedString(string: "序號: \(serialNumber)\n", attributes: normalAttributes))
        }
        if let driverInfo = device.driverInfo {
            details.append(NSAttributedString(string: "驅動程式: \(driverInfo)\n", attributes: normalAttributes))
        }
        
        // 詳細資訊
        if !device.detailInfo.isEmpty {
            details.append(NSAttributedString(string: "\n詳細資訊\n", attributes: headerAttributes))
            
            for (key, value) in device.detailInfo.sorted(by: { $0.key < $1.key }) {
                let keyString = NSAttributedString(string: "\(key): ", attributes: [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.secondaryLabelColor
                ])
                let valueString = NSAttributedString(string: "\(value)\n", attributes: normalAttributes)
                details.append(keyString)
                details.append(valueString)
            }
        }
        
        detailTextView.textStorage?.setAttributedString(details)
    }
    
    // MARK: - Actions
    @IBAction func refreshButtonClicked(_ sender: NSButton) {
        refreshAllDevices()
    }
    
    @objc private func filterChanged(_ sender: NSPopUpButton) {
        let selectedIndex = sender.indexOfSelectedItem
        
        if selectedIndex == 0 {
            selectedCategory = nil
        } else if selectedIndex > 1 { // 跳過分隔線
            let typeIndex = selectedIndex - 2
            if typeIndex < DeviceType.allCases.count {
                selectedCategory = DeviceType.allCases[typeIndex]
            }
        }
        
        applyFilter()
    }
    
    @IBAction func exportDeviceList(_ sender: Any) {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "device_list.txt"
        savePanel.allowedContentTypes = [.plainText]
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                self.exportDevicesToFile(url)
            }
        }
    }
    
    private func exportDevicesToFile(_ url: URL) {
        var content = "macOS 裝置清單\n"
        content += "產生時間: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .medium))\n"
        content += "=" .repeating(60) + "\n\n"
        
        for category in deviceCategories {
            content += "\n[\(category.type.rawValue) 裝置] (\(category.devices.count) 個)\n"
            content += "-".repeating(40) + "\n"
            
            for device in category.devices {
                content += "\n名稱: \(device.name)\n"
                content += "狀態: \(device.status)\n"
                if let manufacturer = device.manufacturer {
                    content += "製造商: \(manufacturer)\n"
                }
                if let model = device.model {
                    content += "型號: \(model)\n"
                }
                if let serialNumber = device.serialNumber {
                    content += "序號: \(serialNumber)\n"
                }
                content += "連接資訊: \(device.connectionInfo)\n"
                if let driverInfo = device.driverInfo {
                    content += "驅動程式: \(driverInfo)\n"
                }
                content += "\n"
            }
        }
        
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            showNotification(title: "匯出成功", message: "裝置清單已匯出")
        } catch {
            showNotification(title: "匯出失敗", message: error.localizedDescription)
        }
    }
    
    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - NSOutlineViewDataSource
extension EnhancedViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return deviceCategories.count + 1 // +1 for "所有裝置"
        }
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            if index == 0 {
                return "所有裝置"
            }
            return deviceCategories[index - 1]
        }
        return ""
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
}

// MARK: - NSOutlineViewDelegate
extension EnhancedViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let cellView = NSTableCellView()
        let textField = NSTextField()
        textField.isBordered = false
        textField.isEditable = false
        textField.backgroundColor = .clear
        
        if let itemString = item as? String {
            textField.stringValue = "📁 \(itemString)"
            textField.font = NSFont.boldSystemFont(ofSize: 13)
        } else if let category = item as? (type: DeviceType, devices: [Device]) {
            textField.stringValue = "\(category.type.icon) \(category.type.rawValue) (\(category.devices.count))"
            textField.font = NSFont.systemFont(ofSize: 12)
        }
        
        cellView.textField = textField
        cellView.addSubview(textField)
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 2),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -2),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        return cellView
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        
        let selectedIndex = outlineView.selectedRow
        guard selectedIndex >= 0 else { return }
        
        let item = outlineView.item(atRow: selectedIndex)
        
        if item as? String == "所有裝置" {
            selectedCategory = nil
        } else if let category = item as? (type: DeviceType, devices: [Device]) {
            selectedCategory = category.type
        }
        
        applyFilter()
    }
}

// MARK: - NSTableViewDataSource & Delegate
extension EnhancedViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredDevices.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredDevices.count else { return nil }
        
        let device = filteredDevices[row]
        let identifier = tableColumn?.identifier.rawValue ?? ""
        
        let cellView = NSTableCellView()
        let textField = NSTextField()
        textField.isBordered = false
        textField.isEditable = false
        textField.backgroundColor = .clear
        textField.font = NSFont.systemFont(ofSize: 12)
        
        switch identifier {
        case "icon":
            textField.stringValue = device.type.icon
            textField.alignment = .center
        case "name":
            textField.stringValue = device.name
        case "type":
            textField.stringValue = device.type.rawValue
        case "status":
            textField.stringValue = device.status
            textField.textColor = device.status == "已連接" || device.status == "已啟用" ? .systemGreen : .secondaryLabelColor
        case "manufacturer":
            textField.stringValue = device.manufacturer ?? "-"
        case "connection":
            textField.stringValue = device.connectionInfo
        case "driver":
            textField.stringValue = device.driverInfo ?? "系統驅動"
        default:
            textField.stringValue = ""
        }
        
        cellView.textField = textField
        cellView.addSubview(textField)
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = deviceTableView.selectedRow
        guard selectedRow >= 0, selectedRow < filteredDevices.count else {
            detailTextView.string = "選擇一個裝置以查看詳細資訊"
            return
        }
        
        let device = filteredDevices[selectedRow]
        showDeviceDetails(device)
    }
}

// MARK: - NSSearchFieldDelegate
extension EnhancedViewController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if let searchField = obj.object as? NSSearchField {
            searchText = searchField.stringValue
            applyFilter()
        }
    }
}

// MARK: - NSSplitViewDelegate
extension EnhancedViewController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if dividerIndex == 0 {
            return 150 // 最小左側面板寬度
        } else if dividerIndex == 1 {
            return splitView.frame.width - 400 // 最小右側面板寬度
        }
        return proposedMinimumPosition
    }
    
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        if dividerIndex == 0 {
            return 300 // 最大左側面板寬度
        } else if dividerIndex == 1 {
            return splitView.frame.width - 250 // 最大右側面板寬度
        }
        return proposedMaximumPosition
    }
}

// MARK: - DeviceManagerDelegate
extension EnhancedViewController: DeviceManagerDelegate {
    func deviceManagerDidUpdateDevices() {
        refreshAllDevices()
    }
    
    func deviceConnected(_ device: Device) {
        refreshAllDevices()
        showNotification(title: "裝置已連接", message: "\(device.type.icon) \(device.name)")
        
        statusLabel.stringValue = "✅ 已連接: \(device.name)"
        statusLabel.textColor = .systemGreen
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.updateStatusBar()
        }
    }
    
    func deviceDisconnected(_ device: Device) {
        refreshAllDevices()
        showNotification(title: "裝置已斷開", message: "\(device.type.icon) \(device.name)")
        
        statusLabel.stringValue = "❌ 已斷開: \(device.name)"
        statusLabel.textColor = .systemOrange
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.updateStatusBar()
        }
    }
}
