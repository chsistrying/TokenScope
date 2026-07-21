import Foundation

enum ToolEventReadClassifier {
    static func readTarget(for event: ToolEvent) -> String? {
        readTarget(
            toolName: event.toolName,
            targetPath: event.targetPath,
            command: event.command,
            workingDirectory: event.workingDirectory
        )
    }

    static func readTarget(
        toolName: String,
        targetPath: String?,
        command: String?,
        workingDirectory: String? = nil
    ) -> String? {
        let normalizedToolName = toolName.lowercased()
        if normalizedToolName == "read", let targetPath, !targetPath.isEmpty {
            return ToolEventPathNormalizer.normalizedPath(targetPath, workingDirectory: workingDirectory)
        }

        if normalizedToolName == "bash" || normalizedToolName == "exec_command" || normalizedToolName == "shell" {
            return command
                .flatMap(pathFromShellReadCommand)
                .flatMap { ToolEventPathNormalizer.normalizedPath($0, workingDirectory: workingDirectory) }
        }

        return nil
    }

    private static func pathFromShellReadCommand(_ command: String) -> String? {
        let words = ToolEventShellParser.words(command)
        guard let executable = ToolEventShellParser.executableName(from: words) else {
            return nil
        }

        let readCommands: Set<String> = ["cat", "sed", "nl", "head", "tail", "wc"]
        guard readCommands.contains(executable) else {
            return nil
        }

        return words
            .dropFirst()
            .last { word in
                !word.hasPrefix("-") && ToolEventShellParser.isPathLike(String(word))
            }
            .map(String.init)
    }
}
