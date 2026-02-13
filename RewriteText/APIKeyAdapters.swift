import Foundation

struct EnvOrKeychainAPIKeyProvider: APIKeyProviding {
    let service: String
    let account: String

    func loadAPIKey() throws -> String? {
        let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        if !env.isEmpty {
            return env
        }
        return try KeychainStore.loadString(service: service, account: account)
    }
}

struct KeychainAPIKeyStore: APIKeyStoring {
    let service: String
    let account: String

    func saveAPIKey(_ key: String) throws {
        try KeychainStore.saveString(key, service: service, account: account)
    }

    func clearAPIKey() throws {
        try KeychainStore.delete(service: service, account: account)
    }

    func hasAPIKey() -> Bool {
        ((try? KeychainStore.loadString(service: service, account: account)) ?? "").isEmpty == false
    }
}

