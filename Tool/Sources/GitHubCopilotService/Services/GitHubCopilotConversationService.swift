import CopilotForXcodeKit
import Foundation
import ConversationServiceProvider
import BuiltinExtension

public final class GitHubCopilotConversationService: ConversationServiceType {
    
    private let serviceLocator: ServiceLocator
    
    init(serviceLocator: ServiceLocator) {
        self.serviceLocator = serviceLocator
    }
    
    public func createConversation(_ request: ConversationRequest, workspace: WorkspaceInfo) async throws {
        guard let service = await serviceLocator.getService(from: workspace) else { return }
        
        return try await service.createConversation(request.content,
                                                    workDoneToken: request.workDoneToken,
                                                    workspaceFolder: request.workspaceFolder,
                                                    doc: nil,
                                                    skills: request.skills)
    }
    
    public func createTurn(with conversationId: String, request: ConversationRequest, workspace: WorkspaceInfo) async throws {
        guard let service = await serviceLocator.getService(from: workspace) else { return }
        
        return try await service.createTurn(request.content, workDoneToken: request.workDoneToken, conversationId: conversationId, doc: nil)
    }
    
    public func cancelProgress(_ workDoneToken: String, workspace: WorkspaceInfo) async throws {
        guard let service = await serviceLocator.getService(from: workspace) else { return }
        
        await service.cancelProgress(token: workDoneToken)
    }
    
    public func rateConversation(turnId: String, rating: ConversationRating, workspace: WorkspaceInfo) async throws {
        guard let service = await serviceLocator.getService(from: workspace) else { return }
        try await service.rateConversation(turnId: turnId, rating: rating)
    }
    
    public func copyCode(request: CopyCodeRequest, workspace: WorkspaceInfo) async throws {
        guard let service = await serviceLocator.getService(from: workspace) else { return }
        try await service.copyCode(turnId: request.turnId, codeBlockIndex: request.codeBlockIndex, copyType: request.copyType, copiedCharacters: request.copiedCharacters, totalCharacters: request.totalCharacters, copiedText: request.copiedText)
    }
}
