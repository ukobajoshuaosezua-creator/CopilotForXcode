import Foundation
import JSONRPC
import LanguageServerProtocol
import SuggestionBasic

struct GitHubCopilotDoc: Codable {
    var source: String
    var tabSize: Int
    var indentSize: Int
    var insertSpaces: Bool
    var path: String
    var uri: String
    var relativePath: String
    var languageId: CodeLanguage
    var position: Position
    /// Buffer version. Not sure what this is for, not sure how to get it
    var version: Int = 0
}

protocol GitHubCopilotRequestType {
    associatedtype Response: Codable
    var request: ClientRequest { get }
}

public struct GitHubCopilotCodeSuggestion: Codable, Equatable {
    public init(
        text: String,
        position: CursorPosition,
        uuid: String,
        range: CursorRange,
        displayText: String
    ) {
        self.text = text
        self.position = position
        self.uuid = uuid
        self.range = range
        self.displayText = displayText
    }

    /// The new code to be inserted and the original code on the first line.
    public var text: String
    /// The position of the cursor before generating the completion.
    public var position: CursorPosition
    /// An id.
    public var uuid: String
    /// The range of the original code that should be replaced.
    public var range: CursorRange
    /// The new code to be inserted.
    public var displayText: String
}

public func editorConfiguration() -> JSONValue {
    var proxyAuthorization: String? {
        let username = UserDefaults.shared.value(for: \.gitHubCopilotProxyUsername)
        if username.isEmpty { return nil }
        let password = UserDefaults.shared.value(for: \.gitHubCopilotProxyPassword)
        return "\(username):\(password)"
    }

    var http: JSONValue? {
        var d: [String: JSONValue] = [:]
        let proxy = UserDefaults.shared.value(for: \.gitHubCopilotProxyUrl)
        if !proxy.isEmpty {
            d["proxy"] = .string(proxy)
        }
        if let proxyAuthorization = proxyAuthorization {
            d["proxyAuthorization"] = .string(proxyAuthorization)
        }
        d["proxyStrictSSL"] = .bool(UserDefaults.shared.value(for: \.gitHubCopilotUseStrictSSL))
        if d.isEmpty { return nil }
        return .hash(d)
    }

    var authProvider: JSONValue? {
        let enterpriseURI = UserDefaults.shared.value(for: \.gitHubCopilotEnterpriseURI)
        if enterpriseURI.isEmpty { return nil }
        return .hash([ "uri": .string(enterpriseURI) ])
    }

    var d: [String: JSONValue] = [:]
    if let http { d["http"] = http }
    if let authProvider { d["github-enterprise"] = authProvider }
    return .hash(d)
}

enum GitHubCopilotRequest {
    struct GetVersion: GitHubCopilotRequestType {
        struct Response: Codable {
            var version: String
        }

        var request: ClientRequest {
            .custom("getVersion", .hash([:]))
        }
    }

    struct CheckStatus: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: GitHubCopilotAccountStatus
        }

        var request: ClientRequest {
            .custom("checkStatus", .hash([:]))
        }
    }

    struct SignInInitiate: GitHubCopilotRequestType {
        struct Response: Codable {
            var verificationUri: String
            var status: String
            var userCode: String
            var expiresIn: Int
            var interval: Int
        }

        var request: ClientRequest {
            .custom("signInInitiate", .hash([:]))
        }
    }

    struct SignInConfirm: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: GitHubCopilotAccountStatus
            var user: String
        }

        var userCode: String

        var request: ClientRequest {
            .custom("signInConfirm", .hash([
                "userCode": .string(userCode),
            ]))
        }
    }

    struct SignOut: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: GitHubCopilotAccountStatus
        }

        var request: ClientRequest {
            .custom("signOut", .hash([:]))
        }
    }

    struct GetCompletions: GitHubCopilotRequestType {
        struct Response: Codable {
            var completions: [GitHubCopilotCodeSuggestion]
        }

        var doc: GitHubCopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getCompletions", .hash([
                "doc": dict,
            ]))
        }
    }

    struct GetCompletionsCycling: GitHubCopilotRequestType {
        struct Response: Codable {
            var completions: [GitHubCopilotCodeSuggestion]
        }

        var doc: GitHubCopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getCompletionsCycling", .hash([
                "doc": dict,
            ]))
        }
    }

    struct InlineCompletion: GitHubCopilotRequestType {
        struct Response: Codable {
            var items: [InlineCompletionItem]
        }

        struct InlineCompletionItem: Codable {
            var insertText: String
            var filterText: String?
            var range: Range?
            var command: Command?

            struct Range: Codable {
                var start: Position
                var end: Position
            }

            struct Command: Codable {
                var title: String
                var command: String
                var arguments: [String]?
            }
        }

        var doc: Input

        struct Input: Codable {
            var textDocument: _TextDocument; struct _TextDocument: Codable {
                var uri: String
                var version: Int
            }

            var position: Position
            var formattingOptions: FormattingOptions
            var context: _Context; struct _Context: Codable {
                enum TriggerKind: Int, Codable {
                    case invoked = 1
                    case automatic = 2
                }

                var triggerKind: TriggerKind
            }
        }

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("textDocument/inlineCompletion", dict)
        }
    }

    struct GetPanelCompletions: GitHubCopilotRequestType {
        struct Response: Codable {
            var completions: [GitHubCopilotCodeSuggestion]
        }

        var doc: GitHubCopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getPanelCompletions", .hash([
                "doc": dict,
            ]))
        }
    }

    struct NotifyShown: GitHubCopilotRequestType {
        struct Response: Codable {}

        var completionUUID: String

        var request: ClientRequest {
            .custom("notifyShown", .hash([
                "uuid": .string(completionUUID),
            ]))
        }
    }

    struct NotifyAccepted: GitHubCopilotRequestType {
        struct Response: Codable {}

        var completionUUID: String

        var acceptedLength: Int?

        var request: ClientRequest {
            var dict: [String: JSONValue] = [
                "uuid": .string(completionUUID),
            ]
            if let acceptedLength {
                dict["acceptedLength"] = .number(Double(acceptedLength))
            }

            return .custom("notifyAccepted", .hash(dict))
        }
    }

    struct NotifyRejected: GitHubCopilotRequestType {
        struct Response: Codable {}

        var completionUUIDs: [String]

        var request: ClientRequest {
            .custom("notifyRejected", .hash([
                "uuids": .array(completionUUIDs.map(JSONValue.string)),
            ]))
        }
    }

    // MARK: Conversation

    struct CreateConversation: GitHubCopilotRequestType {
        struct Response: Codable {}

        var params: ConversationCreateParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/create", dict)
        }
    }

    // MARK: Conversation turn

    struct CreateTurn: GitHubCopilotRequestType {
        struct Response: Codable {}

        var params: TurnCreateParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/turn", dict)
        }
    }

    // MARK: Conversation rating

    struct ConversationRating: GitHubCopilotRequestType {
        struct Response: Codable {}

        var params: ConversationRatingParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/rating", dict)
        }
    }

    // MARK: Copy code

    struct CopyCode: GitHubCopilotRequestType {
        struct Response: Codable {}

        var params: CopyCodeParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/copyCode", dict)
        }
    }
}
