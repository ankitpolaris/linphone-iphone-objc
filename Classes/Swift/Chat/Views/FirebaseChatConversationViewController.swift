//
//  FirebaseChatConversationViewController.swift
//  linphone
//
//  Created by Ankit Khanna on 12/03/25.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import Firebase
import Foundation
import FirebaseStorage
import PhotosUI
import SDWebImage
import ContactsUI
import UniformTypeIdentifiers
import AVFoundation


struct PDFMediaItem: MediaItem {
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
    
    init(pdfURL: URL) {
        let defaultSize = CGSize(width: 200, height: 150) // Set size first

        self.url = pdfURL
        self.placeholderImage = UIImage(named: "pdf-file-icon") ?? UIImage() // Set default PDF icon
        self.size = defaultSize // ✅ Now size is initialized before usage
        self.image = generatePDFThumbnail(url: pdfURL, size: defaultSize) ?? self.placeholderImage
    }
    
    func generatePDFThumbnail(url: URL, size: CGSize) -> UIImage? {
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1) else { return nil }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            let rect = CGRect(origin: .zero, size: size)
            ctx.cgContext.drawPDFPage(page)
        }
    }
}




struct LocalChatMessage: Codable {
    let messageId: String
    let senderId: String
    let timestamp: Double
    let text: String?
    let fileUrl: String?
//    let imageUrl: String?
//    let pdfUrl: String?
//    let audioUrl: String?
//    let videoUrl: String?
//    let fileUrl: String?
    let type: String // "text", "photo", "video", "pdf"
    
}



struct FirebaseChatMessage: MessageType {
    let messageId: String
    let sender: SenderType
    let sentDate: Date
    let kind: MessageKind
    
    var imageUrl: String?
//    var pdfUrl: String?
//    var audioUrl: String?
    var videoUrl: String?
    var contactInfo: [String: Any]?
    var fileUrl: String?  // <-- Add this property
    var senderId: String { sender.senderId }
    
    // ✅ New Initializer for Creating a Message Manually
    init(messageId: String, sender: SenderType, sentDate: Date, text: String) {
        self.messageId = messageId
        self.sender = sender
        self.sentDate = sentDate
        self.kind = MessageKind.text(text) // ✅ Fix: Ensure correct MessageKind usage
        self.imageUrl = nil

    }
    
    
    
    // ✅ Initializer for Image Messages
    init(messageId: String, sender: SenderType, sentDate: Date, imageUrl: String) {
        self.messageId = messageId
        self.sender = sender
        self.sentDate = sentDate
        self.imageUrl = imageUrl
        self.kind = .photo(Media(url: imageUrl)) // ✅ Uses custom `Media` struct
    }

    // Initializer for PDF Messages
//    init(messageId: String, sender: SenderType, sentDate: Date, pdfUrl: String) {
//        self.messageId = messageId
//        self.sender = sender
//        self.sentDate = sentDate
//        self.pdfUrl = pdfUrl
//        self.kind = .custom(pdfUrl)
//    }
    
    // Initializer for File Messages
    init(messageId: String, sender: SenderType, sentDate: Date, fileUrl: String) {
        self.messageId = messageId
        self.sender = sender
        self.sentDate = sentDate
        self.fileUrl = fileUrl
        self.kind = .custom(fileUrl)
    }
    
    // Initializer for Audio Messages
//    init(messageId: String, sender: SenderType, sentDate: Date, audioUrl: String) {
//        self.messageId = messageId
//        self.sender = sender
//        self.sentDate = sentDate
//        self.audioUrl = audioUrl
//        self.kind = .custom(audioUrl)
//    }
    
    // Initializer for Video Messages
    init(messageId: String, sender: SenderType, sentDate: Date, videoUrl: String) {
        self.messageId = messageId
        self.sender = sender
        self.sentDate = sentDate
        self.videoUrl = videoUrl
        self.kind = .video(Media(url: videoUrl))
    }
    
