import Foundation

enum ToolEventPathNormalizer {
    static func normalizedPath(_ path: String, workingDirectory: String?) -> String? {
        guard !path.isEmpty else {
            return nil
        }

        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL.path
        }

        guard let workingDirectory, !workingDirectory.isEmpty else {
            return path
        }

        return URL(fileURLWithPath: path, relativeTo: URL(fileURLWithPath: workingDirectory, isDirectory: true))
            .standardizedFileURL
            .path
    }
}
