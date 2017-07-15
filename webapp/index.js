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