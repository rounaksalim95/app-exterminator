import AppKit
import Foundation
import os.log

private nonisolated(unsafe) let logger = Logger(subsystem: "com.appexterminator", category: "HistoryManager")

actor HistoryManager {

    static let shared = HistoryManager()

    private var records: [DeletionRecord] = []
    private let fileManager = FileManager.default

    private var historyFileURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Could not locate Application Support directory")
            return nil
        }
        let appFolder = appSupport.appendingPathComponent("AppExterminator")
        return appFolder.appendingPathComponent("deletion_history.json")
    }

    private init() {}

    func load() async {
        guard let historyURL = historyFileURL else {
            records = []
            return
        }

        do {
            try ensureAppSupportDirectoryExists()

            guard fileManager.fileExists(atPath: historyURL.path) else {
                records = []
                return
            }

            let data = try Data(contentsOf: historyURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = try decoder.decode([DeletionRecord].self, from: data)
            logger.info("Loaded \(self.records.count) history records")
        } catch {
            logger.error("Failed to load history: \(error.localizedDescription)")
            records = []
        }
    }

    func save() async {
        guard let historyURL = historyFileURL else {
            logger.error("Cannot save history: no valid file URL")
            return
        }

        do {
            try ensureAppSupportDirectoryExists()

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(records)
            try data.write(to: historyURL, options: .atomic)
            logger.info("Saved \(self.records.count) history records")
        } catch {
            logger.error("Failed to save history: \(error.localizedDescription)")
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

        // Note: We no longer store icon data in history to reduce file size and privacy concerns
        // Icons can be regenerated from the app if it's reinstalled

        let record = DeletionRecord(
            date: Date(),
            appName: app.name,
            bundleID: app.bundleID,
            appIconData: nil,
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
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "HistoryManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Application Support directory not found"])
        }
        let appFolder = appSupport.appendingPathComponent("AppExterminator")

        if !fileManager.fileExists(atPath: appFolder.path) {
            try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
    }
}
