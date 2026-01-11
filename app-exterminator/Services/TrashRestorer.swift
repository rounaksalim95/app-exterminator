import Foundation

enum RestoreError: LocalizedError {
    case fileNotInTrash(originalPath: String)
    case destinationOccupied(path: String)
    case permissionDenied(path: String)
    case parentDirectoryMissing(path: String)
    case moveFailed(path: String, reason: String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotInTrash(let path):
            return "File no longer in Trash: \((path as NSString).lastPathComponent)"
        case .destinationOccupied(let path):
            return "Original location is occupied: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .parentDirectoryMissing(let path):
            return "Parent directory missing: \((path as NSString).deletingLastPathComponent)"
        case .moveFailed(let path, let reason):
            return "Failed to restore \((path as NSString).lastPathComponent): \(reason)"
        }
    }
}

struct RestoreResult {
    let successfulRestores: [DeletedFileRecord]
    let failedRestores: [(file: DeletedFileRecord, error: Error)]
    let notInTrash: [DeletedFileRecord]
    
    var totalRestored: Int { successfulRestores.count }
    var totalFailed: Int { failedRestores.count }
    var totalNotInTrash: Int { notInTrash.count }
    
    var isComplete: Bool {
        failedRestores.isEmpty && notInTrash.isEmpty
    }
    
    var restoredSize: Int64 {
        successfulRestores.reduce(0) { $0 + $1.size }
    }
    
    var formattedRestoredSize: String {
        ByteCountFormatter.string(fromByteCount: restoredSize, countStyle: .file)
    }
}

actor TrashRestorer {
    
    private let fileManager = FileManager.default
    
    func restore(files: [DeletedFileRecord]) async -> RestoreResult {
        var successfulRestores: [DeletedFileRecord] = []
        var failedRestores: [(file: DeletedFileRecord, error: Error)] = []
        var notInTrash: [DeletedFileRecord] = []
        
        for file in files {
            let result = await restoreFile(file)
            
            switch result {
            case .success:
                successfulRestores.append(file)
            case .failure(let error):
                if case RestoreError.fileNotInTrash = error {
                    notInTrash.append(file)
                } else {
                    failedRestores.append((file: file, error: error))
                }
            }
        }
        
        return RestoreResult(
            successfulRestores: successfulRestores,
            failedRestores: failedRestores,
            notInTrash: notInTrash
        )
    }
    
    func canRestore(file: DeletedFileRecord) async -> Bool {
        return findInTrash(originalPath: file.originalPath) != nil
    }
    
    func canRestoreAny(files: [DeletedFileRecord]) async -> Bool {
        for file in files {
            if await canRestore(file: file) {
                return true
            }
        }
        return false
    }
    
    private func restoreFile(_ file: DeletedFileRecord) async -> Result<Void, Error> {
        guard let trashURL = findInTrash(originalPath: file.originalPath) else {
            return .failure(RestoreError.fileNotInTrash(originalPath: file.originalPath))
        }
        
        let originalURL = URL(fileURLWithPath: file.originalPath)
        
        if fileManager.fileExists(atPath: file.originalPath) {
            return .failure(RestoreError.destinationOccupied(path: file.originalPath))
        }
        
        let parentDir = originalURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            do {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            } catch {
                return .failure(RestoreError.parentDirectoryMissing(path: file.originalPath))
            }
        }
        
        do {
            try fileManager.moveItem(at: trashURL, to: originalURL)
            return .success(())
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteNoPermissionError {
                return .failure(RestoreError.permissionDenied(path: file.originalPath))
            }
            return .failure(RestoreError.moveFailed(path: file.originalPath, reason: error.localizedDescription))
        }
    }
    
    private func findInTrash(originalPath: String) -> URL? {
        guard let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileName = (originalPath as NSString).lastPathComponent
        
        let directMatch = trashURL.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: directMatch.path) {
            return directMatch
        }
        
        do {
            let trashContents = try fileManager.contentsOfDirectory(
                at: trashURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            let baseName = (fileName as NSString).deletingPathExtension
            let ext = (fileName as NSString).pathExtension
            
            for item in trashContents {
                let itemName = item.lastPathComponent
                let itemBaseName = (itemName as NSString).deletingPathExtension
                let itemExt = (itemName as NSString).pathExtension
                
                if itemExt == ext {
                    if itemBaseName == baseName {
                        return item
                    }
                    if itemBaseName.hasPrefix(baseName + " ") {
                        let suffix = String(itemBaseName.dropFirst(baseName.count + 1))
                        if Int(suffix) != nil {
                            return item
                        }
                    }
                }
            }
        } catch {
            return nil
        }
        
        return nil
    }
}
