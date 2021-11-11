//
//  AppDelegate.swift
//  Prospect
//
//  Created by Vogel Family on 11/9/21.
//

import Cocoa
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    
    
    func applicationWillFinishLaunching(_ notification: Notification) {
//        print("application will finish launching!")
        
        SUUpdater.shared()?.automaticallyChecksForUpdates = true

        SUUpdater.shared()?.feedURL = URL(string: "https://jaromvogel.com/prospect/appcast.xml")
        
        SUUpdater.shared()?.checkForUpdatesInBackground()
//        SUUpdater.shared()?.checkForUpdates(nil)
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {}
    
}
