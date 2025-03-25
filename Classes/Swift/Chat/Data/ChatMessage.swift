//
//  ChatMessage.swift
//  linphone
//
//  Created by Ankit Khanna on 04/03/25.
//

import Foundation

@objc class ChatMessageFirebase: NSObject {
    @objc let chatId: String
    @objc let messageId: String
    @objc let senderId: String
    @objc let senderName: String
    @objc let text: String
    @objc let timestamp: Date
    
    @objc init(chatId: String, messageId: String, senderId: String, senderName: String, text: String, timestamp: Date) {
        self.chatId = chatId
        self.messageId = messageId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
    }
    
    // Convert to dictionary for Firebase
    @objc func toDictionary() -> [String: Any] {
        return [
            "chatId": chatId,
            "messageId": messageId,
            "senderId": senderId,
            "senderName": senderName,
            "text": text,
            "timestamp": timestamp.timeIntervalSince1970 * 1000 // Convert to milliseconds
        ]
    }
    
    // Initialize from dictionary (for reading from Firebase)
    @objc convenience init?(dictionary: [String: Any]) {
        guard let chatId = dictionary["chatId"] as? String,
              let messageId = dictionary["messageId"] as? String,
              let senderId = dictionary["senderId"] as? String,
              let senderName = dictionary["senderName"] as? String,
              let text = dictionary["text"] as? String,
              let timestamp = dictionary["timestamp"] as? TimeInterval else { return nil }
        
        self.init(
            chatId: chatId,
            messageId: messageId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            timestamp: Date(timeIntervalSince1970: timestamp / 1000) // Convert from milliseconds
        )
    }
}
