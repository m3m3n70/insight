var express = require('express');
var app = express();
var server = require('http').Server(app);
var io = require('socket.io')(server);

















app.use(express.static(__dirname));

server.listen(8080, function(){
    console.log('Listening at port 8080');
});

var handleSocketConnection = function (socket) {
  var _socket = socket;

  console.log('Someone connected');


  var asana = require('asana');

  var apiKey = 'gFjQNCw.qpqlr3z4wwsFMBYCm5FPvjkH';
  var projectId = 52963906013475;

  var client = asana.Client.create().useBasicAuth(apiKey);

  var readable = client.events.stream(projectId, {periodSeconds: 2});
  //readable._polling = true;
  readable.on('data', function(item) {
    console.log(item);
    if(item["type"] === "task" && item["resource"]["name"].length > 0){
      // console.log(Math.floor(Date.now() / 1000))
      // console.log("//-----------------------------------------------------------")
      _socket.emit('task-received', item);
      // console.log(item);
    }
    // readable.pause();
    // readable.resume();

  });





  socket.on('echo', function (data) {
    console.log("server side echo received");
    _socket.emit('echo', data);
  });

  // socket.on('echo-ack', function (data, callback) {
  //   callback(data);
  // });
}

io.sockets.on('connection', handleSocketConnection);


