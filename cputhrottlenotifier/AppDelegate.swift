//
//  AppDelegate.swift
//  cputhrottlenotifier
//
//  Created by Andrew Joseph Reitz on 4/16/20.
//  Copyright © 2020 andrew.cash. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    
    var throttled = false
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("StatusBarButtonImage"))
        }
        
        constructMenu()
            
        let pattern = "\\sCPU_Speed_Limit\\s+=\\s+([0-9]{1,3})"
        let regex = try! NSRegularExpression(pattern: pattern)
        
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["pmset", "-g", "thermlog"]
        let pipe = Pipe()
        task.standardOutput = pipe
        
        let outHandle = pipe.fileHandleForReading
        outHandle.waitForDataInBackgroundAndNotify()
        
        var progressObserver : NSObjectProtocol!
        progressObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSFileHandleDataAvailable,
            object: outHandle, queue: nil)
        {
            notification -> Void in
            let data = outHandle.availableData

            if data.count > 0 {
                if let str = String(data: data, encoding: String.Encoding.utf8) {
                    let result = regex.firstMatch(in:str, range:NSMakeRange(0, str.count))!
                    let matchedLimit = result.range(at: 1)
                    let range = Range(matchedLimit, in: str)
                    let cpuLimit = Int(str[range!])!
                    if (cpuLimit < 95 && !self.throttled) {
                        self.showThrottledNotification()
                        self.throttled = true
                    } else if (cpuLimit >= 95 && self.throttled) {
                        self.showNormalNotification()
                        self.throttled = false
                    }
                }
                outHandle.waitForDataInBackgroundAndNotify()
            } else {
                // That means we've reached the end of the input.
                print("End of input")
                NotificationCenter.default.removeObserver(progressObserver!)
            }
        }

        var terminationObserver : NSObjectProtocol!
        terminationObserver = NotificationCenter.default.addObserver(
            forName: Process.didTerminateNotification,
            object: task, queue: nil)
        {
            notification -> Void in
            print("End of input")
            NotificationCenter.default.removeObserver(terminationObserver!)
        }
        
        task.launch()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func constructMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Quit CPU Throttle Notifier",
            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        )
        statusItem.menu = menu
    }
    
    func showThrottledNotification() -> Void {
        let notification = NSUserNotification()
        notification.title = "CPU is being throttled"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.delegate = self
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func showNormalNotification() -> Void {
        let notification = NSUserNotification()
        notification.title = "CPU is back to normal"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.delegate = self
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
      return true
    }
}
