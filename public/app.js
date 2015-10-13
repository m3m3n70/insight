var app = angular.module('insight', [ 'socket.io', 'ngAnimate' ]);

app.config(function ($socketProvider) {

  var url = "/";
  if(window.location.host.match(/localhost/)){
    url = "http://localhost:8080";
  }

  // console.log(url);

  $socketProvider.setConnectionUrl(url);
});


// TODO: move to another file

var mainController = function ($scope, $timeout, $socket, InsightFactory) {

  $scope.tasks = [];

  $scope.projects = null;

  $scope.loaded = false;
  // var styles = [
  //   "one",
  //   "two",
  //   "three",
  //   "four",
  //   "five",
  //   "six"
  // ];
  // Listen to task added events
  // $socket.on('task-added', function (data) {
  //   console.log("Added task")
  //   var project = data.project;
  //   var task = data.task;
  //   var projIndex = projectIdMap[project.id];
  //   $scope.projectsWithTasks[projIndex].tasks.unshift(task);
  // });

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

  asanaColors = {
    "dark-pink": "#b13f94",
    "dark-green": "#427e53",
    "dark-blue": "#3c68bb",
    "dark-red": "#c73f27",
    "dark-teal": "#008eaa",
    "dark-brown": "#906461",
    "dark-orange": "#e17000",
    "dark-purple": "#6743b3",
    "dark-warm-gray": "#493c3d",
    "light-pink": "#f4b6db",
    "light-green": "#c9db9c",
    "light-blue": "#b6c3db",
    "light-red": "#efbdbd",
    "light-teal": "#aad1eb",
    "light-yellow": "#ffeda4",
    "light-orange": "#facdaa",
    "light-purple": "#dacae0",
    "light-warm-gray": "#cec5c6"
  } ;

  function generateChartForTeam(team){
    var $pies = $("#pies");

    $teamChart = $("<div id='team-" + team["id"] +"'></div>");
    $teamChart.append("<h2>" + team["name"] + "</h2>");
    $teamChart.append("<div class='pie-chart'></div>");

    var $teamChartOld = $pies.find("#team-" + team["id"]);
    if($teamChartOld.length == 0){
      $pies.append($teamChart);
    } else {
      $teamChartOld.replaceWith($teamChart);
    }

    var chartData = [];
    var chartColors = {};
    var diameter = 0;

    var projects = team["projects"];
    for(var i = 0; i < projects.length; i++){
      var project = projects[i];
      diameter += parseInt(project["taskCount"]);
      chartData.push(
        [
          project["name"],
          project["taskCount"]
        ]
      );
      chartColors[project["name"]] = asanaColors[project["color"]]
    }

    // diameter = Math.min(200, diameter);

    // 1920 x 1080

    var bindTo = '#team-' + team["id"] + " .pie-chart";

    // console.log(bindTo);
    // console.log(chartData);
    // console.log(chartColors);

    var chart = c3.generate({
        bindto: '#team-' + team["id"] + " .pie-chart",
        size: {
          height: team.diameter,
          width: team.diameter
        },
        data: {
            columns: chartData,
            colors: chartColors,
            type : 'pie',
            // onclick: function (d, i) { console.log("onclick", d, i); },
            // onmouseover: function (d, i) { console.log("onmouseover", d, i); },
            // onmouseout: function (d, i) { console.log("onmouseout", d, i); }
        }
    });

    team.chart = chart;

    return chart;
  } ;

  function updateOnHeartbeat(heartbeat){

    // team = heartbeat[1];
    // generateChartForTeam(team);

    console.log(heartbeat);

    var maxWidth = 1080.0;
    var minWidth = 200;

    var totalTaskCount = 0.0;
    var team, chart, diameter;


    // Now, scale all the charts again based on the totalTaskCount

    for(var i = 0; i < heartbeat.length ; i++){
      team = heartbeat[i];
      totalTaskCount += parseInt(team["taskCount"]);
    }

    for(i = 0; i < heartbeat.length ; i++){
      team = heartbeat[i];
      console.log(team["taskCount"]);
      console.log(totalTaskCount);
      diameter = (parseInt(team["taskCount"]) / totalTaskCount) * maxWidth;
      console.log(team.name);
      console.log(diameter);
      team.diameter = diameter;


      generateChartForTeam(team);
    }



  } ;


  $socket.on("heartbeat", function (data) {
    // console.log("heartbeat");
    $scope.loaded = true;
    updateOnHeartbeat(data);
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
