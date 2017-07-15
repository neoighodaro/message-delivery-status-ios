# How to build message delivery status in iOS using Pusher
While building mobile chat applications, it is not uncommon to see developers adding the feature that lets you know when the message you sent has been delivered safely to the recipient. Instant Messaging applications like WhatsApp, Messenger, BBM, Skype and the likes all provide this feature.

This article will highlight how to add this feature to a mobile application developed for iOS using Swift and the [Pusher](http://pusher.com) SDK.

Some of the tools that we will be needing to build our application are:


1. **Xcode** - The application will be built using Apple’s Swift programming language.
2. **Node (Express)** - The backend application will be written using NodeJS.
3. **Pusher** - Pusher will provide realtime reporting when the sent messages are delivered. You will need a Pusher application ID, key and secret. Create one at [pusher.com](https://pusher.com).

Below is a screen recording of message delivery status using Pusher in action. As you can see, when a message is sent, it is marked as sent, and the moment it hits the recipients phone, it is marked as delivered.


![](https://dl.dropbox.com/s/qrml2une712my9f/message-delivery-status-on-ios-using-pusher-2.gif)


**Getting started with our iOS application**

To get started you will need Xcode installed on your machine and you will also need Cocoapods package manager installed. If you have not installed Cocoapods, here's how to do so:


    $ gem install cocoapods

Now that you have that installed, launch Xcode and create a new project. We are calling ours Anonchat.

Now close Xcode and then `cd` to the root of your project and run the command `pod init`. This should generate a `Podfile` for you. Change the contents of the `Podfile`:


    # Uncomment the next line to define a global platform for your project
    platform :ios, '9.0'
    
    target 'anonchat' do
      # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
      use_frameworks!
    
      # Pods for anonchat
      pod 'Alamofire'
      pod 'PusherSwift'
      pod 'JSQMessagesViewController'
    end

Now run the command `pod install` so the Cocoapods package manager can pull in the necessary dependencies. When this is complete, close Xcode (if open) and then open the `.xcworkspace` file that is in the root of your project folder.


**Creating the views for our iOS application**

We are going to be creating a couple of views that we will need for the chat application to function properly. The views will look something like the screenshot below:


https://www.dropbox.com/s/8551jebu1vava4k/message-delivery-status-on-ios-using-pusher-3.png?dl=1


What we have done above is create a the first ViewController which will serve as our welcome ViewController, and we have added a button which triggers navigation to the next controller which is a `Navigation Controller`. This Navigation Controller in turn has a View Controller set as the root controller.


**Coding the message delivery status for our iOS application**

Now that we have set up the views using the interface builder on the `MainStoryboard`, let's add some functionality. The first thing we will do is create a `WelcomeViewController` and associate it with the first view on the left. This will be the logic house for that view; we won't add much to it for now though:


    import UIKit

    class WelcomeViewController: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
        }
    }

Now that we have created that, we create another controller called the `ChatViewController`, which will be the main power house and where everything will be happening. The controller will extend the `JSQMessagesViewController` so that we automatically get a nice chat interface to work with out of the box, then we have to work on customizing this chat interface to work for us.



    import UIKit
    import Alamofire
    import PusherSwift
    import JSQMessagesViewController
    
    class ChatViewController: JSQMessagesViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
    
            let n = Int(arc4random_uniform(1000))
    
            senderId = "anonymous" + String(n)
            senderDisplayName = senderId
        }
    }

If you notice on the `viewDidLoad` method, we are generating a random username and setting that to be the `senderId` and `senderDisplayName` on the controller. This extends the properties set in the parent controller and is required.

Before we continue working on the chat controller, we want to create a last class called the `AnonMessage` class. This will extend the `JSQMessage` class and we will be using this to extend the default functionality of the class.



    import UIKit
    import JSQMessagesViewController
    
    enum AnonMessageStatus {
        case sending
        case sent
        case delivered
    }
    
    class AnonMessage: JSQMessage {
        var status : AnonMessageStatus
        var id : Int
    
        public init!(senderId: String, status: AnonMessageStatus, displayName: String, text: String, id: Int?) {
            self.status = status
            
            if (id != nil) {
                self.id = id!
            } else {
                self.id = 0
            }


​    
            super.init(senderId: senderId, senderDisplayName: displayName, date: Date.init(), text: text)
        }
    
        public required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

In the class above we have extended the `JSQMessage` class and we have also added some new properties to track; the `id` and the `status`. We also added an initialization method so we can specify the new properties before instantiating the `JSQMessage` class properly. We also added an `enum` that contains all the statuses the message could possibly have.

Now returning to the `ChatViewController` let's add a few properties to the class that will be needed:


    static let API_ENDPOINT = "http://localhost:4000";

    var messages = [AnonMessage]()
    var pusher: Pusher!
    
    var incomingBubble: JSQMessagesBubbleImage!
    var outgoingBubble: JSQMessagesBubbleImage!

Now that it's done, we will start customizing the controller to suit our needs. First, we will add some logic to the `viewDidLoad` method:


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
    }