    // Initializer for Contact Messages
    init(messageId: String, sender: SenderType, sentDate: Date, contactInfo: [String: Any]) {
        self.messageId = messageId
        self.sender = sender
        self.sentDate = sentDate
        self.contactInfo = contactInfo
        self.kind = .custom(contactInfo)
    }
    
    
    // ✅ Existing Initializer for Creating a Message from Firebase Data
    init?(firebaseData: [String: Any]) {

        guard let messageId = firebaseData["messageId"] as? String,
                 let senderId = firebaseData["senderId"] as? String,
                 let senderName = firebaseData["senderName"] as? String,
                 let timestamp = firebaseData["timestamp"] as? TimeInterval else {
               return nil
           }
        
        self.messageId = messageId
        self.sender = Sender(senderId: senderId, displayName: senderName)
        self.sentDate = Date(timeIntervalSince1970: timestamp / 1000) // Convert from milliseconds
        

        if let text = firebaseData["text"] as? String {
            self.kind = .text(text)
            self.imageUrl = nil
        } else if let imageUrl = firebaseData["imageUrl"] as? String {
            self.imageUrl = imageUrl
            self.kind = .photo(Media(url: imageUrl))
        }
//        else if let pdfUrl = firebaseData["fileUrl"] as? String {
//            self.fileUrl = pdfUrl
//            self.kind = .video(Media(url: pdfUrl)) // changed to video as custom type is crashing
//        }
        else if let fileUrl = firebaseData["fileUrl"] as? String,
                  let type = firebaseData["type"] as? String, type == "file" {
            self.fileUrl = fileUrl
            let mediaItem = PDFMediaItem(pdfURL: URL(string: fileUrl) ?? URL(string: "https://example.com/default.pdf")!)
            if fileUrl.contains("mp3") {
                self.kind = .video(Media(url: fileUrl))
            } else {
                self.kind = .video(Media(url: fileUrl)) // changed to video as custom type is crashing
            }
        }
//        else if let audioUrl = firebaseData["fileUrl"] as? String {
//            self.fileUrl = audioUrl
//            self.kind = .custom(audioUrl)
//        }
        else if let videoUrl = firebaseData["videoUrl"] as? String {
            self.videoUrl = videoUrl
            self.kind = .video(Media(url: videoUrl))
        }
        else if let contactInfo = firebaseData["contactInfo"] as? [String: Any] {
            self.contactInfo = contactInfo
            self.kind = .custom(contactInfo)
        }
        else {
            return nil
        }
    }
    
    
    // ✅ Convert to Firebase Dictionary
     func toDictionary() -> [String: Any] {
         var messageData: [String: Any] = [
             "messageId": messageId,
             "senderId": sender.senderId,
             "senderName": sender.displayName,
             "timestamp": sentDate.timeIntervalSince1970 * 1000 // Convert to milliseconds
         ]
         
         if let text = extractText() {
             messageData["text"] = text
         }
         
         if let imageUrl = imageUrl {
             messageData["imageUrl"] = imageUrl
         }
         if let pdfUrl = fileUrl {
             messageData["fileUrl"] = pdfUrl
         }
//         if let audioUrl = audioUrl {
//             messageData["audioUrl"] = audioUrl
//         }
         if let videoUrl = videoUrl {
             messageData["videoUrl"] = videoUrl
         }
         if let contactInfo = contactInfo {
             messageData["contactInfo"] = contactInfo
         }
         return messageData
     }
    
    // ✅ Helper function to extract text safely
    func extractText() -> String? {
        if case let MessageKind.text(text) = kind {
            return text
        }
        return nil
    }
    
    
        func kindToString() -> String {
            switch kind {
            case .text:
                return "text"
            case .photo:
                return "photo"
            case .video:
                return "video"
            case .custom:
                return "custom"
            default:
                return "unknown"
            }
        
    }
    
}

// ✅ Custom struct conforming to `MediaItem`
struct Media: MediaItem {
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
    
    // ✅ Initialize with URL (for Firebase media)
    init(url: String) {
        self.url = URL(string: url)
        self.image = nil
        self.placeholderImage = UIImage(named: "placeholder") ?? UIImage()
        self.size = CGSize(width: 200, height: 200)
    }
    
    // ✅ Initialize with UIImage (for local images before upload)
    init(image: UIImage) {
        self.url = nil
        self.image = image
        self.placeholderImage = image
        self.size = CGSize(width: 200, height: 200)
    }
    
    // ✅ Initialize with URL and custom size (for PDFs, videos, audio thumbnails)
    init(url: String, size: CGSize) {
        self.url = URL(string: url)
        self.image = nil
        self.placeholderImage = UIImage(named: "placeholder") ?? UIImage()
        self.size = size
    }
}



struct Sender: SenderType {
    var senderId: String
    var displayName: String
}



class FirebaseChatConversationViewController: MessagesViewController, UINavigationControllerDelegate {

    var messages: [FirebaseChatMessage] = []
     var chatId: String = "" // Chat ID from Firebase
    var receiverId = ""
    var currentUser = Sender(senderId: "user123", displayName: "Prakash Kumar") // Replace with actual user
   
