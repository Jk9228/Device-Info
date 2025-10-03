import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedFile: URL?
    @State private var isShowingFilePicker = false
    @State private var conversionStatus = ""
    @State private var isConverting = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("PPT to PDF Converter")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                if let selectedFile = selectedFile {
                    Text("Selected: \(selectedFile.lastPathComponent)")
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
    
    private func openInPowerPoint() {
        guard let inputURL = selectedFile else { return }
        
        let script = """
        tell application "Microsoft PowerPoint"
            activate
            open "\(inputURL.path)"
        end tell
        """
        
        if let scriptObject = NSAppleScript(source: script) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)
            
            if error == nil {
                conversionStatus = "已在PowerPoint中打開文件。請手動選擇 文件 > 導出為 > PDF"
            } else {
                conversionStatus = "無法打開PowerPoint"
            }
        }
    }
                
                Button("Select PPT/PPTX File") {
                    isShowingFilePicker = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            if selectedFile != nil {
                Button("Convert to PDF") {
                    convertToPDF()
                }
                .padding()
                .background(isConverting ? Color.gray : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(isConverting)
            }
            
            if !conversionStatus.isEmpty {
                Text(conversionStatus)
                    .foregroundColor(conversionStatus.contains("Error") ? .red : .green)
                    .padding()
            }
            
            if isConverting {
                ProgressView("Converting...")
                    .padding()
            }
            
            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "ppt")!,
                UTType(filenameExtension: "pptx")!
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedFile = url
                    conversionStatus = ""
                }
            case .failure(let error):
                conversionStatus = "Error selecting file: \(error.localizedDescription)"
            }
        }
    }
    
    private func convertToPDF() {
        guard let inputURL = selectedFile else { return }
        
        isConverting = true
        conversionStatus = "Converting..."
        
        // 創建輸出文件路径
        let outputURL = inputURL.deletingPathExtension().appendingPathExtension("pdf")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 使用AppleScript調用PowerPoint進行轉換
            let (success, message) = convertPPTToPDFUsingPowerPoint(inputURL: inputURL, outputURL: outputURL)
            
            DispatchQueue.main.async {
                isConverting = false
                if success {
                    conversionStatus = "成功轉換為: \(outputURL.lastPathComponent)"
                    // 在Finder中顯示文件
                    NSWorkspace.shared.activateFileViewerSelecting([outputURL])
                } else {
                    conversionStatus = "錯誤: \(message)"
                }
            }
        }
    }
}

// 穩定版PowerPoint轉換，確保應用程式正確啟動
func convertPPTToPDFUsingPowerPoint(inputURL: URL, outputURL: URL) -> (Bool, String) {
    let script = """
    try
        -- 先檢查PowerPoint是否已安裝
        tell application "System Events"
            if not (exists application process "Microsoft PowerPoint") then
                tell application "Microsoft PowerPoint"
                    activate
                    delay 3
                end tell
            end if
        end tell
        
        tell application "Microsoft PowerPoint"
            -- 確保應用程式運行
            if not running then
                activate
                delay 5
            end if
            
            -- 打開文件
            set thePresentation to open "\(inputURL.path)"
            delay 5
            
            -- 確認文檔已打開
            if thePresentation exists then
                -- 導出為PDF
                save thePresentation in "\(outputURL.path)" as PDF
                delay 2
                
                -- 關閉文檔
                close thePresentation saving no
                
                return "success"
            else
                return "無法打開PowerPoint文檔"
            end if
            
        end tell
        
    on error errorMessage
        -- 清理工作
        try
            tell application "Microsoft PowerPoint"
                if exists thePresentation then
                    close thePresentation saving no
                end if
            end tell
        end try
        
        return "執行錯誤: " & errorMessage
    end try
    """
    
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
        let result = scriptObject.executeAndReturnError(&error)
        
        if let error = error {
            let errorMsg = error["NSAppleScriptErrorMessage"] as? String ?? error.description
            return (false, "AppleScript錯誤: \(errorMsg)")
        }
        
        if let resultString = result.stringValue {
            if resultString == "success" {
                // 檢查PDF文件是否真的被創建
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    return (true, "轉換成功")
                } else {
                    return (false, "PDF文件未被創建，可能是PowerPoint版本不支持該格式")
                }
            } else {
                return (false, resultString)
            }
        }
        
        return (false, "腳本執行完成但沒有返回結果")
    }
    
    return (false, "無法創建AppleScript")
}