In the above code, we started customizing the way our chat interface will look, using the parent class that has these properties already set. For instance, we are setting the `incomingBubble` to blue, and the `outgoingBubble` to green. We have also eliminated the avatar display because we do not need it right now.

The next thing we are going to do is override some of the methods that come with the parent controller so that we can display messages, customize the feel and more:


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

The next thing we are going to do is create some new methods on the controller that will help us, post a new message, then another to hit the remote endpoint to send the message, then a last one to append the new message sent (or received) to the messages array:


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

Great. Now every time we send a new message, the `didPressSend` method will be triggered and all the other ones will fall into place nicely!

For the last piece of the puzzle, we want to create the method that listens for Pusher events and fires a callback when an event trigger is received.


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

So in this method, we have created a `Pusher` instance, we have set the cluster and the key. We attach the instance to a `chatroom` channel and then bind to the `new_message` event on the channel. We also bind a `message_delivered` event, this will be the event that is triggered when a message is marked as delivered. It will update the message status to `delivered` so the sender knows the message has indeed been delivered.


> 💡 **Remember to replace the key and cluster with the actual value you have gotten from your Pusher dashboard**.

Now we should be done with the application and as it stands, it should work but no messages can be sent just yet as we need a backend application for it to work properly.

**Building the backend Node application**

Now that we are done with the iOS and Xcode parts, we can create the NodeJS back end for the application. We are going to be using Express so that we can quickly whip something up.

Create a directory for the web application and then create two new files:

The **index.js** file…


    // ------------------------------------------------------
    // Import all required packages and files
    // ------------------------------------------------------
    
    let Pusher     = require('pusher');
    let express    = require('express');
    let bodyParser = require('body-parser');
    let Promise    = require('bluebird');
    let db         = require('sqlite');
    let app        = express();
    let pusher     = new Pusher(require('./config.js')['config']);
    
    // ------------------------------------------------------
    // Set up Express
    // ------------------------------------------------------
    
    app.use(bodyParser.json());
    app.use(bodyParser.urlencoded({ extended: false }));
    
    // ------------------------------------------------------
    // Define routes and logic
    // ------------------------------------------------------
    
    app.post('/delivered', (req, res, next) => {
      let payload = {ID: ""+req.body.ID+""}
      pusher.trigger('chatroom', 'message_delivered', payload)
      res.json({success: 200})
    })
    
    app.post('/messages', (req, res, next) => {
      try {
        let payload = {
          text: req.body.text,
          sender: req.body.sender
        };
    
        db.run("INSERT INTO Messages (Sender, Message) VALUES (?,?)", payload.sender, payload.text)
          .then(query => {
            payload.ID = query.stmt.lastID
            pusher.trigger('chatroom', 'new_message', payload);
    
            payload.success = 200;
    
            res.json(payload);
          });
    
      } catch (err) {
        next(err)
      }
    });
    
    app.get('/', (req, res) => {
      res.json("It works!");
    });


    // ------------------------------------------------------
    // Catch errors
    // ------------------------------------------------------
    
    app.use((req, res, next) => {
        let err = new Error('Not Found');
        err.status = 404;
        next(err);
    });


    // ------------------------------------------------------
    // Start application
    // ------------------------------------------------------
    
    Promise.resolve()
      .then(() => db.open('./database.sqlite', { Promise }))
      .then(() => db.migrate({ force: 'last' }))
      .catch(err => console.error(err.stack))
      .finally(() => app.listen(4000, function(){
        console.log('App listening on port 4000!')
      }));

Here we define the entire logic of our backend application. We are also using SQLite to store the chat messages; this is useful to help identify messages. Of course, you can always change the way the application works to suite your needs.

The `index.js` file also has two routes where it receives messages from the iOS application and triggers the Pusher events which is picked up by the application.

next file is the **packages.json** where we define the NPM dependencies:


    {
      "main": "index.js",
      "dependencies": {
        "bluebird": "^3.5.0",
        "body-parser": "^1.16.0",
        "express": "^4.14.1",
        "pusher": "^1.5.1",
        "sqlite": "^2.8.0"
      }
    }

Now run `npm install` on the directory and then `node index.js` once the npm installation is complete. You should see *App listening on port 4000!* message.


![](https://dl.dropbox.com/s/cvwccr7x358r7to/message-delivery-status-on-ios-using-pusher-5.png)


**Testing the application**

Once you have your local node web server running, you will need to make some changes so your application can talk to the local web server. In the `info.plist` file, make the following changes:


![](https://dl.dropbox.com/s/f9mwlct0eswxt14/message-delivery-status-on-ios-using-pusher-4.png)


With this change, you can build and run your application and it will talk directly with your local web application.

**Conclusion**

In this article, we have explored how to create an iOS chat application with a message delivery status message after the message is sent to other users. For practice, you can expand the statuses to support more instances.

Have a question or feedback on the article? Please ask below in the comment section. The repository for the application and the Node backend is available [here](https://github.com/neoighodaro/message-delivery-status-ios).

