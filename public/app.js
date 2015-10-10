var app = angular.module('myApp', [ 'socket.io', 'ngAnimate' ]);

app.config(function ($socketProvider) {

  var url = "/";
  if(window.location.host.match(/localhost/)){
    url = "http://localhost:8080";
  }


  $socketProvider.setConnectionUrl(url);
});



var mainController = function ($scope, $timeout, $socket) {

  $scope.tasks = [];

  $socket.on('echo', function (data) {
    console.log("received echo")
    $scope.serverResponse = data;
  });

  $socket.on('task-added', function (data) {
    console.log("Added task")
    $scope.tasks.unshift(data);
  });

  $socket.on("initial-tasks-loaded", function (data) {
    $timeout(function(){
      console.log("Initial tasks loaded");
      $scope.tasks = data;
    });
  });

  $scope.emitBasic = function emitBasic() {
    console.log('echo event emited');
    $socket.emit('echo', $scope.dataToSend);
    $scope.dataToSend = '';
  };

  $scope.emitACK = function emitACK() {
    $socket.emit('echo-ack', $scope.dataToSend, function (data) {
      $scope.serverResponseACK = data;
    });
    $scope.dataToSend = '';
  };
}

mainController.$inject=[
  "$scope",
  "$timeout",
  "$socket",
]



app.controller('mainController', mainController);

