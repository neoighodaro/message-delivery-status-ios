# How to build message delivery status in iOS using Pusher

When building an application, sometimes, it is useful to know when certain events take place. This enables your application to respond in realtime and can be used in a number of ways. In this article, we will focus on how to implement message delivery status on an iOS application.

This article assumes you already have knowledge on Swift and Xcode, and does not go into too much detail on how to use Xcode or the Swift syntax.

### What our application will do

The application will be an iOS chat application, and the application will allow you post messages and see the delivery status of the message when it has sent. This feature is similar to what you can find in chat applications like WhatsApp, Facebook Messenger, BBM and others. 

[Better Screenshot]

> Note: You will need a Pusher account to work with this tutorial, you can create one by [clicking here](https://pusher.com). Create a new application and note your cluster, app ID, secret and key; they will all be needed for this tutorial.

#### Getting started

To get started you will need XCode installed on your machine and also you will need Cocoapods package manager installed. If you have these installed then lets continue. If you have not installed Cocoapods do so:

```Shell
$ gem install cocoapods
```

Now that you have that installed, launch Xcode and create a new project, we are calling ours Anonchat. Now close Xcode and then `cd` to the root of your project and run the command `pod init`. This should generate a `Podfile` for you. Change the contents of the `Podfile`:

```
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
```

Now run the command `pod install` so the Cocoapods package manager can pull in the necessary dependencies. When this is complete, close XCode (if open) and then open the `.xcworkspace` file that is in the root of your project folder.

#### Creating the views for our iOS Application

We are going to be creating a couple of views that we will need for the chat application to function properly. The views will look something like the screenshot below:

![Message delivery status for iOS using Pusher](https://dl.dropbox.com/s/8551jebu1vava4k/message-delivery-status-on-ios-using-pusher-3.png) 

Quickly, what we have done above is create a the first ViewController which will serve as our welcome ViewController, and we have added a button which triggers navigation to the next controller which is a `Navigation Controller`. This Navigation Controller in turn has a View Controller set as the root controller.

### Coding the message delivery status for our iOS application

Now that we have set up the views using the interface builder on the `MainStoryboard`, lets add some functionality. The first thing we would do is create a `WelcomeViewController` and associate it with the first view on the left. This will be the logic house for that view; we wont add much to it for now though:

```Swift
import UIKit

class WelcomeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
```

Now that we have created that, we should create another controller called the `ChatViewController`, this controller would be the main power house and where everything would be happening. The controller would extend the `JSQMessagesViewController`. Once this controller is extended, we would automatically get a nice chat interface to work with out of the box, then we have to work on customising this chat interface to work for us.

```swift
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
```

If you notice on the `viewDidLoad` method, we are generating a random username and setting that to be the `senderId` and `senderDisplayName` on the controller. This extends the properties set in the parent controller and is required.

Before we continue working on the chat controller, we want to create a last class called the `AnonMessage` class. This will extend the `JSQMessage` class and we will be using this to extend the default functionality of the class.

```Swift
import UIKit
import JSQMessagesViewController

enum AnonMessageStatus {
    case sending
    case delivered
}

class AnonMessage: JSQMessage {
    var status : AnonMessageStatus
    var id : Int
    
    public init!(senderId: String, status: AnonMessageStatus, displayName: String, text: String, id: Int) {
        self.status = status
        self.id = id
        super.init(senderId: senderId, senderDisplayName: displayName, date: Date.init(), text: text)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

In the class above we have extended the `JSQMessage` class and we have also added some new properties to track; the `id` and the `status`. We also added an initialization method so we can specify the new properties before instantiating the `JSQMessage` class properly. We also added an `enum` that contains all the statuses the message could possibly have.

Now returning to the `ChatViewController` lets add a few properties that would be needed to the class:

```swift
static let API_ENDPOINT = "http://localhost:4000";

var messages = [AnonMessage]()
var pusher: Pusher!

var incomingBubble: JSQMessagesBubbleImage!
var outgoingBubble: JSQMessagesBubbleImage!
```

Now that its done, we will start customising the controller to suit our needs. First, we will add some logic to the `viewDidLoad` method: 

```Swift
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
```

In the above code, we started customising the way our chat interface would look using the parent class that has these properties already set. So for instance, we are setting the `incomingBubble` to blue, and the `outgoingBubble` to green. We have also eliminated the avatar display because we do not need it right now.

The next thing we are going to do is override some of the methods that come with the parent controller so that we can display messages, customise the feel and more:

```Swift
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
    let message = addMessage(senderId: senderId, name: senderId, text: text) as! AnonMessage

    postMessage(message: message)
    finishSendingMessage(animated: true)
}

private func isAnOutgoingMessage(_ indexPath: IndexPath!) -> Bool {
    return messages[indexPath.row].senderId == senderId
}
```

 The next thing we are going to do is create some new methods on the controller that would help us, post a new message, then another to hit the remote endpoint to send the message, then a last one to append the new message sent (or received) to the messages array:

```Swift
private func postMessage(message: AnonMessage) {
    let params: Parameters = ["sender": message.senderId, "text": message.text]
    hitEndpoint(url: ChatViewController.API_ENDPOINT + "/messages", parameters: params, message: message)
}

private func hitEndpoint(url: String, parameters: Parameters, message: AnonMessage? = nil) {
    Alamofire.request(url, method: .post, parameters: parameters).validate().responseJSON { response in
        switch response.result {
        case .success:
            if message != nil {
                message?.status = .delivered
                self.collectionView.reloadData()
            }

        case .failure(let error):
        	if message != nil {
              message?.status = .failed
              self.collectionView.reloadData()
        	}
            print(error)
        }
    }
}

private func addMessage(senderId: String, name: String, text: String) -> Any? {
    let leStatus = senderId == self.senderId
        ? AnonMessageStatus.sending
        : AnonMessageStatus.delivered

    let message = AnonMessage(senderId: senderId, status: leStatus, displayName: name, text: text, id: messages.count)

    if (message != nil) {
        messages.append(message as AnonMessage!)
    }

    return message
}
```

Great. Now everytime we send a new message, the `didPressSend` method will be triggered  and all the other ones will fall in to place nicely!

For the last piece of the puzzle, we want to create the method that listens for Pusher events and fires a callback when an event triggered is received.

```swift
private func listenForNewMessages() {
    let options = PusherClientOptions(
        host: .cluster("PUSHER_CLUSTER")
    )

    pusher = Pusher(key: "PUSHER_KEY", options: options)

    let channel = pusher.subscribe("chatroom")

    channel.bind(eventName: "new_message", callback: { (data: Any?) -> Void in
        if let data = data as? [String: AnyObject] {
            let author = data["sender"] as! String

            if author != self.senderId {
                let text = data["text"] as! String

                let message = self.addMessage(senderId: author, name: author, text: text) as! AnonMessage?
                message?.status = .delivered

                self.finishReceivingMessage(animated: true)
            }
        }
    })

    pusher.connect()
}
```

So in this method, we have created a `Pusher` instance, we have set the cluster and the key. We attach the instance to a `chatroom` channel and then bind to the `new_message` event on the channel. **Remember to replace the key and cluster with the actual value you have gotten from your Pusher dashboard**. 

Now we should be done with the application and as it stands, it should work but no messages can be sent just yet as we need a backend application for it to work properly.

### Building the backend Node application

Now that we are done with the iOS and XCode parts, we can create the NodeJS back end for the application. We are going to be using Express, so that we can quickly whip something up.

Create a directory for the web application and then create two new files:

```
// index.js
var path = require('path');
var Pusher = require('pusher');
var express = require('express');
var bodyParser = require('body-parser');

var app = express();

var pusher = new Pusher({
  appId: 'PUSHER_ID',
  key: 'PUSHER_KEY',
  secret: 'PUSHER_SECRET',
  cluster: 'PUSHER_CLUSTER',
  encrypted: true
});

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }));

