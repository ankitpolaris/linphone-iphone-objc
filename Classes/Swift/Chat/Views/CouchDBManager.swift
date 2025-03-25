//
//  CouchDBManager.swift
//  linphone
//
//  Created by Ankit Khanna on 24/03/25.
//

import Foundation
import CouchbaseLiteSwift

@objcMembers
class CouchDBManager: NSObject {
    static let shared = CouchDBManager()

    var database: Database?

    private override init() {
        super.init()
        do {
            database = try Database(name: "chat_messages")
        } catch {
            print("Error initializing database: \(error)")
        }
    }
    @objc class func sharedInstance() -> CouchDBManager { // ✅ Expose to Objective-C
        return shared
    }

    func saveMessage(_ message: LocalChatMessage, chatId: String) {
        guard let db = database else { return }
        
        let document = MutableDocument()
            .setString(chatId, forKey: "chatId") // ✅ Store the chatId
            .setString(message.messageId, forKey: "messageId")
            .setString(message.senderId, forKey: "senderId")
            .setDouble(message.timestamp, forKey: "timestamp")
            .setString(message.text ?? "", forKey: "text")
            .setString(message.fileUrl ?? "", forKey: "fileUrl")
            .setString(message.type, forKey: "type")

        do {
            try db.saveDocument(document)
            print("✅ Message saved successfully in chatId: \(chatId)")
        } catch {
            print("❌ Error saving document: \(error)")
        }
    }


    func loadMessages(chatId: String) -> [LocalChatMessage] {
        guard let db = database else { return [] }

        var messages = [LocalChatMessage]()
        let query = QueryBuilder
            .select(SelectResult.all())
            .from(DataSource.database(db))
            .where(Expression.property("chatId").equalTo(Expression.string(chatId))) // ✅ Filter by chatId

        do {
            let result = try query.execute()
            for row in result {
                if let data = row.dictionary(forKey: "chat_messages") {
                    let message = LocalChatMessage(
                        messageId: data.string(forKey: "messageId") ?? "",
                        senderId: data.string(forKey: "senderId") ?? "",
                        timestamp: data.double(forKey: "timestamp"),
                        text: data.string(forKey: "text"),
                        fileUrl: data.string(forKey: "imageUrl") ?? data.string(forKey: "fileUrl"),
                        type: data.string(forKey: "type") ?? "text"
                    )
                    messages.append(message)
                }
            }
        } catch {
            print("Error fetching messages: \(error)")
        }
        return messages
    }

    func clearDatabase() {
        guard let database = database else { return }
        do {
            let dbName = database.name
            let config = database.config

            // Close and delete the database
            try database.delete()
            print("Database deleted successfully.")

            // Recreate a new empty database
            self.database = try Database(name: dbName, config: config)
            print("New database created successfully.")
        } catch {
            print("Error clearing database: \(error.localizedDescription)")
        }
    }
    
    @objc func deleteChat(chatId: String) {
        guard let db = database else { return }

        let query = QueryBuilder
            .select(SelectResult.expression(Meta.id))
            .from(DataSource.database(db))
            .where(Expression.property("chatId").equalTo(Expression.string(chatId)))

        do {
            let result = try query.execute()

            try db.inBatch {
                for row in result {
                    if let docId = row.string(forKey: "id") {
                        let mutableDoc = MutableDocument(id: docId)
                        try db.deleteDocument(mutableDoc) // 🔥 Delete directly without fetching first
                    }
                }
            }

            print("✅ Successfully deleted chat with chatId: \(chatId)")
        } catch {
            print("❌ Error deleting chat: \(error.localizedDescription)")
        }
    }

    
}

