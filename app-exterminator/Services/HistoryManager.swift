import AppKit
import Foundation

actor HistoryManager {
    
    static let shared = HistoryManager()
    
    private var records: [DeletionRecord] = []
    private let fileManager = FileManager.default
    
    private var historyFileURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("AppExterminator")
        return appFolder.appendingPathComponent("deletion_history.json")
    }
    
    private init() {}
    
    func load() async {
        do {
            try ensureAppSupportDirectoryExists()
            
            guard fileManager.fileExists(atPath: historyFileURL.path) else {
                records = []
                return
            }
            
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = try decoder.decode([DeletionRecord].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
            records = []
        }
    }
    
    func save() async {
        do {
            try ensureAppSupportDirectoryExists()
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(records)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed to save history: \(error)")
        }
    }
    
    func addRecord(_ record: DeletionRecord) async {
        records.insert(record, at: 0)
        await save()
    }
    
    @MainActor
    func createRecord(from app: TargetApplication, deletionResult: DeletionResult) async -> DeletionRecord {
        let deletedFileRecords = deletionResult.successfulDeletions.map { file in
            DeletedFileRecord(
                id: file.id,
                originalPath: file.url.path,
                category: file.category,
                size: file.size
            )
        }
        
        var iconData: Data? = nil
        if let icon = app.icon {
            iconData = icon.tiffRepresentation
        }
        
        let record = DeletionRecord(
            date: Date(),
            appName: app.name,
            bundleID: app.bundleID,
            appIconData: iconData,
            deletedFiles: deletedFileRecords
        )
        
        await addRecord(record)
        return record
    }
    
    func getAllRecords() async -> [DeletionRecord] {
        return records
    }
    
    func getRecord(by id: UUID) async -> DeletionRecord? {
        return records.first { $0.id == id }
    }
    
    func deleteRecord(by id: UUID) async {
        records.removeAll { $0.id == id }
        await save()
    }
    
    func clearHistory() async {
        records.removeAll()
        await save()
    }
    
    func getMostRecentRecord() async -> DeletionRecord? {
        return records.first
    }
    
    private func ensureAppSupportDirectoryExists() throws {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("AppExterminator")
        
        if !fileManager.fileExists(atPath: appFolder.path) {
            try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
    }
}
