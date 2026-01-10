import Testing
import Foundation
@testable import app_exterminator

struct TargetApplicationTests {
    
    @Test func initializesWithRequiredParameters() {
        let url = URL(fileURLWithPath: "/Applications/Safari.app")
        let app = TargetApplication(
            url: url,
            name: "Safari",
            bundleID: "com.apple.Safari"
        )
        
        #expect(app.url == url)
        #expect(app.name == "Safari")
        #expect(app.bundleID == "com.apple.Safari")
        #expect(app.version == nil)
        #expect(app.icon == nil)
        #expect(app.isSystemApp == false)
    }
    
    @Test func initializesWithAllParameters() {
        let url = URL(fileURLWithPath: "/Applications/Safari.app")
        let app = TargetApplication(
            url: url,
            name: "Safari",
            bundleID: "com.apple.Safari",
            version: "17.0",
            icon: nil,
            isSystemApp: true
        )
        
        #expect(app.version == "17.0")
        #expect(app.isSystemApp == true)
    }
    
    @Test func equatableComparesByIdUrlAndBundleId() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/Applications/Test.app")
        
        let app1 = TargetApplication(id: id, url: url, name: "Test", bundleID: "com.test")
        let app2 = TargetApplication(id: id, url: url, name: "Different Name", bundleID: "com.test")
        
        #expect(app1 == app2)
    }
    
    @Test func equatableReturnsFalseForDifferentIds() {
        let url = URL(fileURLWithPath: "/Applications/Test.app")
        
        let app1 = TargetApplication(url: url, name: "Test", bundleID: "com.test")
        let app2 = TargetApplication(url: url, name: "Test", bundleID: "com.test")
        
        #expect(app1 != app2)
    }
    
    @Test func identifiableConformance() {
        let id = UUID()
        let app = TargetApplication(
            id: id,
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            name: "Test",
            bundleID: "com.test"
        )
        
        #expect(app.id == id)
    }
}
