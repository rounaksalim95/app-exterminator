import AppKit
import Foundation

struct RunningAppChecker {
    
    static func isRunning(app: TargetApplication) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == app.bundleID }
    }
    
    static func getRunningInstance(of app: TargetApplication) -> NSRunningApplication? {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.first { $0.bundleIdentifier == app.bundleID }
    }
    
    @discardableResult
    static func terminate(app: TargetApplication, force: Bool = false) -> Bool {
        guard let runningApp = getRunningInstance(of: app) else {
            return true
        }
        
        if force {
            return runningApp.forceTerminate()
        } else {
            return runningApp.terminate()
        }
    }
    
    static func terminateAndWait(app: TargetApplication, force: Bool = false, timeout: TimeInterval = 5.0) async -> Bool {
        guard let runningApp = getRunningInstance(of: app) else {
            return true
        }
        
        let success = force ? runningApp.forceTerminate() : runningApp.terminate()
        
        if !success {
            return false
        }
        
        let startTime = Date()
        while runningApp.isTerminated == false {
            if Date().timeIntervalSince(startTime) > timeout {
                return false
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        return true
    }
}
