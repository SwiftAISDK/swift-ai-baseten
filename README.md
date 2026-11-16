<!-- Generated distribution; edit the canonical repository. -->
# swift-ai-baseten 1.2.0

Independent Swift-native port of Vercel AI SDK. Source and upstream dispositions are in PROVENANCE.json and Porting/.

## Distribution manifest

Add this package to your SwiftPM dependencies:

```swift
.package(url: "https://github.com/SwiftAISDK/swift-ai-baseten.git", from: "1.2.0")
```

Products: `SwiftAIBaseten`.
Contribute and report issues in the canonical SwiftAISDK repository.

## Authored usage guide

# Baseten for Swift

`SwiftAIBaseten` adds Baseten to [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK), an independent Swift port of the Vercel AI SDK. It ports `@ai-sdk/baseten` and supports text generation and embeddings.

Provider guide with models, options, streaming and errors:

- [Baseten](https://swiftaisdk.github.io/SwiftAISDK/providers/baseten/)

## Usage

Add the `SwiftAI` product from `swift-ai-core` and the `SwiftAIBaseten` product from this package to your target, then create the provider:

```swift
import SwiftAI
import SwiftAIBaseten

let provider = try AIProviders.baseten(configuration: BasetenProviderSettings())
```

By default the provider reads `BASETEN_API_KEY` from the environment; values set in `BasetenProviderSettings` take precedence.

To use every provider through one dependency, add the complete [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) package instead; see [Install](https://swiftaisdk.github.io/SwiftAISDK/getting-started/install/).

## Contributing

This package is exported from `Packages/swift-ai-baseten` in the canonical [SwiftAISDK](https://github.com/SwiftAISDK/SwiftAISDK) repository. Open issues and pull requests there.
