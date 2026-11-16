import Foundation
import Testing
@testable import SwiftAIBaseten
import SwiftAIProvider
import SwiftAIProviderUtilities
import SwiftAITransport

// baseten-chat-language-model.test.ts (doGenerate / doStream)
@Suite("Baseten upstream parity")
struct BasetenUpstreamParityTests {
    private let schema: JSONValue = [
        "type": "object",
        "properties": ["answer": ["type": "string"]],
        "required": ["answer"],
        "additionalProperties": false
    ]

    private func call(
        modelID: String = "deepseek-ai/DeepSeek-V4-Pro-0813",
        modelURL: String? = nil,
        responseFormat: AIResponseFormat? = nil,
        stream: Bool
    ) async throws -> (body: JSONValue, warnings: [AIWarning]) {
        let response = stream
            ? sseResponse("data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"{\\\"answer\\\":\\\"PONG\\\"}\"},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n")
            : jsonResponse(#"{"choices":[{"message":{"content":"{\"answer\":\"PONG\"}"},"finish_reason":"stop"}]}"#)
        let transport = RecordingTransport(response: response)
        let provider = try BasetenProvider(configuration: .init(apiKey: "test-api-key", modelURL: modelURL, transport: transport))
        let model = try provider.languageModel(modelID)
        let request = LanguageModelRequest(
            messages: [.system("You are a helpful assistant."), .user("Reply with PONG.")],
            responseFormat: responseFormat ?? .json(schema: schema),
            reasoning: "high"
        )
        var warnings: [AIWarning] = []
        if stream {
            for try await part in model.stream(request) {
                if case let .streamStart(values) = part { warnings = values }
            }
        } else {
            warnings = try await model.generate(request).warnings
        }
        let sent = try #require(await transport.requests().first)
        return (try decodeJSONBody(try #require(sent.body)), warnings)
    }

    @Test(arguments: [false, true])
    func usesSchemaInPromptWithoutJSONModeWhenReasoningIsEnabled(_ stream: Bool) async throws {
        let (body, warnings) = try await call(stream: stream)
        #expect(body["response_format"] == nil)
        #expect(body["reasoning_effort"] == "high")
        let instruction = try #require(body["messages"]?[0]?["content"]?.stringValue)
        #expect(body["messages"]?[0]?["role"] == "system")
        #expect(instruction.contains("\"answer\""))
        #expect(body["messages"]?[1] == ["role": "system", "content": "You are a helpful assistant."])
        #expect(body["messages"]?[2] == ["role": "user", "content": "Reply with PONG."])
        #expect(warnings.contains { $0.type == "compatibility" && $0.feature == "responseFormat" && ($0.message ?? "").contains("injected into the system message") })
    }

    @Test(arguments: [false, true])
    func leavesTextRequestsUnchanged(_ stream: Bool) async throws {
        let (body, warnings) = try await call(responseFormat: .text, stream: stream)
        #expect(body["response_format"] == nil)
        #expect(body["messages"]?.arrayValue?.count == 2)
        #expect(warnings.isEmpty)
    }

    @Test(arguments: [false, true])
    func retainsJSONSchemaForOtherModels(_ stream: Bool) async throws {
        let (body, warnings) = try await call(modelID: "zai-org/GLM-4.7", stream: stream)
        #expect(body["response_format"]?["type"] == "json_schema")
        #expect(body["messages"]?.arrayValue?.count == 2)
        #expect(warnings.isEmpty)
    }

    @Test(arguments: [false, true])
    func leavesDedicatedDeploymentsUnchanged(_ stream: Bool) async throws {
        let (body, warnings) = try await call(modelURL: "https://model-123.api.baseten.co/sync/v1", stream: stream)
        #expect(body["response_format"]?["type"] == "json_schema")
        #expect(body["messages"]?.arrayValue?.count == 2)
        #expect(warnings.isEmpty)
    }

    // A plain /sync modelURL falls back to the Model APIs path upstream, which
    // carries the DeepSeek V4 Pro JSON transform.
    @Test func plainSyncModelURLUsesModelAPIsTransform() async throws {
        let (body, warnings) = try await call(modelURL: "https://model-123.api.baseten.co/environments/production/sync", stream: false)
        #expect(body["response_format"] == nil)
        #expect(body["messages"]?.arrayValue?.count == 3)
        #expect(warnings.contains { $0.type == "compatibility" && $0.feature == "responseFormat" })
    }

    // Upstream returns empty content (no error) for a choice without text.
    @Test func acceptsReasoningOnlyResponseWithoutText() async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"role":"assistant","content":null,"reasoning_content":"thinking"},"finish_reason":"length"}]}"#))
        let provider = try BasetenProvider(configuration: .init(apiKey: "test-api-key", transport: transport))
        let result = try await provider.languageModel("zai-org/GLM-4.7").generate(LanguageModelRequest(messages: [.user("Hi")]))
        #expect(result.text == "")
        #expect(result.reasoning == "thinking")
        #expect(result.finishReason == "length")
    }
}
