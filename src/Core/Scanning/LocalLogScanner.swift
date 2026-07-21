import Foundation

public struct ProviderLogRoot: Equatable, Sendable {
    public var provider: Provider
    public var path: String

    public init(provider: Provider, path: String) {
        self.provider = provider
        self.path = path
    }
}

public struct CandidateSourceFile: Equatable, Sendable {
    public var provider: Provider
    public var path: String

    public init(provider: Provider, path: String) {
        self.provider = provider
        self.path = path
    }
}

public struct LocalLogScanner: Sendable {
    public var providerRoots: [ProviderLogRoot]
    public var candidateExtensions: Set<String>

    public init(
        providerRoots: [ProviderLogRoot] = LocalLogScanner.defaultProviderRoots(),
        candidateExtensions: Set<String> = LocalLogScanner.defaultCandidateExtensions
    ) {
        self.providerRoots = providerRoots
        self.candidateExtensions = Set(candidateExtensions.map { $0.lowercased() })
    }

    public static let defaultCandidateExtensions: Set<String> = [
        "json",
        "jsonl",
        "log"
    ]

    public static func defaultProviderRoots(homeDirectory: String = NSHomeDirectory()) -> [ProviderLogRoot] {
        [
            ProviderLogRoot(provider: .claude, path: "\(homeDirectory)/.claude"),
            ProviderLogRoot(provider: .codex, path: "\(homeDirectory)/.codex")
        ]
    }

    public func scan() -> [CandidateSourceFile] {
        var discovered: [CandidateSourceFile] = []
        var seenCanonicalPaths = Set<String>()

        for root in orderedRoots(providerRoots) {
            let rootURL = URL(fileURLWithPath: root.path)

            guard isReadableDirectory(rootURL) else {
                continue
            }

            for fileURL in candidateFiles(under: rootURL) {
                let canonicalPath = canonicalPath(for: fileURL)

                guard seenCanonicalPaths.insert(canonicalPath).inserted else {
                    continue
                }

                discovered.append(CandidateSourceFile(provider: root.provider, path: canonicalPath))
            }
        }

        return discovered.sorted {
            if $0.provider.rawValue != $1.provider.rawValue {
                return $0.provider.rawValue < $1.provider.rawValue
            }

            return $0.path < $1.path
        }
    }

    private func orderedRoots(_ roots: [ProviderLogRoot]) -> [ProviderLogRoot] {
        roots.sorted {
            if $0.provider.rawValue != $1.provider.rawValue {
                return $0.provider.rawValue < $1.provider.rawValue
            }

            return canonicalPath(for: URL(fileURLWithPath: $0.path)) < canonicalPath(for: URL(fileURLWithPath: $1.path))
        }
    }

    private func candidateFiles(under rootURL: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isReadableKey],
            options: [.skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var files: [URL] = []

        for case let fileURL as URL in enumerator {
            guard isCandidateFile(fileURL) else {
                continue
            }

            files.append(fileURL)
        }

        return files.sorted { canonicalPath(for: $0) < canonicalPath(for: $1) }
    }

    private func isCandidateFile(_ fileURL: URL) -> Bool {
        guard candidateExtensions.contains(fileURL.pathExtension.lowercased()) else {
            return false
        }

        guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            return false
        }

        guard isLikelyProviderUsagePath(fileURL.path) else {
            return false
        }

        return FileManager.default.isReadableFile(atPath: fileURL.path)
    }

    private func isLikelyProviderUsagePath(_ path: String) -> Bool {
        if path.contains("/.claude/projects/") && path.hasSuffix(".jsonl") {
            return true
        }

        if path.contains("/.codex/sessions/") && path.hasSuffix(".jsonl") {
            return true
        }

        return false
    }

    private func isReadableDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        return FileManager.default.isReadableFile(atPath: url.path)
    }

    private func canonicalPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
