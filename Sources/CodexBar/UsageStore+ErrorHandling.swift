import Foundation

extension UsageStore {
    static func isCancellationLikeError(_ error: any Error) -> Bool {
        self.isCancellationLikeError(error, depth: 0)
    }

    func userFacingProviderErrorMessage(_ error: any Error) -> String? {
        guard !Self.isCancellationLikeError(error) else { return nil }
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? nil : message
    }

    private static func isCancellationLikeError(_ error: any Error, depth: Int) -> Bool {
        guard depth < 4 else { return false }
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return true }

        if self.isCancellationLikeMessage(error.localizedDescription) { return true }

        for child in Mirror(reflecting: error).children {
            if let nestedError = child.value as? any Error,
               self.isCancellationLikeError(nestedError, depth: depth + 1)
            {
                return true
            }
            if let message = child.value as? String,
               self.isCancellationLikeMessage(message)
            {
                return true
            }
        }
        return false
    }

    private static func isCancellationLikeMessage(_ message: String) -> Bool {
        let normalized = message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else { return false }
        return normalized == "cancelled" ||
            normalized == "canceled" ||
            normalized.hasSuffix(": cancelled") ||
            normalized.hasSuffix(": canceled") ||
            normalized.contains("operation was cancelled") ||
            normalized.contains("operation was canceled") ||
            normalized.contains("nsurlerrordomain error -999")
    }
}
