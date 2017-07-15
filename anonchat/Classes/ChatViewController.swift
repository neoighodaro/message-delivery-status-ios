//
//  ChatViewController.swift
//  anonchat
//
//  Created by Neo Ighodaro on 09/05/2017.
//  Copyright © 2017 CreativityKills Labs. All rights reserved.
//

import UIKit
import Alamofire
import PusherSwift
import JSQMessagesViewController

class ChatViewController: JSQMessagesViewController {
    static let API_ENDPOINT = "http://localhost:4000";

    var messages = [AnonMessage]()
    var pusher: Pusher!

    var incomingBubble: JSQMessagesBubbleImage!
    var outgoingBubble: JSQMessagesBubbleImage!

    override func viewDidLoad() {
        super.viewDidLoad()

        let n = Int(arc4random_uniform(1000))

        senderId = "anonymous" + String(n)
        senderDisplayName = senderId

        inputToolbar.contentView.leftBarButtonItem = nil

        incomingBubble = JSQMessagesBubbleImageFactory().incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
        outgoingBubble = JSQMessagesBubbleImageFactory().outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleGreen())

        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero

        automaticallyScrollsToMostRecentMessage = true

        collectionView?.reloadData()
        collectionView?.layoutIfNeeded()

        listenForNewMessages()
    }

    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }

    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForCellBottomLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        if !isAnOutgoingMessage(indexPath) {
            return nil
        }

        let message = messages[indexPath.row]

        switch (message.status) {
        case .sending:
            return NSAttributedString(string: "Sending...")
        case .sent:
            return NSAttributedString(string: "Sent")
        case .delivered:
            return NSAttributedString(string: "Delivered")
        }
    }

    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellBottomLabelAt indexPath: IndexPath!) -> CGFloat {
        return CGFloat(15.0)
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }

    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        if message.senderId == senderId {
            return outgoingBubble
        } else {
            return incomingBubble
        }
    }

    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }

    override func didPressSend(_ button: UIButton, withMessageText text: String, senderId: String, senderDisplayName: String, date: Date) {
        let message = addMessage(senderId: senderId, name: senderId, text: text, id: nil)

        if (message != nil) {
            postMessage(message: message as! AnonMessage)
        }
        
        finishSendingMessage(animated: true)
    }

    private func isAnOutgoingMessage(_ indexPath: IndexPath!) -> Bool {
        return messages[indexPath.row].senderId == senderId
    }

    private func postMessage(message: AnonMessage) {
        let params: Parameters = ["sender": message.senderId, "text": message.text]
        hitEndpoint(url: ChatViewController.API_ENDPOINT + "/messages", parameters: params, message: message)
    }

    private func hitEndpoint(url: String, parameters: Parameters, message: AnonMessage? = nil) {
        Alamofire.request(url, method: .post, parameters: parameters).validate().responseJSON { response in
            switch response.result {
            case .success(let JSON):
                let response = JSON as! NSDictionary

                if message != nil {
                    message?.id = (response.object(forKey: "ID") as! Int) as Int
                    message?.status = .sent
                    self.collectionView.reloadData()
                }

            case .failure(let error):
                print(error)
            }
        }
    }

    private func addMessage(senderId: String, name: String, text: String, id: Int?) -> Any? {
        let status = AnonMessageStatus.sending
        
        let id = id == nil ? nil : id;

        let message = AnonMessage(senderId: senderId, status: status, displayName: name, text: text, id: id)

        if (message != nil) {
            messages.append(message as AnonMessage!)
        }

        return message
    }

    private func listenForNewMessages() {
        let options = PusherClientOptions(
            host: .cluster("PUSHER_CLUSTER")
        )

        pusher = Pusher(key: "PUSHER_KEY", options: options)

        let channel = pusher.subscribe("chatroom")

        channel.bind(eventName: "new_message", callback: { (data: Any?) -> Void in
            if let data = data as? [String: AnyObject] {
                let messageId = data["ID"] as! Int
                let author = data["sender"] as! String
                
                if author != self.senderId {
                    let text = data["text"] as! String

                    let message = self.addMessage(senderId: author, name: author, text: text, id: messageId) as! AnonMessage?
                    message?.status = .delivered
                    
                    let params: Parameters = ["ID":messageId]
                    self.hitEndpoint(url: ChatViewController.API_ENDPOINT + "/delivered", parameters: params, message: nil)

                    self.finishReceivingMessage(animated: true)
                }
            }
        })
        
        channel.bind(eventName: "message_delivered", callback: { (data: Any?) -> Void in
            if let data = data as? [String: AnyObject] {
                let messageId = (data["ID"] as! NSString).integerValue
                let msg = self.messages.first(where: { $0.id == messageId })
                
                msg?.status = AnonMessageStatus.delivered
                self.finishReceivingMessage(animated: true)
            }
        })

        pusher.connect()
    }
}
