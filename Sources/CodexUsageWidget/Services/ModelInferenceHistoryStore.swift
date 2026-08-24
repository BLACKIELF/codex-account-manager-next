import Foundation

enum ModelInferenceHistoryStore {
    static let maximumSampleCount = 50_000

    private static let schemaVersion = 1
    private static let maximumArchiveBytes: Int64 = 32 * 1_024 * 1_024

    private struct DiskEnvelope: Codable {
        let version: Int
        let archive: ModelInferenceHistoryArchive
    }

    static func sourceIdentifier(threadID: String?, rolloutPath: String) -> String {
        if let threadID {
            let normalized = threadID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty { return normalized }
        }

        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in rolloutPath.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "rollout-\(String(hash, radix: 16))"
    }

    static func load(fileManager: FileManager = .default, now: Date) -> ModelInferenceHistoryArchive {
        guard let url = archiveURL(fileManager: fileManager),
              let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              Int64(values.fileSize ?? 0) <= maximumArchiveBytes,
              let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(DiskEnvelope.self, from: data),
              envelope.version == schemaVersion
        else {
            return ModelInferenceHistoryArchive(recordingStartedAt: now)
        }
        return envelope.archive
    }

    @discardableResult
    static func save(
        _ archive: ModelInferenceHistoryArchive,
        fileManager: FileManager = .default
    ) -> Bool {
        guard let url = archiveURL(fileManager: fileManager) else { return false }
        do {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(DiskEnvelope(version: schemaVersion, archive: archive))
            guard Int64(data.count) <= maximumArchiveBytes else { return false }
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func archiveURL(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CodexAccountManagerNext", isDirectory: true)
            .appendingPathComponent("inference-performance-v1.json")
    }
}
