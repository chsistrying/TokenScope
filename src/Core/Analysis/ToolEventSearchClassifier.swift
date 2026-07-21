import Foundation

struct ToolEventSearchTarget: Equatable, Sendable {
    var commandName: String
    var rootPath: String
}

enum ToolEventSearchClassifier {
    static func searchTarget(for event: ToolEvent) -> ToolEventSearchTarget? {
        searchTarget(
            toolName: event.toolName,
            command: event.command,
            workingDirectory: event.workingDirectory
        )
    }

    static func searchTarget(
        toolName: String,
        command: String?,
        workingDirectory: String?
    ) -> ToolEventSearchTarget? {
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
        case "rg":
            return rootPath(fromRipgrepWords: words, workingDirectory: workingDirectory).map {
                ToolEventSearchTarget(commandName: "rg", rootPath: $0)
            }
        case "grep":
            guard isRecursiveGrep(words) else {
                return nil
            }

            return rootPath(fromGenericSearchWords: words, workingDirectory: workingDirectory).map {
                ToolEventSearchTarget(commandName: "grep", rootPath: $0)
            }
        case "find":
            guard !isShallowFind(words) else {
                return nil
            }

            return rootPath(fromFindWords: words, workingDirectory: workingDirectory).map {
                ToolEventSearchTarget(commandName: "find", rootPath: $0)
            }
        default:
            return nil
        }
    }

    private static func rootPath(fromRipgrepWords words: [Substring], workingDirectory: String?) -> String? {
        let positionalWords = words.dropFirst().filter { !$0.hasPrefix("-") }
        let rootCandidate = positionalWords
            .last { ToolEventShellParser.isPathLike(String($0)) }
            ?? (hasFlag("--files", in: words) ? positionalWords.last : nil)
            ?? (positionalWords.count >= 2 ? positionalWords.last : nil)
        let root = rootCandidate.map(String.init)

        return normalizedRoot(root, workingDirectory: workingDirectory)
    }

    private static func rootPath(fromGenericSearchWords words: [Substring], workingDirectory: String?) -> String? {
        let positionalWords = words.dropFirst().filter { !$0.hasPrefix("-") }
        let rootCandidate = positionalWords
            .last { ToolEventShellParser.isPathLike(String($0)) }
            ?? (positionalWords.count >= 2 ? positionalWords.last : nil)
        let root = rootCandidate.map(String.init)

        return normalizedRoot(root, workingDirectory: workingDirectory)
    }

    private static func rootPath(fromFindWords words: [Substring], workingDirectory: String?) -> String? {
        let rootCandidate = words
            .dropFirst()
            .first { word in
                !word.hasPrefix("-")
            }
            .map(String.init)

        return normalizedRoot(rootCandidate, workingDirectory: workingDirectory)
    }

    private static func normalizedRoot(_ rootCandidate: String?, workingDirectory: String?) -> String? {
        if let rootCandidate {
            return ToolEventPathNormalizer.normalizedPath(rootCandidate, workingDirectory: workingDirectory)
        }

        return workingDirectory.flatMap {
            ToolEventPathNormalizer.normalizedPath($0, workingDirectory: nil)
        }
    }

    private static func isRecursiveGrep(_ words: [Substring]) -> Bool {
        words.contains { word in
            word == "-r"
                || word == "-R"
                || word == "--recursive"
                || word.contains("r") && word.hasPrefix("-") && !word.hasPrefix("--")
        }
    }

    private static func hasFlag(_ flag: String, in words: [Substring]) -> Bool {
        words.contains { $0 == Substring(flag) }
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
