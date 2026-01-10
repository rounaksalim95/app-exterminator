import Testing
import Foundation
@testable import app_exterminator

struct DiscoveredFileTests {
    
    @Test func initializesWithDefaults() {
        let url = URL(fileURLWithPath: "/Applications/Test.app")
        let file = DiscoveredFile(url: url, category: .application)
        
        #expect(file.url == url)
        #expect(file.category == .application)
        #expect(file.size == 0)
        #expect(file.requiresAdmin == false)
    }
    
    @Test func initializesWithAllParameters() {
        let url = URL(fileURLWithPath: "/Library/LaunchDaemons/com.test.plist")
        let file = DiscoveredFile(
            url: url,
            category: .launchDaemons,
            size: 1024,
            requiresAdmin: true
        )
        
        #expect(file.url == url)
        #expect(file.category == .launchDaemons)
        #expect(file.size == 1024)
        #expect(file.requiresAdmin == true)
    }
    
    @Test func formattedSizeReturnsHumanReadable() {
        let url = URL(fileURLWithPath: "/test")
        
        let smallFile = DiscoveredFile(url: url, category: .other, size: 500)
        #expect(smallFile.formattedSize.contains("bytes") || smallFile.formattedSize.contains("B"))
        
        let mbFile = DiscoveredFile(url: url, category: .other, size: 1_048_576)
        #expect(mbFile.formattedSize.contains("MB") || mbFile.formattedSize.contains("1"))
        
        let gbFile = DiscoveredFile(url: url, category: .other, size: 1_073_741_824)
        #expect(gbFile.formattedSize.contains("GB") || gbFile.formattedSize.contains("1"))
    }
    
    @Test func displayPathReplacesHomeWithTilde() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let testPath = "\(homeDir)/Library/Caches/com.test"
        let url = URL(fileURLWithPath: testPath)
        let file = DiscoveredFile(url: url, category: .caches)
        
        #expect(file.displayPath.hasPrefix("~"))
        #expect(!file.displayPath.contains(homeDir))
    }
    
    @Test func displayPathPreservesSystemPaths() {
        let url = URL(fileURLWithPath: "/Library/LaunchDaemons/com.test.plist")
        let file = DiscoveredFile(url: url, category: .launchDaemons)
        
        #expect(file.displayPath == "/Library/LaunchDaemons/com.test.plist")
    }
    
    @Test func hashableConformance() {
        let url = URL(fileURLWithPath: "/test")
        let file1 = DiscoveredFile(id: UUID(), url: url, category: .application)
        let file2 = DiscoveredFile(id: file1.id, url: url, category: .application)
        let file3 = DiscoveredFile(id: UUID(), url: url, category: .application)
        
        #expect(file1.hashValue == file2.hashValue)
        #expect(file1.hashValue != file3.hashValue)
    }
    
    @Test func equatableComparesById() {
        let url = URL(fileURLWithPath: "/test")
        let sharedId = UUID()
        let file1 = DiscoveredFile(id: sharedId, url: url, category: .application)
        let file2 = DiscoveredFile(id: sharedId, url: url, category: .caches)
        
        #expect(file1 == file2)
    }
}
