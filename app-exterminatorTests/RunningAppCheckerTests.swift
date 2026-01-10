import Testing
import Foundation
@testable import app_exterminator

struct RunningAppCheckerTests {
    
    @Test func detectsRunningApp() {
        let finderApp = TargetApplication(
            url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
            name: "Finder",
            bundleID: "com.apple.finder",
            isSystemApp: true
        )
        
        #expect(RunningAppChecker.isRunning(app: finderApp) == true)
    }
    
    @Test func detectsNonRunningApp() {
        let fakeApp = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/NonExistent.app"),
            name: "NonExistent",
            bundleID: "com.nonexistent.fakeapp"
        )
        
        #expect(RunningAppChecker.isRunning(app: fakeApp) == false)
    }
    
    @Test func getsRunningInstance() {
        let finderApp = TargetApplication(
            url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
            name: "Finder",
            bundleID: "com.apple.finder",
            isSystemApp: true
        )
        
        let runningInstance = RunningAppChecker.getRunningInstance(of: finderApp)
        #expect(runningInstance != nil)
        #expect(runningInstance?.bundleIdentifier == "com.apple.finder")
    }
    
    @Test func returnsNilForNonRunningApp() {
        let fakeApp = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/NonExistent.app"),
            name: "NonExistent",
            bundleID: "com.nonexistent.fakeapp"
        )
        
        let runningInstance = RunningAppChecker.getRunningInstance(of: fakeApp)
        #expect(runningInstance == nil)
    }
    
    @Test func terminateReturnsTrueForNonRunningApp() {
        let fakeApp = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/NonExistent.app"),
            name: "NonExistent",
            bundleID: "com.nonexistent.fakeapp"
        )
        
        let result = RunningAppChecker.terminate(app: fakeApp)
        #expect(result == true)
    }
    
    @Test func terminateAndWaitReturnsTrueForNonRunningApp() async {
        let fakeApp = TargetApplication(
            url: URL(fileURLWithPath: "/Applications/NonExistent.app"),
            name: "NonExistent",
            bundleID: "com.nonexistent.fakeapp"
        )
        
        let result = await RunningAppChecker.terminateAndWait(app: fakeApp)
        #expect(result == true)
    }
}
