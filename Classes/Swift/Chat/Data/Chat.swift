//
//  Chat.swift
//  linphone
//
//  Created by Ankit Khanna on 04/03/25.
//

import Foundation

@objc class Chat: NSObject {
    @objc let chatId: String
    @objc let user1: String
    @objc let user2: String
    
    @objc init(chatId: String, user1: String, user2: String) {
        self.chatId = chatId
        self.user1 = user1
        self.user2 = user2
    }
    
    // Convert to dictionary for Firebase
    @objc func toDictionary() -> [String: Any] {
        return [
            "chatId": chatId,
            "user1": user1,
            "user2": user2
        ]
    }
}