    @objc dynamic var chatDetails: NSDictionary?
    private let topBarView = UIView()
    private let backButton = UIButton()
    private let userProfileImageView = UIImageView()
    private let userNameLabel = UILabel()
  
    
    @objc func initChatRoomFirebaseWithChatModel(_ chatModel: NSDictionary) {
        var convertedChatDetails = [String: Any]()
        
        for (key, value) in chatModel {
            if let keyString = key as? String {
                if let valueString = value as? String {
                    convertedChatDetails[keyString] = NSString(string: valueString)
                } else {
                    convertedChatDetails[keyString] = value
                }
            }
        }
        
        self.chatDetails = convertedChatDetails as NSDictionary
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        messagesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        
        messagesCollectionView.keyboardDismissMode = .interactive

//        messagesCollectionView.register(FirebaseChatMessageCell.self, forCellWithReuseIdentifier: "FirebaseChatMessageCell")
        messagesCollectionView.register(MediaMessageCell.self, forCellWithReuseIdentifier: "MediaMessageCell")

    
        messagesCollectionView.contentInset.top = 70
        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeBack))
        swipeGesture.direction = .right // ✅ Swiping right will trigger the back action
        view.addGestureRecognizer(swipeGesture)
        setChatBackground()
        setupTopNavigationBar() // ✅ Add Custom Top Bar
        setupSendButtonIcon() // ✅ Change the Send Button
        setupAttachmentButton()
        
        NotificationCenter.default.addObserver(self, selector: #selector(onNewMessageReceived), name: .newMessageReceived, object: nil)

        guard let chatDetails = chatDetails as? [String: Any] else {
            print("❌ No chat details provided")
            return
        }
        
        print("✅ Chat Details: \(chatDetails)") // ✅ Debugging: Print chat details
        
        let senderId = chatDetails["senderId"] as? String ?? "Unknown"
        let receiverId = chatDetails["receiverId"] as? String ?? "Unknown"
        let chatId = chatDetails["chatId"] as? String ?? "Unknown"

        print("📌 Sender ID: \(senderId)")
        print("📌 Receiver ID: \(receiverId)")
        print("📌 Chat ID: \(chatId)")
        self.chatId = chatId
        self.receiverId = receiverId
        currentUser = Sender(senderId: senderId, displayName: senderId)
        
//        CouchDBManager.shared.clearDatabase()
        self.fetchMessagesLocally(chatId: chatId)
        
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2) {
            FirebaseMessageSyncService.shared.startListeningForMessages(chatId: chatId)
//            self.fetchMessagesFromFirebase(chatId: chatId) // Load messages
        }
    }
    
    @objc private func handleSwipeBack() {
        self.dismiss(animated: true)
    }

    
    func setChatBackground() {
//        let backgroundImage = UIImage(named: "chat-wallpaper") // Replace with your image name
//        let backgroundImageView = UIImageView(image: backgroundImage)
//        backgroundImageView.contentMode = .scaleAspectFill
//        backgroundImageView.clipsToBounds = true
//        backgroundImageView.frame = view.bounds
//        
//        // Set background of MessagesCollectionView
//        messagesCollectionView.backgroundView = backgroundImageView
        
        // Set background color of MessagesCollectionView to #D8DADC
        messagesCollectionView.backgroundColor = UIColor(red: 235/255, green: 243/255, blue: 252/255, alpha: 1.0)
//        messageInputBar.backgroundColor = UIColor(red: 235/255, green: 243/255, blue: 252/255, alpha: 1.0)
    }
    @objc private func onNewMessageReceived() {
        fetchMessagesLocally(chatId: chatId) // Refresh from CouchDB
    }
    private func setupAttachmentButton() {
        let attachmentButton = InputBarButtonItem()
        attachmentButton.setSize(CGSize(width: 36, height: 36), animated: false)
        attachmentButton.setImage(UIImage(systemName: "paperclip"), for: .normal)
        attachmentButton.tintColor = .gray
        
        attachmentButton.onTouchUpInside { [weak self] _ in
            self?.presentAttachmentOptions()
        }
        
        messageInputBar.leftStackView.addArrangedSubview(attachmentButton)
        messageInputBar.setLeftStackViewWidthConstant(to: 40, animated: false)
    }
    
    private func presentAttachmentOptions() {
        let actionSheet = UIAlertController(title: "Attach File", message: nil, preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Photo/Video", style: .default) { _ in
            self.presentMediaPicker()
        })
        
        actionSheet.addAction(UIAlertAction(title: "Document (PDF)", style: .default) { _ in
            self.presentDocumentPicker()
        })
        
        actionSheet.addAction(UIAlertAction(title: "Audio", style: .default) { _ in
            self.presentAudioPicker()
        })
        
        actionSheet.addAction(UIAlertAction(title: "Contact", style: .default) { _ in
            self.presentContactPicker()
        })
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    // ✅ Present Media Picker (for Photo, Video, and Audio)
    private func presentMediaPicker() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        present(picker, animated: true, completion: nil)
    }

    // ✅ Present Contact Picker
    private func presentContactPicker() {
        let contactPicker = CNContactPickerViewController()
        contactPicker.delegate = self
        present(contactPicker, animated: true, completion: nil)
    }
    
    // ✅ Present Audio Picker
    private func presentAudioPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio])
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
    // ✅ Present Document Picker
    private func presentDocumentPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .text, .image, .audio, .video])
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
 
    
    private func setupSendButtonIcon() {
        let sendIcon = UIImage(systemName: "paperplane.fill")?
            .withRenderingMode(.alwaysTemplate) // ✅ Ensure tint color applies
            .applyingSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)) // ✅ Increase size
        
        messageInputBar.sendButton.setImage(sendIcon, for: .normal)
        messageInputBar.sendButton.setTitle("", for: .normal) // ✅ Remove text
        messageInputBar.sendButton.tintColor = .blue // ✅ Change icon color

        // ✅ Increase button size
        messageInputBar.sendButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        messageInputBar.sendButton.imageView?.contentMode = .scaleAspectFit
    }
    
    
    // ✅ Function to Setup Top Navigation Bar
    private func setupTopNavigationBar() {
        topBarView.backgroundColor = .white
        topBarView.layer.shadowColor = UIColor.black.cgColor
        topBarView.layer.shadowOpacity = 0.1
        topBarView.layer.shadowOffset = CGSize(width: 0, height: 1)
        topBarView.translatesAutoresizingMaskIntoConstraints = false

        // ✅ Back Button
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .black
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false

        // ✅ User Profile Image
        userProfileImageView.image = UIImage(systemName: "person.circle.fill") // Placeholder
        userProfileImageView.contentMode = .scaleAspectFill
        userProfileImageView.layer.cornerRadius = 20
        userProfileImageView.clipsToBounds = true
        userProfileImageView.translatesAutoresizingMaskIntoConstraints = false

        // ✅ User Name Label
        userNameLabel.text = chatDetails?["receiverId"] as? String ?? "Unknown"
        userNameLabel.font = UIFont.boldSystemFont(ofSize: 18)
        userNameLabel.textColor = .black
        userNameLabel.translatesAutoresizingMaskIntoConstraints = false

        // ✅ Add Subviews
        topBarView.addSubview(backButton)
        topBarView.addSubview(userProfileImageView)
        topBarView.addSubview(userNameLabel)
        view.addSubview(topBarView)

        // ✅ Constraints
        NSLayoutConstraint.activate([
            topBarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -6),
            topBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarView.heightAnchor.constraint(equalToConstant: 60),

//            messagesCollectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0),
//            messagesCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            messagesCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            messagesCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: topBarView.leadingAnchor, constant: 15),
            backButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.heightAnchor.constraint(equalToConstant: 30),

            userProfileImageView.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 10),
            userProfileImageView.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            userProfileImageView.widthAnchor.constraint(equalToConstant: 40),
            userProfileImageView.heightAnchor.constraint(equalToConstant: 40),

            userNameLabel.leadingAnchor.constraint(equalTo: userProfileImageView.trailingAnchor, constant: 10),
            userNameLabel.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor)
        ])

        // ✅ Ensure Top Bar Stays Visible
        view.bringSubviewToFront(backButton)
    }

    
    // ✅ Back Button Action
    @objc private func backButtonTapped() {
//        if let parentVC = self.parent {
//            self.willMove(toParent: nil)
//            self.view.removeFromSuperview()
//            self.removeFromParent()
//        }
        self.dismiss(animated: true)
    }

    // ✅ Upload Media to Firebase
    private func uploadFileToFirebase(data: Data, fileName: String, folder: String, completion: @escaping (String?) -> Void) {
        let storageRef = Storage.storage().reference().child("\(folder)/\(fileName)")
        
        storageRef.putData(data, metadata: nil) { metadata, error in
            if let error = error {
                print("❌ Upload failed: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Failed to get download URL: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                completion(url?.absoluteString)
            }
        }
    }
    

    // ✅ Upload image to Firebase Storage
    // ✅ Handle Image Upload
    private func uploadImageToFirebase(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.75) else {
            print("❌ Failed to convert image to JPEG format")
            return
        }
        
        let imageID = UUID().uuidString
        uploadFileToFirebase(data: imageData, fileName: "\(imageID).jpg", folder: "chat_images") { url in
            if let imageUrl = url {
                print("✅ Image Upload successful: \(imageUrl)")
                self.sendMessage(imageUrl: imageUrl, chatId: self.chatId, user1: self.currentUser.senderId, user2: self.receiverId)
            }
        }
    }
    
    private func uploadVideoToFirebase(videoURL: URL) {
        let videoID = UUID().uuidString
        let videoFileName = "\(videoID).mp4"

        do {
            let videoData = try Data(contentsOf: videoURL)
            
            uploadFileToFirebase(data: videoData, fileName: videoFileName, folder: "chat_videos") { url in
                if let videoUrl = url {
                    print("✅ Video Upload successful: \(videoUrl)")
                    self.sendMessage(fileUrl: videoUrl, chatId: self.chatId, user1: self.currentUser.senderId, user2: self.receiverId)
                } else {
                    print("❌ Video Upload failed")
                }
            }
        } catch {
            print("❌ Failed to read video data: \(error.localizedDescription)")
        }
    }

    
    // ✅ Handle Video, Audio, and Document Uploads
    private func uploadDocumentToFirebase(data: Data, fileName: String, folder: String) {
        let storageRef = Storage.storage().reference().child("\(folder)/\(fileName)")

        storageRef.putData(data, metadata: nil) { metadata, error in
            if let error = error {
                print("❌ Upload failed: \(error.localizedDescription)")
                return
            }

            storageRef.downloadURL { url, error in
                if let error = error {
                    print("❌ Failed to get download URL: \(error.localizedDescription)")
                    return
                }

                if let fileUrl = url?.absoluteString {
                    print("✅ File uploaded successfully: \(fileUrl)")
                    self.sendMessage(fileUrl: fileUrl, chatId: self.chatId, user1: self.currentUser.senderId, user2: self.receiverId)
                }
            }
        }
    }



   

    
   func stringToKind(_ type: String, mediaUrl: String?) -> MessageKind {
        guard let mediaUrl = mediaUrl, !mediaUrl.isEmpty else {
            return .text("Unknown message")
        }

        switch type {
        case "text":
            return .text(mediaUrl)
        case "photo":
            return .photo(Media(url: mediaUrl)) // Pass String instead of URL
        case "video":
            return .video(Media(url: mediaUrl))
        case "pdf":
            return .custom(mediaUrl)
        default:
            return .text("Unknown message type")
        }
    }

    func loadMessagesFromLocal(chatId: String) -> [LocalChatMessage] {
        return CouchDBManager.shared.loadMessages(chatId: chatId)
    }
    func saveLocalMessagesToDB(_ message: LocalChatMessage, chatId: String) {
        CouchDBManager.shared.saveMessage(message, chatId: chatId)
    }
