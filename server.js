var express = require('express');
var app = express();
var server = require('http').Server(app);
var io = require('socket.io')(server);

var asana = require('asana');
// TODO: make these env variables
var apiKey = 'gFjQNCw.qpqlr3z4wwsFMBYCm5FPvjkH';
var projectId = 52963906013475;

var client = asana.Client.create().useBasicAuth(apiKey);
var taskCollection = [];


var allClients = [];

var emitAllClients = function(event, data){
  for(var i = 0; i < allClients.length; i++){
    if(allClients[i]){
      allClients[i].emit(event, data)
    }
  }
}

var tasks = {};

// TODO: move these to another file

var asanaListening = false;

var setupAsanaListener = function(socket){
  if(asanaListening){
    return true;
  }
  var readable = client.events.stream(projectId, {periodSeconds: 3});
  readable.on('data', function(item) {
    // console.log(item);
    if(item["type"] === "task" && item["resource"]["name"].length > 0){
      // console.log(Math.floor(Date.now() / 1000))
      if(tasks[item["resource"]["id"]]){
        // Task exists already, so this was an update and not an add
        emitAllClients('task-updated', item["resource"]);
      } else {
        emitAllClients('task-added', item["resource"]);
      }
      tasks[item["resource"]["id"]] = item["resource"]["name"];
    }
  });
  asanaListening = true;
}

var loadInitialTasks = function(socket){
  // if(taskCollection.length > 0){
  //   socket.emit("initial-tasks-loaded", taskCollection);
  // } else {
  client.tasks.findByProject(projectId, {completed_since: "now", limit: 50}).then(function(collection) {
    taskCollection = collection.data;
    socket.emit("initial-tasks-loaded", taskCollection);
  });
  // }
}

var handleSocketConnection = function (socket) {
  var _socket = socket;
  allClients.push(_socket);
  console.log(allClients.length + " users connected");
  loadInitialTasks(_socket);
  setupAsanaListener(_socket);

  socket.on('disconnect', function() {
    console.log('Got disconnect!');

    var i = allClients.indexOf(socket);
    delete allClients[i];
    console.log(allClients.length + " users connected");
  });

}

app.use(express.static(__dirname + "/public"));

server.listen(process.env.PORT, function(){
  console.log('Listening at port ' + process.env.PORT);
});

io.sockets.on('connection', handleSocketConnection);

