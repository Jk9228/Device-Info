//import Cocoa
//import IOKit
//import IOKit.usb
//import IOKit.usb.IOUSBLib
//import UserNotifications
//
//// MARK: - USB 裝置資料模型
//struct USBDevice {
//    let name: String
//    let vendorID: UInt16
//    let productID: UInt16
//    let locationID: UInt32
//    let serialNumber: String?
//    let manufacturer: String?
//    let speed: String
//    let powerRequirement: Int
//
//    var displayName: String {
//        return name.isEmpty ? "未知裝置" : name
//    }
//
//    var vendorIDString: String {
//        return String(format: "0x%04X", vendorID)
//    }
//
//    var productIDString: String {
//        return String(format: "0x%04X", productID)
//    }
//}
//
//// MARK: - USB 監控管理器
//class USBMonitor: NSObject {
//    private var notificationPort: IONotificationPortRef?
//    private var addedIterator: io_iterator_t = 0
//    private var removedIterator: io_iterator_t = 0
//
//    weak var delegate: USBMonitorDelegate?
//
//    override init() {
//        super.init()
//        setupMonitoring()
//    }
//
//    deinit {
//        stopMonitoring()
//    }
//
//    private func setupMonitoring() {
//        // 創建通知埠
//        if #available(macOS 12.0, *) {
//            notificationPort = IONotificationPortCreate(kIOMainPortDefault)
//        } else {
//            notificationPort = IONotificationPortCreate(kIOMasterPortDefault)
//        }
//        guard let notificationPort = notificationPort else { return }
//
//        let runLoopSource = IONotificationPortGetRunLoopSource(notificationPort)?.takeUnretainedValue()
//        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
//
//        // 設置裝置添加通知
//        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
//        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
//
//        IOServiceAddMatchingNotification(
//            notificationPort,
//            kIOFirstMatchNotification,
//            matchingDict,
//            deviceAdded,
//            selfPtr,
//            &addedIterator
//        )
//
//        // 處理已存在的裝置
//        deviceAdded(refCon: selfPtr, iterator: addedIterator)
//
//        // 設置裝置移除通知
//        let terminatedDict = IOServiceMatching(kIOUSBDeviceClassName)
//        IOServiceAddMatchingNotification(
//            notificationPort,
//            kIOTerminatedNotification,
//            terminatedDict,
//            deviceRemoved,
//            selfPtr,
//            &removedIterator
//        )
//
//        deviceRemoved(refCon: selfPtr, iterator: removedIterator)
//    }
//
//    private func stopMonitoring() {
//        if addedIterator != 0 {
//            IOObjectRelease(addedIterator)
//        }
//        if removedIterator != 0 {
//            IOObjectRelease(removedIterator)
//        }
//        if let notificationPort = notificationPort {
//            IONotificationPortDestroy(notificationPort)
//        }
//    }
//
//    // 獲取所有當前連接的 USB 裝置
//    func getAllUSBDevices() -> [USBDevice] {
//        var devices: [USBDevice] = []
//
//        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
//        var iterator: io_iterator_t = 0
//
//        let masterPort: mach_port_t
//        if #available(macOS 12.0, *) {
//            masterPort = kIOMainPortDefault
//        } else {
//            masterPort = kIOMasterPortDefault
//        }
//
//        guard IOServiceGetMatchingServices(masterPort, matchingDict, &iterator) == KERN_SUCCESS else {
//            return devices
//        }
//
//        defer { IOObjectRelease(iterator) }
//
//        while case let service = IOIteratorNext(iterator), service != 0 {
//            defer { IOObjectRelease(service) }
//
//            if let device = createUSBDevice(from: service) {
//                devices.append(device)
//            }
//        }
//
//        return devices
//    }
//
//    func createUSBDevice(from service: io_service_t) -> USBDevice? {
//        var name = ""
//        var vendorID: UInt16 = 0
//        var productID: UInt16 = 0
//        var locationID: UInt32 = 0
//        var serialNumber: String?
//        var manufacturer: String?
//        var speed = "未知"
//        var powerRequirement = 0
//
//        // 獲取裝置名稱
//        if let deviceName = getStringProperty(from: service, key: "USB Product Name") {
//            name = deviceName
//        }
//
//        // 獲取廠商資訊
//        manufacturer = getStringProperty(from: service, key: "USB Vendor Name")
//        serialNumber = getStringProperty(from: service, key: "USB Serial Number")
//
//        // 獲取數值屬性
//        vendorID = UInt16(getNumberProperty(from: service, key: "idVendor"))
//        productID = UInt16(getNumberProperty(from: service, key: "idProduct"))
//        locationID = UInt32(getNumberProperty(from: service, key: "locationID"))
//        powerRequirement = Int(getNumberProperty(from: service, key: "MaxPowerRequested"))
//
//        // 獲取速度資訊
//        let deviceSpeed = getNumberProperty(from: service, key: "Device Speed")
//        switch deviceSpeed {
//        case 0:
//            speed = "低速 (1.5 Mbps)"
//        case 1:
//            speed = "全速 (12 Mbps)"
//        case 2:
//            speed = "高速 (480 Mbps)"
//        case 3:
//            speed = "超高速 (5 Gbps)"
//        case 4:
//            speed = "超高速+ (10 Gbps)"
//        default:
//            speed = "未知速度"
//        }
//
//        return USBDevice(
//            name: name,
//            vendorID: vendorID,
//            productID: productID,
//            locationID: locationID,
//            serialNumber: serialNumber,
//            manufacturer: manufacturer,
//            speed: speed,
//            powerRequirement: powerRequirement
//        )
//    }
//
//    private func getStringProperty(from service: io_service_t, key: String) -> String? {
//        guard let property = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
//            return nil
//        }
//
//        if CFGetTypeID(property.takeUnretainedValue()) == CFStringGetTypeID() {
//            return property.takeRetainedValue() as? String
//        }
//
//        return nil
//    }
//
//    private func getNumberProperty(from service: io_service_t, key: String) -> Int {
//        guard let property = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
//            return 0
//        }
//
//        if CFGetTypeID(property.takeUnretainedValue()) == CFNumberGetTypeID() {
//            let cfNumber = property.takeRetainedValue() as! CFNumber
//            var value: Int = 0
//            CFNumberGetValue(cfNumber, .intType, &value)
//            return value
//        }
//
//        return 0
//    }
//}
//
//// MARK: - USB 監控委託協定
//protocol USBMonitorDelegate: AnyObject {
//    func usbDeviceConnected(_ device: USBDevice)
//    func usbDeviceDisconnected()
//}
//
//// MARK: - C 回調函數
//func deviceAdded(refCon: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
//    let monitor = Unmanaged<USBMonitor>.fromOpaque(refCon!).takeUnretainedValue()
//
//    while case let service = IOIteratorNext(iterator), service != 0 {
//        defer { IOObjectRelease(service) }
//
//        if let device = monitor.createUSBDevice(from: service) {
//            DispatchQueue.main.async {
//                monitor.delegate?.usbDeviceConnected(device)
//            }
//        }
//    }
//}
//
//func deviceRemoved(refCon: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
//    let monitor = Unmanaged<USBMonitor>.fromOpaque(refCon!).takeUnretainedValue()
//
//    while case let service = IOIteratorNext(iterator), service != 0 {
//        IOObjectRelease(service)
//
//        DispatchQueue.main.async {
//            monitor.delegate?.usbDeviceDisconnected()
//        }
//    }
//}
//
//// MARK: - 主視窗控制器
//class ViewController: NSViewController {
//
//    // MARK: - IBOutlets
//    @IBOutlet weak var tableView: NSTableView!
//    @IBOutlet weak var deviceCountLabel: NSTextField!
//    @IBOutlet weak var refreshButton: NSButton!
//    @IBOutlet weak var statusLabel: NSTextField!
//
//    // MARK: - Properties
//    private var usbMonitor: USBMonitor!
//    private var devices: [USBDevice] = []
//
//    // 通知設定
//    private var showSystemNotifications = true // 是否顯示系統通知
//    private var enableSoundNotifications = false // 是否播放通知聲音
//
//    // MARK: - View Lifecycle
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        setupUI()
//        setupUSBMonitor()
//        setupNotifications()
//        refreshDeviceList()
//
//    }
//    override func viewDidAppear() {
//        super.viewDidAppear()
//
//        // 調試資訊
//        print("Table columns count: \(tableView.tableColumns.count)")
//        for (index, column) in tableView.tableColumns.enumerated() {
//            print("Column \(index): \(column.title) - Width: \(column.width)")
//        }
//
//        // 強制重新載入
//        tableView.reloadData()
//    }
//
//    // MARK: - UI Setup
//    private func setupUI() {
//        title = "USB 裝置監控器"
//        statusLabel.stringValue = "監控中..."
//        statusLabel.textColor = .systemGreen
//
//        // 設置按鈕樣式
//        refreshButton.bezelStyle = .rounded
//        refreshButton.setButtonType(.momentaryPushIn)
//
//        // 設置按鈕內容優先級，避免被裁切
//        refreshButton.setContentHuggingPriority(NSLayoutConstraint.Priority(251), for: .horizontal)
//        refreshButton.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(751), for: .horizontal)
//
//        // 設置標籤內容優先級
//        deviceCountLabel.setContentHuggingPriority(NSLayoutConstraint.Priority(250), for: .horizontal)
//        statusLabel.setContentHuggingPriority(NSLayoutConstraint.Priority(252), for: .horizontal)
//
//        // 設置表格視圖
//        tableView.delegate = self
//        tableView.dataSource = self
//        tableView.allowsMultipleSelection = false
//        tableView.allowsEmptySelection = true
//        tableView.usesAlternatingRowBackgroundColors = true
//        tableView.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
//
//        // 設置表格樣式
//        tableView.intercellSpacing = NSSize(width: 1, height: 1)
//        tableView.backgroundColor = NSColor.controlBackgroundColor
//
//        // 啟用自動行高
//        tableView.usesAutomaticRowHeights = false // 先關閉自動高度
//        tableView.rowHeight = 44 // 設置固定行高
//
//        // 清除現有欄位（如果有的話）
//        tableView.tableColumns.forEach { tableView.removeTableColumn($0) }
//
//        // 添加表格欄位
//        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
//        nameColumn.title = "裝置名稱"
//        nameColumn.width = 250
//        nameColumn.minWidth = 200
//        nameColumn.maxWidth = 400
//        nameColumn.resizingMask = [.autoresizingMask, .userResizingMask]
//        tableView.addTableColumn(nameColumn)
//
//        let manufacturerColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("manufacturer"))
//        manufacturerColumn.title = "製造商"
//        manufacturerColumn.width = 120
//        manufacturerColumn.minWidth = 100
//        manufacturerColumn.maxWidth = 200
//        manufacturerColumn.resizingMask = [.autoresizingMask, .userResizingMask]
//        tableView.addTableColumn(manufacturerColumn)
//
//        let vendorColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("vendor"))
//        vendorColumn.title = "廠商ID"
//        vendorColumn.width = 100
//        vendorColumn.minWidth = 80
//        vendorColumn.maxWidth = 120
//        vendorColumn.resizingMask = .userResizingMask
//        tableView.addTableColumn(vendorColumn)
//
//        let productColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("product"))
//        productColumn.title = "產品ID"
//        productColumn.width = 100
//        productColumn.minWidth = 80
//        productColumn.maxWidth = 120
//        productColumn.resizingMask = .userResizingMask
//        tableView.addTableColumn(productColumn)
//
//        let speedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("speed"))
//        speedColumn.title = "連接速度"
//        speedColumn.width = 150
//        speedColumn.minWidth = 120
//        speedColumn.maxWidth = 200
//        speedColumn.resizingMask = [.autoresizingMask, .userResizingMask]
//        tableView.addTableColumn(speedColumn)
//
//        let serialColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("serial"))
//        serialColumn.title = "序號"
//        serialColumn.width = 180
//        serialColumn.minWidth = 150
//        serialColumn.maxWidth = 300
//        serialColumn.resizingMask = [.autoresizingMask, .userResizingMask]
//        tableView.addTableColumn(serialColumn)
//
//        // 確保顯示表頭
//        tableView.headerView = NSTableHeaderView()
//        tableView.cornerView = NSView() // 添加角落視圖
//
//        // 設置表格屬性
//        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
//        tableView.allowsColumnResizing = true
//        tableView.allowsColumnReordering = false
//        tableView.allowsColumnSelection = false
//
//        // 強制重新載入並顯示
//        DispatchQueue.main.async {
//            self.tableView.reloadData()
//            self.tableView.sizeToFit()
//            self.tableView.needsDisplay = true
//        }
//    }
//
//    private func setupUSBMonitor() {
//        usbMonitor = USBMonitor()
//        usbMonitor.delegate = self
//    }
//
//    // MARK: - 通知設置
//    private func setupNotifications() {
//        let center = UNUserNotificationCenter.current()
//
//        // 請求通知權限
//        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
//            DispatchQueue.main.async {
//                if granted {
//                    print("通知權限已獲得")
//                } else {
//                    print("通知權限被拒絕")
//                    self.showSystemNotifications = false
//                }
//
//                if let error = error {
//                    print("請求通知權限時發生錯誤: \(error.localizedDescription)")
//                }
//            }
//        }
//    }
//
//    // MARK: - IBActions
//    @IBAction func refreshButtonClicked(_ sender: NSButton) {
//        refreshDeviceList()
//    }
//
//    // MARK: - Private Methods
//    private func refreshDeviceList() {
//        devices = usbMonitor.getAllUSBDevices()
//        tableView.reloadData()
//        updateDeviceCount()
//    }
//
//    private func updateDeviceCount() {
//        deviceCountLabel.stringValue = "已連接 \(devices.count) 個 USB 裝置"
//    }
//
//    private func showDeviceDetails(_ device: USBDevice) {
//        let alert = NSAlert()
//        alert.messageText = "裝置詳細資訊"
//
//        let details = """
//        名稱: \(device.displayName)
//        製造商: \(device.manufacturer ?? "未知")
//        廠商 ID: \(device.vendorIDString)
//        產品 ID: \(device.productIDString)
//        序號: \(device.serialNumber ?? "無")
//        速度: \(device.speed)
//        位置 ID: 0x\(String(device.locationID, radix: 16).uppercased())
//        電源需求: \(device.powerRequirement) mA
//        """
//
//        alert.informativeText = details
//        alert.alertStyle = .informational
//        alert.addButton(withTitle: "確定")
//        alert.runModal()
//    }
//}
//
//// MARK: - USB Monitor Delegate
//extension ViewController: USBMonitorDelegate {
//    func usbDeviceConnected(_ device: USBDevice) {
//        refreshDeviceList()
//
//        // 更新狀態標籤顯示連接訊息
//        statusLabel.stringValue = "✅ 已連接: \(device.displayName)"
//        statusLabel.textColor = .systemGreen
//
//        // 3秒後恢復為監控狀態
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
//            self.statusLabel.stringValue = "監控中..."
//            self.statusLabel.textColor = .systemGreen
//        }
//
//        // 可選：顯示 macOS 系統通知（不會打斷用戶）
//        showSystemNotification(title: "USB 裝置已連接", message: device.displayName)
//    }
//
//    func usbDeviceDisconnected() {
//        refreshDeviceList()
//
//        // 更新狀態標籤顯示斷開訊息
//        statusLabel.stringValue = "❌ 裝置已斷開"
//        statusLabel.textColor = .systemOrange
//
//        // 3秒後恢復為監控狀態
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
//            self.statusLabel.stringValue = "監控中..."
//            self.statusLabel.textColor = .systemGreen
//        }
//
//        // 可選：顯示 macOS 系統通知
//        showSystemNotification(title: "USB 裝置已斷開", message: "一個裝置已斷開連接")
//    }
//
//    // MARK: - 系統通知方法
//    private func showSystemNotification(title: String, message: String) {
//        // 檢查是否啟用系統通知
//        guard showSystemNotifications else { return }
//
//        let center = UNUserNotificationCenter.current()
//
//        // 創建通知內容
//        let content = UNMutableNotificationContent()
//        content.title = title
//        content.body = message
//        content.categoryIdentifier = "USB_DEVICE_NOTIFICATION"
//
//        // 根據設定決定是否播放聲音
//        if enableSoundNotifications {
//            content.sound = UNNotificationSound.default
//        } else {
//            content.sound = nil
//        }
//
//        // 創建通知請求
//        let identifier = UUID().uuidString
//        let request = UNNotificationRequest(
//            identifier: identifier,
//            content: content,
//            trigger: nil // 立即發送
//        )
//
//        // 發送通知
//        center.add(request) { error in
//            if let error = error {
//                print("發送通知失敗: \(error.localizedDescription)")
//            }
//        }
//    }
//
//    // MARK: - 通知設定方法
//    func toggleSystemNotifications() {
//        showSystemNotifications.toggle()
//        let status = showSystemNotifications ? "已開啟" : "已關閉"
//        statusLabel.stringValue = "系統通知\(status)"
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//            self.statusLabel.stringValue = "監控中..."
//            self.statusLabel.textColor = .systemGreen
//        }
//    }
//}
//
//// MARK: - Table View Data Source & Delegate
//extension ViewController: NSTableViewDataSource, NSTableViewDelegate {
//    func numberOfRows(in tableView: NSTableView) -> Int {
//        return devices.count
//    }
//
//    // 動態計算行高（改進版）
//    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
//        guard row < devices.count else { return 44 }
//
//        let device = devices[row]
//        let font = NSFont.systemFont(ofSize: 13)
//
//        // 取得各欄位實際寬度
//        let columns = tableView.tableColumns
//        var maxHeight: CGFloat = 44 // 最小高度
//
//        for column in columns {
//            var content = ""
//            let identifier = column.identifier.rawValue
//
//            switch identifier {
//            case "name":
//                content = device.displayName
//            case "manufacturer":
//                content = device.manufacturer ?? "未知"
//            case "vendor":
//                content = device.vendorIDString
//            case "product":
//                content = device.productIDString
//            case "speed":
//                content = device.speed
//            case "serial":
//                content = device.serialNumber ?? "無"
//            default:
//                content = ""
//            }
//
//            // 使用實際欄位寬度計算高度
//            let columnWidth = column.width - 16 // 減去左右邊距
//            let boundingRect = content.boundingRect(
//                with: NSSize(width: columnWidth, height: CGFloat.greatestFiniteMagnitude),
//                options: [.usesLineFragmentOrigin, .usesFontLeading],
//                attributes: [NSAttributedString.Key.font: font]
//            )
//
//            let requiredHeight = boundingRect.height + 8 // 加上上下邊距
//            maxHeight = max(maxHeight, requiredHeight)
//        }
//
//        return min(maxHeight, 120) // 設置最大高度限制
//    }
//
//    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
//        guard row < devices.count else { return nil }
//
//        let device = devices[row]
//        let identifier = tableColumn?.identifier.rawValue ?? ""
//
//        let cellView = NSTableCellView()
//        let textField = NSTextField()
//        textField.isBordered = false
//        textField.isEditable = false
//        textField.backgroundColor = .clear
//        textField.font = NSFont.systemFont(ofSize: 13)
//
//        // 啟用多行文字和自動換行，但限制在欄位寬度內
//        textField.maximumNumberOfLines = 0 // 0 表示無限制
//        textField.cell?.wraps = true
//        textField.cell?.isScrollable = false
//        textField.lineBreakMode = .byWordWrapping
//
//        // 重要：設置文字不能超出邊界
//        textField.cell?.usesSingleLineMode = false
//        textField.cell?.truncatesLastVisibleLine = true
//
//        // 設置文字內容
//        switch identifier {
//        case "name":
//            textField.stringValue = device.displayName
//        case "manufacturer":
//            textField.stringValue = device.manufacturer ?? "未知"
//        case "vendor":
//            textField.stringValue = device.vendorIDString
//        case "product":
//            textField.stringValue = device.productIDString
//        case "speed":
//            textField.stringValue = device.speed
//        case "serial":
//            textField.stringValue = device.serialNumber ?? "無"
//        default:
//            textField.stringValue = ""
//        }
//
//        // 設置 textField 為 cellView 的主要 textField
//        cellView.textField = textField
//        cellView.addSubview(textField)
//
//        // 設置約束以支援動態高度，但嚴格限制寬度
//        textField.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
//            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
//            textField.topAnchor.constraint(equalTo: cellView.topAnchor, constant: 4),
//            textField.bottomAnchor.constraint(equalTo: cellView.bottomAnchor, constant: -4)
//        ])
//
//        // 設置內容優先級，防止文字溢出
//        textField.setContentHuggingPriority(NSLayoutConstraint.Priority(250), for: .horizontal)
//        textField.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(250), for: .horizontal)
//
//        return cellView
//    }
//
//    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
//        guard row < devices.count else { return false }
//
//        let device = devices[row]
//        showDeviceDetails(device)
//        return true
//    }
//}
