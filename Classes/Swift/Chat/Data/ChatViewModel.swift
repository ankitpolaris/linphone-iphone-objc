//
//  ChatViewModel.swift
//  linphone
//
//  Created by Ankit Khanna on 04/03/25.
//

import Foundation
import FirebaseDatabase

@objc class ChatViewModel: NSObject {
    // MARK: - Properties
    private var databaseRef: DatabaseReference!
    private var messages: [ChatMessageFirebase] = []
    
    @objc var onMessagesUpdated: (() -> Void)? // Callback to notify UI of updates
    
    @objc override init() {
        super.init()
        databaseRef = Database.database().reference()
    }
    
    // MARK: - Send Message
    @objc(sendMessageWithText:senderId:senderName:chatId:user1:user2:)
    func sendMessage(text: String, senderId: String, senderName: String, chatId: String, user1: String, user2: String) {
        let messagesRef = databaseRef.child("WORKSPACE_VOXTRIO").child("chats").child(chatId).child("messages")
        
        guard let messageId = messagesRef.childByAutoId().key else {
            print("🔥 Error: Unable to generate message ID")
            return
        }
        
        let message: [String: Any] = [
            "messageId": messageId,
            "senderId": senderId,
            "senderName": senderName,
            "text": text,
            "timestamp": Date().timeIntervalSince1970 * 1000 // Milliseconds
        ]
        
        // Write the message to Firebase
        messagesRef.child(messageId).setValue(message) { error, _ in
            if let error = error {
                print("❌ Error writing message: \(error.localizedDescription)")
            } else {
                print("✅ Message successfully written!")
            }
        }
        
        // Update chat metadata WITHOUT overwriting messages
        let chatMetadata: [String: Any] = [
            "chatId": chatId,
            "user1": user1,
            "user2": user2
        ]
        
        databaseRef.child("WORKSPACE_VOXTRIO").child("chats").child(chatId).updateChildValues(chatMetadata) { error, _ in
            if let error = error {
                print("❌ Error updating chat metadata: \(error.localizedDescription)")
            } else {
                print("✅ Chat metadata updated!")
            }
        }
    }
    
    // MARK: - Observe Messages
    @objc func observeMessages(for chatId: String) {
        databaseRef.child("WORKSPACE_VOXTRIO").child("chats").child(chatId).child("messages").observe(.childAdded) { [weak self] snapshot in
            guard let self = self,
                  let messageDict = snapshot.value as? [String: Any],
                  let message = ChatMessageFirebase(dictionary: messageDict) else { return }
            
            self.messages.append(message)
            self.onMessagesUpdated?() // Notify UI to update
        }
    }
    
    // MARK: - Get Messages
    @objc func getMessages() -> [ChatMessageFirebase] {
        return messages
    }
    
    // MARK: - Generate Chat ID
    @objc(generateChatIdForUser1:user2:)
    func generateChatId(for user1: String, and user2: String) -> String {
        let users = [user1, user2].sorted()
        return users.joined(separator: "_")
    }
    
    
    // MARK: - Fetch Conversations
//    @objc func fetchConversations(completion: @escaping ([[String: Any]]) -> Void) {
//        
//        databaseRef.child("chats").observe(.value) { snapshot in
//            guard let chatsDict = snapshot.value as? [String: [String: Any]] else {
//                completion([])
//                return
//            }
//            
//            let conversations = Array(chatsDict.values)
//            completion(conversations)
//        }
//    }
    
    func extractUserId(from sipAddress: String) -> String? {
        let components = sipAddress.components(separatedBy: "@")
        guard let userPart = components.first else { return nil } // Extract "sip:202-1234"

        // ✅ Remove "sip:" prefix if present
        let cleanedUserPart = userPart.replacingOccurrences(of: "sip:", with: "")

        // ✅ Extract first part before "-"
        let userParts = cleanedUserPart.components(separatedBy: "-")
        if let userId = userParts.first {
            return userId.prefix(3).description // ✅ Return first 3 characters
        }

        return nil // ✅ Return nil if extraction fails
    }
    
    func getCurrentUserId() -> String? {
        guard let defaultAccount = linphone_core_get_default_account(LinphoneManager.getLc()) else { return nil }
        guard let accountParams = linphone_account_get_params(defaultAccount) else { return nil }
        guard let addr = linphone_account_params_get_identity_address(accountParams) else { return nil }
        guard let cString = linphone_address_as_string(addr) else { return nil }
        let currentSipId = String(cString: cString)
        
        return extractUserId(from: currentSipId)
    }
    
    @objc func fetchConversations(completion: @escaping ([[String: Any]]) -> Void) {
        guard let currentUserId = getCurrentUserId() else {
            print("❌ Error: Current User ID not found")
            completion([])
            return
        }

        databaseRef.child("WORKSPACE_VOXTRIO").child("chats").observe(.value) { (snapshot: DataSnapshot) in
            guard let chatsDict = snapshot.value as? [String: [String: Any]] else {
                completion([])
                return
            }

            // ✅ Filter conversations where currentUserId is either user1 or user2
            let filteredConversations = chatsDict.values.filter { chat in
                if let chatMetadata = chat["chatMetadata"] as? [String: Any],
                   let user1 = chatMetadata["user1"] as? String,
                   let user2 = chatMetadata["user2"] as? String {
                    return user1 == currentUserId || user2 == currentUserId
                }
                return false
            }

            // ✅ Sort by `lastUpdated` timestamp in descending order (latest first)
            let sortedConversations = filteredConversations.sorted { chat1, chat2 in
                let timestamp1 = (chat1["chatMetadata"] as? [String: Any])?["lastUpdated"] as? TimeInterval ?? 0
                let timestamp2 = (chat2["chatMetadata"] as? [String: Any])?["lastUpdated"] as? TimeInterval ?? 0
                return timestamp1 > timestamp2 // ✅ Most recent first
            }

            completion(sortedConversations)
        }
    }


    
    @objc func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000) // Convert to seconds
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // 24-hour format
        return formatter.string(from: date)
    }
    
    @objc func fetchLastMessage(for chatId: String, completion: @escaping ([String: Any]?) -> Void) {
        databaseRef.child("WORKSPACE_VOXTRIO").child("chats").child(chatId).child("messages").queryLimited(toLast: 1).observeSingleEvent(of: .value) { snapshot in
            guard let messagesDict = snapshot.value as? [String: [String: Any]] else {
                completion(nil)
                return
            }
            
            // Get the last message
            let lastMessage = messagesDict.values.first
            completion(lastMessage)
        }
    }
    
}
