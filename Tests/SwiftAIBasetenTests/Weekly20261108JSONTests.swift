import Foundation
import Testing
@testable import SwiftAIBaseten
import SwiftAIProvider

@Suite("Weekly20261108 Baseten reasoning JSON fallback")
struct Weekly20261108JSONTests {
    @Test(arguments: [false, true])
    func fallbackAndDisabledReasoningMatchInGenerateAndStream(_ stream: Bool) async throws {
        for (reasoning, options, schema, expectedFallback) in [
            (Optional<String>.none, [String: JSONValue](), Optional<JSONValue>.none, true),
            ("none", [:], JSONValue.object(["type": "object"]), false),
            ("high", ["reasoningEffort": "none"], JSONValue.object(["type": "object"]), false),
            (Optional<String>.none, ["reasoning_effort": "none"], JSONValue.object(["type": "object"]), false)
        ] {
            let response = stream ? sseResponse("data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"{}\"},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n") : jsonResponse(#"{"choices":[{"message":{"content":"{}"},"finish_reason":"stop"}]}"#)
            let transport = RecordingTransport(response: response)
            let provider = try BasetenProvider(configuration: .init(apiKey: "key", transport: transport))
            let model = try provider.languageModel("deepseek-ai/DeepSeek-V4-Pro-0813")
            let request = LanguageModelRequest(messages: [.system("Original"), .user("JSON")], responseFormat: .json(schema: schema), reasoning: reasoning, providerOptions: ["baseten": .object(options)])
            var warnings: [AIWarning] = []
            if stream {
                for try await part in model.stream(request) {
                    if case let .streamStart(values) = part { warnings = values }
                }
            } else { warnings = try await model.generate(request).warnings }
            let sent = try #require(await transport.requests().first)
            let body = try JSONDecoder().decode(JSONValue.self, from: #require(sent.body))
            #expect((body["response_format"] == nil) == expectedFallback)
            if expectedFallback {
                #expect(body["messages"]?[0] == ["role": "system", "content": "You MUST answer with JSON."])
                #expect(body["messages"]?[1] == ["role": "system", "content": "Original"])
            } else {
                #expect(body["reasoning_effort"] == "none")
                #expect(body["messages"]?.arrayValue?.count == 2)
            }
            #expect(warnings.contains { $0.type == "compatibility" && $0.feature == "responseFormat" } == expectedFallback)
        }
    }

    @Test(arguments: [false, true])
    func serverlessUsesPromptAndDedicatedKeepsSchema(_ dedicated: Bool) async throws {
        let transport = RecordingTransport(response: jsonResponse(#"{"choices":[{"message":{"content":"{}"},"finish_reason":"stop"}]}"#))
        let provider = try BasetenProvider(configuration: .init(apiKey: "key", modelURL: dedicated ? "https://model.example.com/sync/v1" : nil, transport: transport))
        let model = try provider.languageModel("deepseek-ai/DeepSeek-V4-Pro-0813")
        let result = try await model.generate(.init(messages: [.system("Original"), .user("JSON")], responseFormat: .json(schema: ["type": "object"]), reasoning: "high"))
        let request = try #require(await transport.requests().first)
        let body = try JSONDecoder().decode(JSONValue.self, from: #require(request.body))
        #expect((body["response_format"] != nil) == dedicated)
        #expect(body["messages"]?.arrayValue?.count == (dedicated ? 2 : 3))
        #expect(result.warnings.contains { $0.type == "compatibility" && $0.feature == "responseFormat" } == !dedicated)
    }
}
