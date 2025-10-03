//
//  AppDelegate.swift
//  Deveice Info
//
//  Created by 古峻瑋 on 2025/9/19.
//

import Cocoa

@main
// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 應用程式啟動後的設定
    }
    
    func applicationWillTerminate(_ anotification: Notification) {
        // 應用程式終止前的清理
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return true
    }
}