//    func saveLocalMessagesArrayToDB(_ messages: [LocalChatMessage], chatId: String) {
//        for index in 0..<messages.count {
//            CouchDBManager.shared.saveMessage(messages[index], chatId: chatId)
//        }
//    }
    
    func fetchMessagesLocally(chatId: String) {
        // ✅ Load messages from local DB first
        let localMessages = loadMessagesFromLocal(chatId: chatId)
        self.messages = localMessages.compactMap { localMsg in
            let sender = Sender(senderId: localMsg.senderId, displayName: "Unknown") // Convert senderId to SenderType
            let sentDate = Date(timeIntervalSince1970: localMsg.timestamp)

            if let mediaUrl = localMsg.fileUrl {
                switch localMsg.type {
                case "text":
                    return FirebaseChatMessage(
                        messageId: localMsg.messageId,
                        sender: sender,
                        sentDate: sentDate,
                        text: localMsg.text ?? "" // ✅ Fixed text assignment
                    )
                case "photo":
                    return FirebaseChatMessage(
                        messageId: localMsg.messageId,
                        sender: sender,
                        sentDate: sentDate,
                        imageUrl: mediaUrl
                    )
                case "video":
                    return FirebaseChatMessage(
                        messageId: localMsg.messageId,
                        sender: sender,
                        sentDate: sentDate,
                        videoUrl: mediaUrl
                    )
                case "pdf":
                    return FirebaseChatMessage(
                        messageId: localMsg.messageId,
                        sender: sender,
                        sentDate: sentDate,
                        fileUrl: mediaUrl
                    )
                case "audio":
                    return FirebaseChatMessage(
                        messageId: localMsg.messageId,
                        sender: sender,
                        sentDate: sentDate,
                        fileUrl: mediaUrl
                    )
                default:
                    return nil
                }
            } else {
                return nil
            }
        }
 
        DispatchQueue.main.async {
            self.messagesCollectionView.reloadData()
            self.messagesCollectionView.scrollToLastItem(animated: true)
        }

    }

    // ✅ Fetch Messages from Firebase
    
    
    func fetchMessagesFromFirebase(chatId: String) {
        let chatRef = Database.database().reference()
            .child("WORKSPACE_VOXTRIO")
            .child("chats")
            .child(chatId)
            .child("messages")

        chatRef.observe(.childAdded) { [weak self] snapshot, _ in
            guard let self = self else { return }
            
//            guard snapshot.exists() else {
//                 // ✅ No messages → Show "No Conversations" UI
//                 self.messages.removeAll()
//                 self.messagesCollectionView.reloadData()
////                 self.showNoConversationsView()
//                 return
//             }
            
            guard let data = snapshot.value as? [String: Any],
                  let newMessage = FirebaseChatMessage(firebaseData: data) else { return }

            // ✅ Process in background to avoid UI lag
            DispatchQueue.global(qos: .userInitiated).async {
                if !self.messages.contains(where: { $0.messageId == newMessage.messageId }) {
                    self.messages.append(newMessage)

                    let localMessage = LocalChatMessage(
                        messageId: newMessage.messageId,
                        senderId: newMessage.sender.senderId,
                        timestamp: newMessage.sentDate.timeIntervalSince1970,
                        text: newMessage.extractText(),
                        fileUrl: newMessage.imageUrl ?? newMessage.videoUrl ?? newMessage.fileUrl,
                        type: newMessage.kindToString()
                    )

                    // ✅ Save to local DB in the background
//                    self.saveLocalMessagesToDB(localMessage, chatId: chatId)

                    // ✅ UI update on the main thread
//                    DispatchQueue.main.async {
//                        self.messagesCollectionView.reloadData()
//                        self.messagesCollectionView.scrollToLastItem(animated: false)
//                    }
                }
            }
        }
    }

    


    
    
    


    // ✅ Send Message to Firebase
    // ✅ Send Text or Image Message to Firebase
    
    // ✅ Send Message with Support for All Media Types
    private func sendMessage(text: String? = nil, imageUrl: String? = nil, fileUrl: String? = nil, chatId: String, user1: String, user2: String) {
        let chatRef = Database.database().reference().child("WORKSPACE_VOXTRIO").child("chats").child(chatId)
        let messageRef = chatRef.child("messages").childByAutoId()
        
        var messageData: [String: Any] = [
            "messageId": messageRef.key ?? UUID().uuidString,
            "senderId": currentUser.senderId,
            "senderName": currentUser.displayName,
            "timestamp": Date().timeIntervalSince1970 * 1000
        ]
        
        if let text = text {
            messageData["text"] = text
            messageData["type"] = "text"
        }
        
        if let imageUrl = imageUrl {
            messageData["imageUrl"] = imageUrl
            messageData["type"] = "image"
        }
        
        if let fileUrl = fileUrl {
              
              // 🔍 Check if the file is a video (based on common video extensions)
              let videoExtensions = ["mp4", "mov", "avi", "mkv"]
              if let fileExtension = URL(string: fileUrl)?.pathExtension.lowercased(), videoExtensions.contains(fileExtension) {
                  messageData["type"] = "video"
                  messageData["videoUrl"] = fileUrl
              } else {
                  messageData["type"] = "file"
                  messageData["fileUrl"] = fileUrl
              }
          }
        
        messageRef.setValue(messageData) { error, _ in
            if let error = error {
                print("❌ Error sending message: \(error.localizedDescription)")
            } else {
                print("✅ Message sent successfully!")
            }
        }
        
        let chatMetadataRef = chatRef.child("chatMetadata")
        let chatMetadata: [String: Any] = [
            "chatId": chatId,
            "user1": user1,
            "user2": user2,
            "lastMessage": text ?? "Attachment",
            "lastUpdated": Date().timeIntervalSince1970 * 1000
        ]
        
        chatMetadataRef.setValue(chatMetadata) { error, _ in
            if let error = error {
                print("❌ Error updating chat metadata: \(error.localizedDescription)")
            } else {
                print("✅ Chat metadata updated successfully!")
            }
        }
    }
    

    func generatePDFThumbnail(url: URL, size: CGSize) -> UIImage? {
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1) else { return nil }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            let rect = CGRect(origin: .zero, size: size)
            ctx.cgContext.drawPDFPage(page)
        }
    }
    
