import Testing
import Foundation
@testable import app_exterminator

struct FileCategoryTests {
    
    @Test func allCasesHaveDisplayNames() {
        for category in FileCategory.allCases {
            #expect(!category.displayName.isEmpty)
        }
    }
    
    @Test func allCasesHaveSystemImages() {
        for category in FileCategory.allCases {
            #expect(!category.systemImage.isEmpty)
        }
    }
    
    @Test func identifiableConformance() {
        let category = FileCategory.application
        #expect(category.id == category.rawValue)
    }
    
    @Test func codableConformance() throws {
        let original = FileCategory.applicationSupport
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FileCategory.self, from: encoded)
        #expect(decoded == original)
    }
    
    @Test func displayNameValues() {
        #expect(FileCategory.application.displayName == "Application")
        #expect(FileCategory.preferences.displayName == "Preferences")
        #expect(FileCategory.caches.displayName == "Caches")
        #expect(FileCategory.launchAgents.displayName == "Launch Agents")
    }
}
