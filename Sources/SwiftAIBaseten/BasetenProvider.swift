import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIOpenAICompatible
import SwiftAIProviderUtilities

public struct BasetenProviderSettings: Sendable {
    public var apiKey: String?
    public var baseURL: String?
    public var headers: [String: String]
    public var queryParams: [String: String]
    public var includeUsage: Bool
    public var supportsStructuredOutputs: Bool
    public var supportsMultiPartToolContent: Bool
    public var maxEmbeddingsPerCall: Int?
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])?
    public var modelURL: String?
    public var transport: any AITransport

    public init(apiKey: String? = nil, baseURL: String? = nil, modelURL: String? = nil, headers: [String: String] = [:],
                queryParams: [String: String] = [:], transport: any AITransport = URLSessionTransport.shared,
                includeUsage: Bool = false, supportsStructuredOutputs: Bool = false, supportsMultiPartToolContent: Bool = false, maxEmbeddingsPerCall: Int? = nil, transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil, transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])? = nil) {
        self.apiKey = apiKey; self.baseURL = baseURL; self.headers = headers
        self.queryParams = queryParams; self.transport = transport
        self.includeUsage = includeUsage; self.supportsStructuredOutputs = supportsStructuredOutputs; self.supportsMultiPartToolContent = supportsMultiPartToolContent; self.maxEmbeddingsPerCall = maxEmbeddingsPerCall; self.transformRequestBody = transformRequestBody; self.transformRequestBodyWithWarnings = transformRequestBodyWithWarnings; self.modelURL = modelURL.map(withoutTrailingSlash)
    }
}

public final class BasetenProvider: AIProvider, Sendable {
    public let providerID = "baseten"
    public let supportedCapabilities: Set<ModelCapability> = [.language, .embedding]
    private let queryParams: [String: String]
    private let config: BasetenModelConfiguration

    public init(configuration: BasetenProviderSettings = .init()) throws {
        queryParams = configuration.queryParams
        let names = ["BASETEN_API_KEY"]
        guard let key = configuration.apiKey ?? environmentValue(names) else {
            throw AIError.missingAPIKey(provider: "baseten", environmentVariables: names)
        }
        var headers = configuration.headers
        headers["Authorization"] = headers["Authorization"] ?? "Bearer \(key)"
        headers = withUserAgentSuffix(headers, "ai-sdk-baseten/2.1.56")
        let baseURL = withoutTrailingSlash(configuration.baseURL ?? "https://inference.baseten.co/v1")
        let http = AIProviderHTTPClient(providerID: "baseten", headers: headers, transport: configuration.transport,
            url: { _, path in try providerURL("\(baseURL)\(path)", queryParams: configuration.queryParams) })
        config = BasetenModelConfiguration(http: http, baseURL: baseURL ,includeUsage: configuration.includeUsage, supportsStructuredOutputs: configuration.supportsStructuredOutputs, supportsMultiPartToolContent: configuration.supportsMultiPartToolContent, maxEmbeddingsPerCall: configuration.maxEmbeddingsPerCall, transformRequestBody: configuration.transformRequestBody, transformRequestBodyWithWarnings: configuration.transformRequestBodyWithWarnings, modelURL: configuration.modelURL)
    }

    public func languageModel(_ modelID: String) throws -> any LanguageModel {
        OpenAICompatibleChatModel(modelID: modelID, config: try compatibleConfiguration(surface: "chat"))
    }

    public func embeddingModel(_ modelID: String) throws -> any EmbeddingModel {
        guard let baseURL = basetenEmbeddingBaseURL(modelURL: config.modelURL) else {
            throw basetenEmbeddingConfigurationError(modelURL: config.modelURL)
        }
        var embeddingConfig = config.withProviderID("baseten.embedding")
        embeddingConfig.baseURL = baseURL
        let queryParams = self.queryParams
        embeddingConfig.http.url = { _, path in try providerURL("\(baseURL)\(path)", queryParams: queryParams) }
        return BasetenEmbeddingModel(modelID: modelID, config: embeddingConfig)
    }