app.post('/messages', function(req, res){
  var message = {
    text: req.body.text,
    sender: req.body.sender
  }
  pusher.trigger('chatroom', 'new_message', message);
  res.json({success: 200});
});

app.use(function(req, res, next) {
    var err = new Error('Not Found');
    err.status = 404;
    next(err);
});

module.exports = app;

app.listen(4000, function(){
  console.log('App listening on port 4000!')
})
```

and **packages.json**

```
{
  "main": "index.js",
  "dependencies": {
    "body-parser": "^1.16.0",
    "express": "^4.14.1",
    "path": "^0.12.7",
    "pusher": "^1.5.1"
  }
}

```

Now run `npm install` on the directory and then `node index.js` once the npm installation is complete. You should see *App listening on port 4000!* message.

![](https://dl.dropbox.com/s/cvwccr7x358r7to/message-delivery-status-on-ios-using-pusher-5.png)

## Testing the application

Once you have your local node webserver running, you will need to make some changes so your application can talk to the local webserver.

In the `info.plist` file, make the following changes: 

![](https://dl.dropbox.com/s/f9mwlct0eswxt14/message-delivery-status-on-ios-using-pusher-4.png)

With this change, you can build and run your application and it will talk directly with your local web application.

### Conclusion

In this article, we have explored how to create an iOS chat application with a message delivery status message after the message is sent to other users. For practice, you can expand the statuses to support more instances.

Have a question or feedback on the article? Please ask below in the comment section. The repository for the application and the Node backend is available [here](https://github.com/neoighodaro/message-delivery-status-ios).