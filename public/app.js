var app = angular.module('insight', [ 'socket.io', 'ngAnimate' ]);

app.config(function ($socketProvider) {
  var url = "/";
  if(window.location.host.match(/localhost/)){
    url = "http://localhost:8000";
  }

  $socketProvider.setConnectionUrl(url);
});


// TODO: move to another file
var mainController = function ($scope, $timeout, $socket, InsightFactory) {

  $scope.tasks = [];
  $scope.projects = null;
  $scope.loaded = false;
  $scope.page = 1;
  $scope.togglePage = function(){
    if($scope.page === 1){
      return $scope.page = 2;
    }
    $scope.page = 1;
  }

  // TODO: move to a constant
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

  asanaColors = {
    "dark-pink": "#ed03b1",
    "dark-green": "#12ae3e",
    "dark-blue": "#0056f7",
    "dark-red": "#ee2400",
    "dark-teal": "#008eaa",
    "dark-brown": "#cc2f25",
    "dark-orange": "#e17000",
    "dark-purple": "#5105f0",
    "dark-warm-gray": "#6a1b21",
    "light-pink": "#ffabdd",
    "light-green": "#d7fd7a",
    "light-blue": "#9bbbf6",
    "light-red": "#ffadad",
    "light-teal": "#96d5ff",
    "light-yellow": "#ffeda4",
    "light-orange": "#ffcca5",
    "light-purple": "#e4b5f5",
    "light-warm-gray": "#e9aab1"
  } ;


  function generateChartForTeam(team, i){
    var $pies = $("#pies-1");
    if(i > 2){
      $pies = $("#pies-2");
    }

    var display_name = team["name"].substring(15,99999) // Strip off "Nike Team #1"

    $teamChart = $("<div class='team team-" + i +"' id='team-" + team["id"] +"'></div>");
    $teamChart.append("<h2>" + display_name + "</h2>");
    $teamChart.append("<div class='pie-chart'></div>");

    var $teamChartOld = $pies.find("#team-" + team["id"]);
    if($teamChartOld.length == 0){
      $pies.append($teamChart);
    } else {
      $teamChartOld.replaceWith($teamChart);
    }

    var chartData = [];
    var chartColors = {};
    var projects = team["projects"];
    for(var i = 0; i < projects.length; i++){
      var project = projects[i];
      chartData.push(
        [
          project["name"],
          project["taskCount"]
        ]
      );
      chartColors[project["name"]] = asanaColors[project["color"]]
    }

    var bindTo = '#team-' + team["id"] + " .pie-chart";

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
        },
        legend: {
          hide: true
        }
    });

    team.chart = chart;

    return chart;
  }

  function updateOnHeartbeat(heartbeat){
    var maxWidth = 900.0;
    var totalTaskCount = 0.0;
    var team, chart, diameter;

    teams = heartbeat.teams;
    console.log(heartbeat.wowTasks);
    console.log(heartbeat.deadTasks);

    // Set the totalTaskCount
    for(var i = 0; i < teams.length ; i++){
      team = teams[i];
      totalTaskCount += parseInt(team["taskCount"]);
    }

    // Calculate the diameter as a percentage of the total task count
    for(i = 0; i < teams.length ; i++){
      team = teams[i];
      diameter = (parseInt(team["taskCount"]) / totalTaskCount) * maxWidth;
      team.diameter = diameter;

      // Then render the chart
      generateChartForTeam(team, i);
    }
  }


  $socket.on("heartbeat", function (data) {
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
// Currently unused since we have one socket that just listens for heartbeats
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