//    @objc func openPDF(_ sender: UITapGestureRecognizer) {
//        guard let indexPath = messagesCollectionView.indexPathForItem(at: sender.location(in: messagesCollectionView)),
//              let message = messages[indexPath.section] as? FirebaseChatMessage,
//              let pdfUrlString = message.pdfUrl,  // ✅ Use pdfUrl instead of fileUrl
//              let pdfUrl = URL(string: pdfUrlString) else {
//            print("❌ No valid PDF URL found")
//            return
//        }
//
//        let documentController = UIDocumentInteractionController(url: pdfUrl)
//        documentController.delegate = self
//        documentController.presentPreview(animated: true)
//    }
    func openPDF(url: URL) {
        let fileName = url.lastPathComponent
        let localFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        // Check if the file already exists locally
        if FileManager.default.fileExists(atPath: localFileURL.path) {
            presentPDFViewer(localFileURL)
            return
        }

        // Download the PDF file
        let session = URLSession.shared
        let downloadTask = session.downloadTask(with: url) { tempLocalUrl, response, error in
            guard let tempLocalUrl = tempLocalUrl, error == nil else {
                print("Download failed:", error?.localizedDescription ?? "Unknown error")
                return
            }
            
            // Move file from temp location to a permanent one
            do {
                try FileManager.default.moveItem(at: tempLocalUrl, to: localFileURL)
                DispatchQueue.main.async {
                    self.presentPDFViewer(localFileURL)
                }
            } catch {
                print("File move error:", error.localizedDescription)
            }
        }
        downloadTask.resume()
    }

    func presentPDFViewer(_ fileURL: URL) {
        let documentController = UIDocumentInteractionController(url: fileURL)
        documentController.delegate = self
        documentController.presentPreview(animated: true)
    }

    
    func generateVideoThumbnail(from url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let assetImageGenerator = AVAssetImageGenerator(asset: asset)
        assetImageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try assetImageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("❌ Error generating thumbnail: \(error)")
            return nil
        }
    }

    
    
