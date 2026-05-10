import Foundation

public enum ProviderConfigEnvironment {
    public static func applyAPIKeyOverride(
        base: [String: String],
        provider: UsageProvider,
        config: ProviderConfig?) -> [String: String]
    {
        if provider == .bedrock {
            return self.applyBedrockOverrides(base: base, config: config)
        }

        guard let apiKey = config?.sanitizedAPIKey, !apiKey.isEmpty else { return base }
        var env = base
        if let key = self.directAPIKeyEnvironmentKey(for: provider) {
            env[key] = apiKey
            return env
        }

        switch provider {
        case .kimik2:
            if let key = KimiK2SettingsReader.apiKeyEnvironmentKeys.first {
                env[key] = apiKey
            }
        case .warp:
            if let key = WarpSettingsReader.apiKeyEnvironmentKeys.first {
                env[key] = apiKey
            }
        case .codebuff:
            // Preserve a token already present in the process environment so that
            // runtime/CI overrides win over a key saved in Settings (matches the
            // precedence used by `ProviderTokenResolver.codebuffResolution`).
            if CodebuffSettingsReader.apiKey(environment: base) == nil {
                env[CodebuffSettingsReader.apiTokenKey] = apiKey
            }
        case .crof:
            if CrofSettingsReader.apiKey(environment: base) == nil,
               let key = CrofSettingsReader.apiKeyEnvironmentKeys.first
            {
                env[key] = apiKey
            }
        case .doubao:
            if let key = DoubaoSettingsReader.apiKeyEnvironmentKeys.first {
                env[key] = apiKey
            }
        default:
            break
        }
        return env
    }

    private static func directAPIKeyEnvironmentKey(for provider: UsageProvider) -> String? {
        switch provider {
        case .zai:
            ZaiSettingsReader.apiTokenKey
        case .copilot:
            "COPILOT_API_TOKEN"
        case .minimax:
            MiniMaxAPISettingsReader.apiTokenKey
        case .alibaba:
            AlibabaCodingPlanSettingsReader.apiTokenKey
        case .kilo:
            KiloSettingsReader.apiTokenKey
        case .synthetic:
            SyntheticSettingsReader.apiKeyKey
        case .openrouter:
            OpenRouterSettingsReader.envKey
        case .venice:
            VeniceSettingsReader.apiKeyEnvironmentKey
        default:
            nil
        }
    }

    private static func applyBedrockOverrides(base: [String: String], config: ProviderConfig?) -> [String: String] {
        // Bedrock uses multiple independent credential fields, not just a single API key.
        // Apply each field from config when present, regardless of the others.
        var env = base
        if let accessKey = config?.sanitizedAPIKey, !accessKey.isEmpty {
            env[BedrockSettingsReader.accessKeyIDKey] = accessKey
        }
        if let secret = config?.sanitizedCookieHeader, !secret.isEmpty {
            env[BedrockSettingsReader.secretAccessKeyKey] = secret
        }
        if let region = config?.region, !region.isEmpty {
            env[BedrockSettingsReader.regionKeys[0]] = region
        }
        return env
    }
}
