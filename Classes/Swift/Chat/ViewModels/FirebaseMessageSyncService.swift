//
//  FirebaseMessageSyncService.swift
//  linphone
//
//  Created by Ankit Khanna on 25/03/25.
//

import FirebaseDatabase
import Foundation
import CouchbaseLiteSwift

class FirebaseMessageSyncService {
    static let shared = FirebaseMessageSyncService()
    private var isSyncing = false
    private var fetchedMessageIds: Set<String> = []
    
    private init() {}

    func startListeningForMessages(chatId: String) {
        guard !isSyncing else { return }
        isSyncing = true

        let chatRef = Database.database().reference()
            .child("WORKSPACE_VOXTRIO")
            .child("chats")
            .child(chatId)
            .child("messages")

        chatRef.observe(.childAdded) { snapshot, _ in
            guard let data = snapshot.value as? [String: Any],
                  let newMessage = FirebaseChatMessage(firebaseData: data) else { return }
            
            // ✅ Step 1: Check if message already exists (Avoid duplicates)
            let messageId = newMessage.messageId
            if self.fetchedMessageIds.contains(messageId) {
                return  // 🚀 Ignore duplicate messages
            }
            self.fetchedMessageIds.insert(messageId)  // ✅ Mark message as fetched

            DispatchQueue.global(qos: .background).async {
                let localMessage = LocalChatMessage(
                    messageId: newMessage.messageId,
                    senderId: newMessage.sender.senderId,
                    timestamp: newMessage.sentDate.timeIntervalSince1970,
                    text: newMessage.extractText(),
                    fileUrl: newMessage.imageUrl ?? newMessage.videoUrl ?? newMessage.fileUrl,
                    type: newMessage.kindToString()
                )

                if !self.isMessageAlreadySaved(messageId: messageId, chatId: chatId) {
                    
                    self.saveLocalMessagesToDB(localMessage, chatId: chatId)
                    
                    // ✅ Send a notification to update UI
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .newMessageReceived, object: nil)
                    }
                }

              
            }
        }
    }

    /// ✅ Checks if the message is already saved in CouchDB
    private func isMessageAlreadySaved(messageId: String, chatId: String) -> Bool {
        // ✅ Fetch messages from CouchDB for the given chatId
        let existingMessages = fetchMessagesFromCouchDB(chatId: chatId)
        
        // ✅ Check if the messageId already exists
        return existingMessages.contains { $0.messageId == messageId }
    }
    
    func fetchMessagesFromCouchDB(chatId: String) -> [LocalChatMessage] {
        return CouchDBManager.shared.loadMessages(chatId: chatId)
    }
    private func saveLocalMessagesToDB(_ message: LocalChatMessage, chatId: String) {
        CouchDBManager.shared.saveMessage(message, chatId: chatId)
    }
}

// ✅ Define notification name
extension Notification.Name {
    static let newMessageReceived = Notification.Name("newMessageReceived")
}