//    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        let message = messages[indexPath.section]
//        
//        if case .video(let mediaItem) = message.kind {
//            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MediaMessageCell", for: indexPath) as! MediaMessageCell
//            cell.playButtonView.isHidden = true
//            
//            // Configure the media view
//            configureMediaMessageImageView(cell.imageView, for: message, at: indexPath, in: messagesCollectionView)
//            
//            return cell
//        }
//        // Fallback to default implementation
//        return super.collectionView(collectionView, cellForItemAt: indexPath)
//    }

    
    
    
}

// ✅ MessageKit DataSource & Delegates
extension FirebaseChatConversationViewController: UIDocumentInteractionControllerDelegate, MessageCellDelegate {
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let message = messages[indexPath.section]
        switch message.kind {
        case .video(let mediaItem):
            if let pdfURL = mediaItem.url { // Ensure URL exists
                openPDF(url: pdfURL)
            }
        default:
            print("Tapped a different message type")
        }
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {

        // Get the indexPath of the tapped cell
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            print("Could not determine indexPath")
            return
        }

        let message = messages[indexPath.section] // Fetch message at correct index

        switch message.kind {
        case .photo(let mediaItem):
            if let pdfURL = mediaItem.url { // Ensure URL exists
                openPDF(url: pdfURL)
            }
        case .video(let mediaItem):
            if let pdfURL = mediaItem.url { // Ensure URL exists
                openPDF(url: pdfURL)
            }
        default:
            print("Tapped a different message type")
        }
    }

    func didTapAvatar(in cell: MessageCollectionViewCell) {
        print("didTapAvatar works")
    }
    
    func didTapMessage(in cell: MessageCollectionViewCell, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let message = messages[indexPath.section]

        switch message.kind {
        case .video(let mediaItem):
            if let pdfURL = mediaItem.url { // Ensure URL exists
                openPDF(url: pdfURL)
            }
        default:
            print("Tapped a different message type")
        }
    }
    
 
}


