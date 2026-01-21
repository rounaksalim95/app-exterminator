import AppKit
import Foundation
import os.log

private enum Log: Sendable {
    nonisolated static let logger = Logger(subsystem: "com.appexterminator", category: "HistoryManager")
}

private extension NSImage {
    /// Converts NSImage to PNG data at a specified maximum size
    /// This is more reliable for JSON serialization than TIFF
    func pngData(maxSize: CGFloat) -> Data? {
        // Create a scaled-down version of the image
        let targetSize = NSSize(width: maxSize, height: maxSize)

        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high
        self.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: self.size),
            operation: .copy,
            fraction: 1.0
        )

        newImage.unlockFocus()

        // Convert to PNG
        guard let tiffData = newImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        return pngData
    }
}

actor HistoryManager {

    static let shared = HistoryManager()

    private var records: [DeletionRecord] = []
    private let fileManager = FileManager.default

    private var historyFileURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            Log.logger.error("Could not locate Application Support directory")
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
            Log.logger.info("Loaded \(self.records.count) history records")
        } catch {
            Log.logger.error("Failed to load history: \(error.localizedDescription)")
            records = []
        }
    }

    func save() async {
        guard let historyURL = historyFileURL else {
            Log.logger.error("Cannot save history: no valid file URL")
            return
        }

        do {
            try ensureAppSupportDirectoryExists()

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(records)
            try data.write(to: historyURL, options: .atomic)
            Log.logger.info("Saved \(self.records.count) history records")
        } catch {
            Log.logger.error("Failed to save history: \(error.localizedDescription)")
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
            iconData = icon.pngData(maxSize: 64)
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
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "HistoryManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Application Support directory not found"])
        }
        let appFolder = appSupport.appendingPathComponent("AppExterminator")

        if !fileManager.fileExists(atPath: appFolder.path) {
            try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
    }
}
