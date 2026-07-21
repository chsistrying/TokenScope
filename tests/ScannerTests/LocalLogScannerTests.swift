import Foundation
import XCTest
@testable import TokenScope

final class LocalLogScannerTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }

        temporaryDirectories.removeAll()
        try super.tearDownWithError()
    }

    func testDefaultProviderRootsUseClaudeAndCodexUnderHomeDirectory() {
        let roots = LocalLogScanner.defaultProviderRoots(homeDirectory: "/tmp/example-home")

        XCTAssertEqual(roots, [
            ProviderLogRoot(provider: .claude, path: "/tmp/example-home/.claude"),
            ProviderLogRoot(provider: .codex, path: "/tmp/example-home/.codex")
        ])
    }

    func testMissingRootsReturnNoCandidates() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let scanner = LocalLogScanner(providerRoots: [
            ProviderLogRoot(provider: .claude, path: tempDirectory.appendingPathComponent("missing-claude").path),
            ProviderLogRoot(provider: .codex, path: tempDirectory.appendingPathComponent("missing-codex").path)
        ])

        XCTAssertEqual(scanner.scan(), [])
    }

    func testRecursivelyDiscoversCandidatesWithProviderAttribution() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let claudeRoot = tempDirectory.appendingPathComponent(".claude")
        let codexRoot = tempDirectory.appendingPathComponent(".codex")

        try createFile(at: claudeRoot.appendingPathComponent("projects/alpha/session.jsonl"))
        try createFile(at: claudeRoot.appendingPathComponent("projects/alpha/notes.txt"))
        try createFile(at: codexRoot.appendingPathComponent("sessions/beta/session.jsonl"))
        try createFile(at: codexRoot.appendingPathComponent("sessions/beta/debug.log"))

        let scanner = LocalLogScanner(providerRoots: [
            ProviderLogRoot(provider: .claude, path: claudeRoot.path),
            ProviderLogRoot(provider: .codex, path: codexRoot.path)
        ])

        XCTAssertEqual(scanner.scan(), [
            CandidateSourceFile(
                provider: .claude,
                path: canonicalPath(claudeRoot.appendingPathComponent("projects/alpha/session.jsonl"))
            ),
            CandidateSourceFile(
                provider: .codex,
                path: canonicalPath(codexRoot.appendingPathComponent("sessions/beta/session.jsonl"))
            )
        ])
    }

    func testAvoidsDuplicateDiscoveredFilesDeterministically() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let claudeRoot = tempDirectory.appendingPathComponent(".claude")
        let sourceFile = claudeRoot.appendingPathComponent("projects/session.jsonl")
        try createFile(at: sourceFile)

        let scanner = LocalLogScanner(providerRoots: [
            ProviderLogRoot(provider: .claude, path: claudeRoot.path),
            ProviderLogRoot(provider: .claude, path: claudeRoot.path)
        ])

        XCTAssertEqual(scanner.scan(), [
            CandidateSourceFile(provider: .claude, path: canonicalPath(sourceFile))
        ])
    }

    func testDeterministicOrderingDoesNotDependOnInjectedRootOrder() throws {
        let tempDirectory = try makeTemporaryDirectory()
        let claudeRoot = tempDirectory.appendingPathComponent(".claude")
        let codexRoot = tempDirectory.appendingPathComponent(".codex")

        try createFile(at: codexRoot.appendingPathComponent("sessions/zeta.jsonl"))
        try createFile(at: claudeRoot.appendingPathComponent("projects/nested/beta.jsonl"))
        try createFile(at: claudeRoot.appendingPathComponent("projects/alpha.jsonl"))

        let scanner = LocalLogScanner(providerRoots: [
            ProviderLogRoot(provider: .codex, path: codexRoot.path),
            ProviderLogRoot(provider: .claude, path: claudeRoot.path)
        ])

        XCTAssertEqual(scanner.scan(), [
            CandidateSourceFile(provider: .claude, path: canonicalPath(claudeRoot.appendingPathComponent("projects/alpha.jsonl"))),
            CandidateSourceFile(provider: .claude, path: canonicalPath(claudeRoot.appendingPathComponent("projects/nested/beta.jsonl"))),
            CandidateSourceFile(provider: .codex, path: canonicalPath(codexRoot.appendingPathComponent("sessions/zeta.jsonl")))
        ])
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TokenScopeScannerTests")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryDirectories.append(directory)
        return directory
    }

    private func createFile(at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: url)
    }

    private func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
