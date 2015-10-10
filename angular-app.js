var app = angular.module('myApp', [ 'socket.io' ]);

app.config(function ($socketProvider) {
  $socketProvider.setConnectionUrl('http://localhost:8080');
});

app.controller('Ctrl', function Ctrl($scope, $socket) {

  $scope.tasks = [];

  $socket.on('echo', function (data) {
    console.log("received echo")
    $scope.serverResponse = data;
  });

  $socket.on('task-received', function (data) {
    console.log("received task")
    $scope.tasks.unshift(data);
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
});

