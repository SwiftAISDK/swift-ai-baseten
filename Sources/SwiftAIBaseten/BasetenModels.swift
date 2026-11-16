import SwiftAIOpenAICompatible
import Foundation
import SwiftAIProvider
import SwiftAITransport
import SwiftAIProviderUtilities


public final class BasetenEmbeddingModel: EmbeddingModel, @unchecked Sendable {
    public let providerID = "baseten.embedding"
    public let modelID: String
    public var maxEmbeddingsPerCall: Int? { basetenHTTPBatchSize }
    private let config: BasetenModelConfiguration

    public init(modelID: String, config: BasetenModelConfiguration) {
        self.modelID = modelID
        self.config = config
    }

    public func embed(_ request: EmbeddingRequest) async throws -> EmbeddingResult {
        guard !request.values.isEmpty else {
            throw AIError.invalidArgument(argument: "values", message: "Input list cannot be empty")
        }

        // Upstream OpenAICompatibleEmbeddingModel rejects batches above
        // maxEmbeddingsPerCall; embedMany splits larger inputs before calling.
        guard request.values.count <= basetenHTTPBatchSize else {
            throw AITooManyEmbeddingValuesForCallError(
                provider: providerID,
                modelID: modelID,
                maxEmbeddingsPerCall: basetenHTTPBatchSize,
                values: request.values
            )
        }

        let body = basetenHTTPEmbeddingBody(values: request.values, modelID: modelID, request: request)
        let response = try await config.sendJSONResponse(
            path: "/embeddings",
            modelID: modelID,
            body: body,
            headers: request.headers,
            abortSignal: request.abortSignal
        )
        let raw = response.json
        guard let data = raw["data"]?.arrayValue else {
            throw AIError.invalidResponse(provider: providerID, message: "No embedding data found.")
        }
        let embeddings = data.compactMap { item -> [Double]? in
            item["embedding"]?.arrayValue?.compactMap(\.doubleValue)
        }
        return EmbeddingResult(
            embeddings: embeddings,
            usage: tokenUsage(from: raw),
            rawValue: raw,
            warnings: openAICompatibleProviderOptionWarnings(
                providerOptions: request.providerOptions,
                extraBody: request.extraBody,
                providerID: providerID,
                includeCompatibilityNamespace: true
            ),
            providerMetadata: raw["providerMetadata"]?.objectValue ?? [:],
            requestMetadata: AIRequestMetadata(body: body, headers: request.headers),
            responseMetadata: aiResponseMetadata(from: raw, response: response.response, modelID: modelID)
        )
    }
}

private let basetenHTTPBatchSize = 128

private func basetenHTTPEmbeddingBody(
    values: [String],
    modelID: String,
    request: EmbeddingRequest
) -> JSONValue {
    var body: [String: JSONValue] = [
        "input": .array(values.map(JSONValue.string)),
        "model": .string(modelID),
        "encoding_format": .string("float")
    ]
    if let dimensions = request.dimensions {
        body["dimensions"] = .number(Double(dimensions))
    }
    body.merge(openAICompatibleProviderOptions(
        providerOptions: request.providerOptions,
        extraBody: request.extraBody,
        providerID: "baseten.embedding",
        includeCompatibilityNamespace: true
    )) { _, providerValue in providerValue }
    return .object(body)
}