// ✅ MessageKit DataSource & Delegates
extension FirebaseChatConversationViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate, InputBarAccessoryViewDelegate, UIImagePickerControllerDelegate, CNContactPickerDelegate, UIDocumentPickerDelegate {


    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)

        if let image = info[.originalImage] as? UIImage {
            uploadImageToFirebase(image: image) // ✅ Upload the image
        }
        // ✅ Check if it's a video
         if let videoURL = info[.mediaURL] as? URL {
             print("🎥 Picked a video: \(videoURL.absoluteString)")
             uploadVideoToFirebase(videoURL: videoURL) // ✅ Upload the video
             return
         }
    }
    
    
    // ✅ Handle selected document
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedFileURL = urls.first else {
            print("❌ No file selected")
            return
        }

        // Request secure access to iCloud Drive files
        let isSecuredAccess = selectedFileURL.startAccessingSecurityScopedResource()

        defer {
            if isSecuredAccess {
                selectedFileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let fileData = try Data(contentsOf: selectedFileURL)
            let fileExtension = selectedFileURL.pathExtension.lowercased()

            if ["jpg", "png", "jpeg"].contains(fileExtension) {
                uploadDocumentToFirebase(data: fileData, fileName: UUID().uuidString + ".\(fileExtension)", folder: "chat_images")
            } else if ["mp4", "mov"].contains(fileExtension) {
                uploadDocumentToFirebase(data: fileData, fileName: UUID().uuidString + ".\(fileExtension)", folder: "chat_videos")
            } else if ["mp3", "wav", "m4a"].contains(fileExtension) {
                uploadDocumentToFirebase(data: fileData, fileName: UUID().uuidString + ".\(fileExtension)", folder: "chat_audio")
            } else if ["pdf", "doc", "docx", "txt"].contains(fileExtension) {
                uploadDocumentToFirebase(data: fileData, fileName: UUID().uuidString + ".\(fileExtension)", folder: "chat_documents")
            } else {
                print("❌ Unsupported file type: \(fileExtension)")
            }
        } catch {
            print("❌ Failed to read file data: \(error.localizedDescription)")
        }
    }


    // ✅ Handle document picker cancellation
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("❌ Document picker cancelled")
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        
        if let message = message as? FirebaseChatMessage {
            switch message.kind {
            
            case .photo(let mediaItem):
                // If it's a photo, load the image
                if let imageUrl = mediaItem.url {
                    imageView.sd_setImage(with: imageUrl, placeholderImage: UIImage(named: "placeholder"))
                }
                
            case .video(let mediaItem):
                
                if let cell = messagesCollectionView.cellForItem(at: indexPath) as? MediaMessageCell {
                    cell.playButtonView.isHidden = true
                }
                // If it's a video, generate a thumbnail
                if let fileUrl = mediaItem.url?.absoluteString.lowercased() {
                    
                    if fileUrl.contains(".mp4") || fileUrl.contains(".mov") || fileUrl.contains(".avi") || fileUrl.contains(".mp3") {
                        // ✅ This is a video file, generate a thumbnail
//                        DispatchQueue.global(qos: .background).async {
//                            if let thumbnail = self.generateVideoThumbnail(from: mediaItem.url!) {
//                                DispatchQueue.main.async {
//                                    imageView.image = thumbnail
//                                }
//                            } else {
//                                DispatchQueue.main.async {
                                    imageView.image = UIImage(named: "video-file-icon") // Default video icon
//                                }
//                            }
//                        }
                        imageView.contentMode = .scaleToFill
                        
                        // ✅ Add a custom Play button for videos
                        let playButton = UIImageView(image: UIImage(named: "video-play-button-icon")) // Use your play button image
                        playButton.translatesAutoresizingMaskIntoConstraints = false
                        imageView.addSubview(playButton)
                        NSLayoutConstraint.activate([
                            playButton.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
                            playButton.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
                            playButton.widthAnchor.constraint(equalToConstant: 45),
                            playButton.heightAnchor.constraint(equalToConstant: 45)
                        ])
                        
                        
                    } else if fileUrl.contains(".pdf") {
                        // ✅ This is a PDF file
                        imageView.image = UIImage(named: "pdf-file-icon") // Show PDF icon
                        imageView.contentMode = .scaleAspectFit

                        // ✅ Add a container view to hold the button and label
                        let containerView = UIView()
                        containerView.translatesAutoresizingMaskIntoConstraints = false
                        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.6) // Semi-transparent background
                        containerView.layer.cornerRadius = 8
                        containerView.clipsToBounds = true
                        imageView.addSubview(containerView)

                        // ✅ Add Download Button
                        let downloadButton = UIImageView(image: UIImage(named: "download-round-blue-icon"))
                        downloadButton.translatesAutoresizingMaskIntoConstraints = false
                        containerView.addSubview(downloadButton)

                        // ✅ Add Label
                        let downloadLabel = UILabel()
                        downloadLabel.text = "Download"
                        downloadLabel.textColor = .white
                        downloadLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
                        downloadLabel.translatesAutoresizingMaskIntoConstraints = false
                        containerView.addSubview(downloadLabel)

                        // ✅ Apply Auto Layout Constraints
                        NSLayoutConstraint.activate([
                            // 📌 Container View at Bottom-Left
                            containerView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 8),
                            containerView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -8),
                            containerView.heightAnchor.constraint(equalToConstant: 30),

                            // 📌 Download Button Constraints
                            downloadButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
                            downloadButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                            downloadButton.widthAnchor.constraint(equalToConstant: 20),
                            downloadButton.heightAnchor.constraint(equalToConstant: 20),

                            // 📌 Label Constraints
                            downloadLabel.leadingAnchor.constraint(equalTo: downloadButton.trailingAnchor, constant: 6),
                            downloadLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                            downloadLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8)
                        ])

                        
                    } else {
                        // ✅ Other unknown file types
                        imageView.image = UIImage(named: "pdf-file-icon") // Generic file icon
                        imageView.contentMode = .scaleAspectFit
                    }
                }

                
            
            case .custom(let fileUrl):
                // If it's a file (PDF, doc, etc.), show a document icon
                if let fileUrl = fileUrl as? String, fileUrl.lowercased().contains(".pdf") {
                    imageView.image = UIImage(named: "pdf-file-icon")
                    imageView.contentMode = .scaleAspectFit
                } else {
                    imageView.image = UIImage(named: "file-icon") // Generic file icon
                }
                if let fileUrl = fileUrl as? String, fileUrl.lowercased().contains(".mp3") || fileUrl.lowercased().contains(".wav") || fileUrl.lowercased().contains(".m4a") {
                    imageView.image = UIImage(named: "pdf-file-icon")
                    imageView.contentMode = .scaleAspectFit
                }
                // ✅ Add a custom Play button for videos
                let playButton = UIImageView(image: UIImage(named: "video-play-button-icon")) // Use your play button image
                playButton.translatesAutoresizingMaskIntoConstraints = false
                imageView.addSubview(playButton)
                NSLayoutConstraint.activate([
                    playButton.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
                    playButton.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
                    playButton.widthAnchor.constraint(equalToConstant: 45),
                    playButton.heightAnchor.constraint(equalToConstant: 45)
                ])
            default:
                break
            }
        }
    }


    

    
