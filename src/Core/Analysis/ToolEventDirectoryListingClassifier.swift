import Foundation

struct ToolEventDirectoryListingTarget: Equatable, Sendable {
    var commandName: String
    var directoryPath: String
}

enum ToolEventDirectoryListingClassifier {
    static func listingTarget(for event: ToolEvent) -> ToolEventDirectoryListingTarget? {
        listingTarget(
            toolName: event.toolName,
            command: event.command,
            workingDirectory: event.workingDirectory
        )
    }

    static func listingTarget(
        toolName: String,
        command: String?,
        workingDirectory: String?
    ) -> ToolEventDirectoryListingTarget? {
        let normalizedToolName = toolName.lowercased()
        guard normalizedToolName == "bash"
            || normalizedToolName == "exec_command"
            || normalizedToolName == "shell" else {
            return nil
        }

        guard let command else {
            return nil
        }

        let words = ToolEventShellParser.words(command)
        guard let executable = ToolEventShellParser.executableName(from: words) else {
            return nil
        }

        switch executable {
        case "ls", "tree":
            return listingRoot(fromWords: words, workingDirectory: workingDirectory).map {
                ToolEventDirectoryListingTarget(commandName: executable, directoryPath: $0)
            }
        case "find":
            guard isShallowFind(words) else {
                return nil
            }

            return listingRoot(fromWords: words, workingDirectory: workingDirectory).map {
                ToolEventDirectoryListingTarget(commandName: "find", directoryPath: $0)
            }
        default:
            return nil
        }
    }

    private static func listingRoot(fromWords words: [Substring], workingDirectory: String?) -> String? {
        let candidate = words
            .dropFirst()
            .filter { !$0.hasPrefix("-") }
            .first
            .map(String.init)

        return normalizedRoot(candidate, workingDirectory: workingDirectory)
    }

    private static func normalizedRoot(_ rootCandidate: String?, workingDirectory: String?) -> String? {
        if let rootCandidate {
            return ToolEventPathNormalizer.normalizedPath(rootCandidate, workingDirectory: workingDirectory)
        }

        return workingDirectory.flatMap {
            ToolEventPathNormalizer.normalizedPath($0, workingDirectory: nil)
        }
    }

    private static func isShallowFind(_ words: [Substring]) -> Bool {
        for (index, word) in words.enumerated() where word == "-maxdepth" {
            let nextIndex = index + 1
            guard nextIndex < words.count else {
                return false
            }

            return words[nextIndex] == "1"
        }

        return false
    }
}
