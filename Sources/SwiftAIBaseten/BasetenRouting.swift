import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


public func basetenEmbeddingConfigurationError(modelURL: String?) -> AIError {
    guard let modelURL else {
        return AIError.invalidArgument(argument: "modelURL", message: "No model URL provided for embeddings. Please set modelURL option for embeddings.")
    }
    if modelURL.contains("/predict") || !modelURL.contains("/sync") {
        return AIError.invalidArgument(argument: "modelURL", message: "Not supported. You must use a /sync or /sync/v1 endpoint for embeddings.")
    }
    return AIError.invalidArgument(argument: "modelURL", message: "No model URL provided for embeddings. Please set modelURL option for embeddings.")
}
public func basetenDefaultChatModelID(modelURL: String?) -> String {
    modelURL?.contains("/sync/v1") == true ? "placeholder" : "chat"
}

public func basetenChatBaseURL(modelURL: String?) throws -> String? {
    if let modelURL {
        if modelURL.contains("/predict") {
            throw AIError.invalidArgument(argument: "modelURL", message: "Not supported. You must use a /sync/v1 endpoint for chat models.")
        }
        if modelURL.contains("/sync/v1") { return withoutTrailingSlash(modelURL) }
    }
    return nil
}

public func basetenEmbeddingBaseURL(modelURL: String?) -> String? {
    guard let modelURL, modelURL.contains("/sync"), !modelURL.contains("/predict") else { return nil }
    return modelURL.contains("/sync/v1") ? modelURL : "\(modelURL)/v1"
}