//    func configureMessageCell(_ cell: MessageCollectionViewCell, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
//        print("🔹 configureMessageCell called for message: \(message.kind)")
//
//        if case .video(let mediaItem) = message.kind {
//            print("✅ This is a video message with URL: \(mediaItem.url?.absoluteString ?? "nil")")
//        }
//    }

    
    // ✅ Fix: Use `var` instead of `func` for currentSender
    var currentSender: any SenderType {
        return currentUser
    }
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let message = messages[indexPath.section]
        
        if message.sender.senderId == currentUser.senderId {
            return UIColor(hexWithString: "2A6BF7") // ✅ Sent messages (Right-aligned)
        } else {
            return UIColor.lightGray // ✅ Received messages (Left-aligned)
        }
    }

    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        let message = messages[indexPath.section]
           print("✅ Message Type at \(indexPath.section): \(message.kind)")

        return messages[indexPath.section]
    }
    
    
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        sendMessage(text: text, chatId: self.chatId, user1: self.currentUser.senderId, user2: self.receiverId)
        inputBar.inputTextView.text = ""
    }
    
    
    func avatarSize(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGSize? {
        return .zero
//        return .some(CGSize(width: 36, height: 36))
    }
    // ✅ Align messages (Right for current user, Left for others)
    
    func messageStyle(for message: any MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        let message = messages[indexPath.section]
//        if case .video(_) = message.kind {
//            return .custom { _ in }
//        }
        if message.sender.senderId == currentUser.senderId {
            return .bubbleTail(.bottomRight, .curved) // ✅ Sent message (Right)
        } else {
            return .bubbleTail(.bottomLeft, .curved) // ✅ Received message (Left)
        }
    }
    
}



//class FirebaseChatMessageCell: MessageCollectionViewCell {
//
//    let fileAttachmentView: UILabel = {
//        let label = UILabel()
//        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
//        label.textColor = .blue // Highlight it as a link
//        label.numberOfLines = 2
//        label.textAlignment = .left
//        label.isHidden = true // Hide by default
//        label.isUserInteractionEnabled = true
//        return label
//    }()
//
//    var fileUrl: String? // Store file URL for tapping
//
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        contentView.addSubview(fileAttachmentView)
//        
//        fileAttachmentView.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            fileAttachmentView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
//            fileAttachmentView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
//            fileAttachmentView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
//            fileAttachmentView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5)
//        ])
//
////        // Add tap gesture for opening file
////        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(openFile))
////        fileAttachmentView.addGestureRecognizer(tapGesture)
//    }
//
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    func configureFileMessage(with fileUrl: String) {
//        self.fileUrl = fileUrl
//        fileAttachmentView.text = "📎 Tap to Open PDF"
//        fileAttachmentView.isHidden = false
//    }
//
//    @objc private func openFile() {
//        if let urlString = fileUrl, let url = URL(string: urlString) {
//            UIApplication.shared.open(url)
//        }
//    }
//}



