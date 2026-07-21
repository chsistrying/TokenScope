import Foundation

enum ToolEventShellParser {
    static func words(_ command: String) -> [Substring] {
        var words: [Substring] = []
        var start: String.Index?
        var quote: Character?
        var index = command.startIndex

        while index < command.endIndex {
            let character = command[index]

            if let currentQuote = quote {
                if character == currentQuote {
                    quote = nil
                }
            } else if character == "'" || character == "\"" {
                quote = character
                start = start ?? index
            } else if character.isWhitespace {
                if let wordStart = start {
                    words.append(command[wordStart..<index].trimmingShellQuotes())
                    start = nil
                }
            } else {
                start = start ?? index
            }

            index = command.index(after: index)
        }

        if let wordStart = start {
            words.append(command[wordStart..<command.endIndex].trimmingShellQuotes())
        }

        return words
    }

    static func executableName(from words: [Substring]) -> String? {
        guard let executable = words.first?.split(separator: "/").last else {
            return nil
        }

        return String(executable).lowercased()
    }

    static func isPathLike(_ value: String) -> Bool {
        value == "."
            || value.hasPrefix("/")
            || value.hasPrefix("./")
            || value.hasPrefix("../")
            || value.contains("/")
    }
}

private extension Substring {
    func trimmingShellQuotes() -> Substring {
        var value = self

        while let first = value.first, first == "'" || first == "\"" {
            value.removeFirst()
        }

        while let last = value.last, last == "'" || last == "\"" {
            value.removeLast()
        }

        return value
    }
}