    public func imageModel(_ modelID: String) throws -> any ImageModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .image, modelID: modelID)
    }

    public func transcriptionModel(_ modelID: String) throws -> any TranscriptionModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .transcription, modelID: modelID)
    }

    public func speechModel(_ modelID: String) throws -> any SpeechModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .speech, modelID: modelID)
    }

    public func videoModel(_ modelID: String) throws -> any VideoModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .video, modelID: modelID)
    }

    public func rerankingModel(_ modelID: String) throws -> any RerankingModel {
        throw AIError.unsupportedModel(provider: providerID, capability: .reranking, modelID: modelID)
    }

    private func compatibleConfiguration(surface: String) throws -> OpenAICompatibleModelConfiguration {
        var http = config.http
        http.providerID = "baseten.\(surface)"
        if let baseURL = try basetenChatBaseURL(modelURL: config.modelURL) {
            let queryParams = self.queryParams
            http.url = { _, path in try providerURL("\(baseURL)\(path)", queryParams: queryParams) }
        }
        var wire = OpenAICompatibleModelConfiguration(http: http, baseURL: config.baseURL)
        wire.usesGenericOpenAICompatibleProviderOptions = false
        wire.allowsEmptyTextResponse = false
        wire.includeUsage = config.includeUsage
        wire.supportsStructuredOutputs = config.supportsStructuredOutputs
        wire.supportsMultiPartToolContent = config.supportsMultiPartToolContent
        wire.maxEmbeddingsPerCall = config.maxEmbeddingsPerCall
        wire.transformRequestBody = config.transformRequestBody
        wire.transformRequestBodyWithWarnings = config.transformRequestBodyWithWarnings
        wire.supportsStructuredOutputs = true
        wire.includeUsage = true
        return wire
    }

    public func languageModel() throws -> any LanguageModel { try languageModel(basetenDefaultChatModelID(modelURL: config.modelURL)) }
    public func chatModel() throws -> any LanguageModel { try languageModel() }
    public func embeddingModel() throws -> any EmbeddingModel { try embeddingModel("embeddings") }
    public func textEmbeddingModel() throws -> any EmbeddingModel { try embeddingModel() }

    public func chatModel(_ modelID: String) throws -> any LanguageModel { try languageModel(modelID) }
}

public extension AIProviders {
    static func baseten(configuration: BasetenProviderSettings) throws -> BasetenProvider {
        try BasetenProvider(configuration: configuration)
    }
}

public struct BasetenModelConfiguration: AIProviderHTTPConfiguration {
    public var http: AIProviderHTTPClient
    public var baseURL: String
    public var includeUsage: Bool
    public var supportsStructuredOutputs: Bool
    public var supportsMultiPartToolContent: Bool
    public var maxEmbeddingsPerCall: Int?
    public var transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])?
    public var transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])?
    public var modelURL: String?
    public init(http: AIProviderHTTPClient, baseURL: String ,includeUsage: Bool = false, supportsStructuredOutputs: Bool = false, supportsMultiPartToolContent: Bool = false, maxEmbeddingsPerCall: Int? = nil, transformRequestBody: (@Sendable ([String: JSONValue]) -> [String: JSONValue])? = nil, transformRequestBodyWithWarnings: (@Sendable ([String: JSONValue], inout [AIWarning]) -> [String: JSONValue])? = nil, modelURL: String? = nil) {
        self.http = http; self.baseURL = withoutTrailingSlash(baseURL)
        self.includeUsage = includeUsage
        self.supportsStructuredOutputs = supportsStructuredOutputs
        self.supportsMultiPartToolContent = supportsMultiPartToolContent
        self.maxEmbeddingsPerCall = maxEmbeddingsPerCall
        self.transformRequestBody = transformRequestBody
        self.transformRequestBodyWithWarnings = transformRequestBodyWithWarnings
        self.modelURL = modelURL.map(withoutTrailingSlash)
    }
}

public extension BasetenModelConfiguration {
    func httpStatusError(_ response: AIHTTPResponse) -> AIError {
        openAICompatibleHTTPStatusError(provider: providerID, response: response)
    }
}
