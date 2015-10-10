var express = require('express');
var app = express();
var server = require('http').Server(app);
var io = require('socket.io')(server);

var asana = require('asana');
var apiKey = 'gFjQNCw.qpqlr3z4wwsFMBYCm5FPvjkH';
var projectId = 52963906013475;
var client = asana.Client.create().useBasicAuth(apiKey);
var taskCollection = [];

app.use(express.static(__dirname));

server.listen(8080, function(){
  console.log('Listening at port 8080');
});

var setupAsanaListener = function(socket){
  var readable = client.events.stream(projectId, {periodSeconds: 3});
  var tasks = {};
  readable.on('data', function(item) {
    // console.log(item);
    if(item["type"] === "task" && item["resource"]["name"].length > 0){
      // console.log(Math.floor(Date.now() / 1000))
      if(tasks[item["resource"]["id"]]){
        // Task exists already, so this was an update and not an add
        socket.emit('task-updated', item["resource"]);
      } else {
        socket.emit('task-added', item["resource"]);
      }
      tasks[item["resource"]["id"]] = item["resource"]["name"];

    }
  });
}

var loadInitialTasks = function(socket){
  client.tasks.findByProject(projectId, {limit: 50}).then(function(collection) {
    taskCollection = collection.data;
    // console.log(collection.data);
    socket.emit("initial-tasks-loaded", collection.data);
  });
}

var handleSocketConnection = function (socket) {
  var _socket = socket;

  console.log('Someone connected');

  loadInitialTasks(_socket);


  setupAsanaListener(_socket);
  socket.on('echo', function (data) {
    console.log("server side echo received");
    _socket.emit('echo', data);
  });

  // socket.on('echo-ack', function (data, callback) {
  //   callback(data);
  // });
}

io.sockets.on('connection', handleSocketConnection);


