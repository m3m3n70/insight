var app = angular.module('insight', [ 'socket.io', 'ngAnimate' ]);

app.config(function ($socketProvider) {

  var url = "/";
  if(window.location.host.match(/localhost/)){
    url = "http://localhost:8080";
  }

  $socketProvider.setConnectionUrl(url);
});


// TODO: move to another file

var mainController = function ($scope, $timeout, $socket, InsightFactory) {

  $scope.tasks = [];

  $scope.projects = null;

  var styles = [
    "one",
    "two",
    "three",
    "four",
    "five",
    "six"
  ];

  var projectIdMap = {};

  // Grab the initial projects with their tasks
  function loadProjectsWithTasks(){
    InsightFactory.projectsWithTasks().then(function(response){
      $timeout(function(){
        var i = 0;
        $scope.projectsWithTasks = response.data.map(function(project){
          project.cssClass = styles[i % 6];
          projectIdMap[project.id] = i;
          i++;
          return project;
        });
      });
    })
  }




  // Listen to task added events
  $socket.on('task-added', function (data) {
    console.log("Added task")
    var project = data.project;
    var task = data.task;
    var projIndex = projectIdMap[project.id];
    $scope.projectsWithTasks[projIndex].tasks.unshift(task);
  });

  $socket.on("heartbeat", function (data) {
    console.log("heartbeat");
    console.log(data);
  });


}

mainController.$inject = [
  "$scope",
  "$timeout",
  "$socket",
  "InsightFactory"
]

angular.module('insight').controller('mainController', mainController);

// TODO: move to another file

var InsightFactory = function ($http){
  var projects = function(){
    return $http.get("/projects");
  }

  var tasks = function(projectId){
    return $http.get("/tasks/" + projectId);
  }

  var projectsWithTasks = function(){
    return $http.get("/projects-with-tasks");
  }

  return {
    projects: projects,
    projectsWithTasks: projectsWithTasks
  }
}

InsightFactory.$inject = [
  "$http"
]

angular.module('insight').factory("InsightFactory", InsightFactory)












