import Foundation

struct ToolEventFailureTarget: Equatable, Sendable {
    var commandName: String
    var commandKey: String
    var errorSummary: String
}

enum ToolEventFailureClassifier {
    static func failureTarget(for event: ToolEvent) -> ToolEventFailureTarget? {
        guard let command = event.command, !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        guard isFailure(event) else {
            return nil
        }

        let words = ToolEventShellParser.words(command)
        let commandName = ToolEventShellParser.executableName(from: words) ?? event.toolName
        let commandKey = normalizedCommand(command)
        let errorSummary = normalizedErrorSummary(event.errorSummary) ?? "Command failed"

        return ToolEventFailureTarget(
            commandName: commandName,
            commandKey: commandKey,
            errorSummary: errorSummary
        )
    }

    private static func isFailure(_ event: ToolEvent) -> Bool {
        if let exitCode = event.exitCode, exitCode != 0 {
            return true
        }

        return event.errorSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private static func normalizedCommand(_ command: String) -> String {
        command
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func normalizedErrorSummary(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return String(trimmed.prefix(80))
    }
}
