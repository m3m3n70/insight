// Generated by CoffeeScript 1.9.3
(function() {
  var InsightFactory, app, insightHeader, mainController, taskListDisplay, taskListEdit, teamCard;

  app = angular.module("insight", ["socket.io", "ngAnimate", "as.sortable"]);

  app.config(function($socketProvider) {
    var url;
    url = "/";
    if (window.location.host.match(/localhost/)) {
      url = 'http://localhost:8000';
    }
    return $socketProvider.setConnectionUrl(url);
  });

  mainController = function($scope, $timeout, $socket, $filter, InsightFactory) {
    var asanaColors, conditionallyAddTask, fireBaseUrl, firebaseRef, generateAllTasks, generateInitialWowMeter, generateWowMeterForTeams, generateWowTasks, init, initializeCountdown, initializeMisc, initializeTaskRotator, initializeTasks, miscQuestionMapping, processCsv, shuffle, teamIds, updateOnHeartbeat;
    teamIds = [52963906013475, 57010700420933, 57010700420935, 57010700420937, 57010700420939, 57010700420942];
    miscQuestionMapping = {
      "52963906013475": "team1title",
      "57010700420933": "team2title",
      "57010700420935": "team3title",
      "57010700420937": "team4title",
      "57010700420939": "team5title"
    };
    shuffle = function(o) {
      var i, j, x;
      i = o.length;
      while (i) {
        j = Math.floor(Math.random() * i);
        x = o[--i];
        o[i] = o[j];
        o[j] = x;
      }
      return o;
    };
    processCsv = function(allText) {
      var allTextLines, data, i, j, lines, tarr;
      allTextLines = allText.split(/\r\n|\n/);
      lines = [];
      i = 0;
      while (i < allTextLines.length - 1) {
        data = allTextLines[i].split(',');
        tarr = [];
        j = 0;
        while (j < data.length) {
          tarr.push(data[j]);
          j++;
        }
        lines.push(tarr);
        i++;
      }
      return lines;
    };
    generateInitialWowMeter = function() {
      return InsightFactory.getInitialWowCounts().then(function(data) {
        var bindTo, chart, rows;
        rows = processCsv(data.data);
        $scope.wowTimes = rows.map(function(a) {
          var x;
          x = new Date(0);
          x.setSeconds(a[0]);
          return x;
        });
        $scope.wowTimes.unshift("x");
        $scope.wowCounts = rows.map(function(a) {
          return a[1];
        });
        $scope.wowCounts.unshift("Wows");
        bindTo = "#wow-chart";
        chart = c3.generate({
          bindto: bindTo,
          data: {
            x: "x",
            columns: [$scope.wowTimes, $scope.wowCounts],
            type: 'area'
          },
          axis: {
            x: {
              type: 'timeseries',
              tick: {
                format: '%H:%M',
                multiline: false,
                rotate: 75,
                culling: {
                  max: 10
                }
              }
            }
          },
          legend: {
            show: false
          }
        });
        return $scope.wowChart = chart;
      });
    };
    generateWowMeterForTeams = function(teams) {
      var chartData, i, team, wowCount;
      wowCount = 0;
      i = 0;
      while (i < teams.length) {
        team = teams[i];
        wowCount += parseInt(team.validatedCount);
        i++;
      }
      $scope.wowTimes.push(new Date());
      $scope.wowCounts.push(wowCount);
      chartData = {
        columns: [$scope.wowTimes, $scope.wowCounts]
      };
      return $scope.wowChart.load(chartData);
    };
    $scope.wowTaskIds = {};
    $scope.wowTasks = [];
    generateWowTasks = function(teams) {
      var k, len, results, team, tempWowTasks;
      tempWowTasks = [];
      results = [];
      for (k = 0, len = teams.length; k < len; k++) {
        team = teams[k];
        results.push((function(team) {
          var l, len1, ref, results1, task;
          ref = team.wowTasks;
          results1 = [];
          for (l = 0, len1 = ref.length; l < len1; l++) {
            task = ref[l];
            if ($scope.wowTaskIds[task.id]) {
              continue;
            } else {
              $scope.wowTaskIds[task.id] = true;
              $scope.wowTasks.push({
                teamName: team.name,
                task: task
              });
              results1.push(true);
            }
          }
          return results1;
        })(team));
      }
      return results;
    };
    conditionallyAddTask = function(team, task) {
      if ($scope.allTaskIds[task.id]) {
        return true;
      } else {
        $scope.allTaskIds[task.id] = true;
        $scope.allTasks.unshift({
          teamName: team.name,
          task: task
        });
        return true;
      }
    };
    $scope.allTaskIds = {};
    $scope.allTasks = [];
    generateAllTasks = function(teams) {
      var compare, firstTime, k, keys, len, tasksHash, team, vals;
      firstTime = true;
      if ($scope.allTasks.length > 0) {
        firstTime = false;
      }
      for (k = 0, len = teams.length; k < len; k++) {
        team = teams[k];
        team.validatedTasks = [];
        tasksHash = team.tasksHash;
        keys = Object.keys(tasksHash);
        vals = keys.map(function(v) {
          var task;
          task = tasksHash[v];
          conditionallyAddTask(team, task);
          if (task.validated) {
            team.validatedTasks.push(task);
          }
          return task;
        });
        compare = function(a, b) {
          if (a.order < b.order) {
            return -1;
          }
          if (a.order > b.order) {
            return 1;
          }
          return 0;
        };
        team.validatedTasks = team.validatedTasks.sort(compare);
        team.validatedTasksSub = team.validatedTasks.splice(-3);
        team.validatedTasksSub = team.validatedTasksSub.reverse();
      }
      if (firstTime) {
        return shuffle($scope.allTasks);
      }
    };
    $scope.taskClass = function(task) {
      if (task.wow) {
        return "wow";
      }
      if (task.validated) {
        return "validated " + task.confidence;
      }
      if (task.dead) {
        return "dead";
      }
      return "";
    };
    initializeTaskRotator = function() {
      return $(function() {
        return setInterval((function() {
          if (!($scope.allTasks.length > 0)) {
            return;
          }
          return $timeout(function() {
            var lastEl, taskId;
            lastEl = $scope.allTasks.pop();
            $scope.allTasks.unshift(lastEl);
            taskId = lastEl.task.id;
            return $("#task-" + taskId).css({
              opacity: 0
            }).animate({
              opacity: 1
            });
          });
        }), 10000);
      });
    };
    updateOnHeartbeat = function(heartbeat) {
      var teams;
      teams = heartbeat.teams;
      $scope.teams = teams;
      generateWowMeterForTeams(teams);
      return generateAllTasks(teams);
    };
    $scope.loaded = false;
    $scope.page = 1;
    $scope.togglePage = function() {
      if ($scope.page === 1) {
        return $scope.page = 2;
      }
      if ($scope.page === 2) {
        return $scope.page = 3;
      }
      $scope.page = 1;
      return $timeout(function() {
        return $(window).trigger("resize");
      });
    };
    $scope.wowTimes = ['x', new Date()];
    $scope.wowCounts = ["Wows", 2];
    asanaColors = {
      'dark-pink': "#B8D0DE",
      'dark-green': "#9FC2D6",
      'dark-blue': "#86B4CF",
      'dark-red': "#107FC9",
      'dark-teal': "#0E4EAD",
      'dark-brown': "#0B108C",
      'dark-orange': "#B8D0DE",
      'dark-purple': "#9FC2D6",
      'dark-warm-gray': "#86B4CF",
      'light-pink': "#107FC9",
      'light-green': "#0E4EAD",
      'light-blue': "#0B108C",
      'light-red': "#B8D0DE",
      'light-teal': "#9FC2D6",
      'light-yellow': "#86B4CF",
      'light-orange': "#107FC9",
      'light-purple': "#0E4EAD",
      'light-warm-gray': "#0B108C"
    };
    fireBaseUrl = "https://sizzling-torch-5381.firebaseio.com/";
    firebaseRef = new Firebase(fireBaseUrl);
    $scope.solidTaskList = {
      firebaseId: "solid-tasks",
      taskList: [],
      newModel: {},
      title: "Solid Insights"
    };
    $scope.riskAreaList = {
      firebaseId: "risk-areas",
      taskList: [],
      newModel: {},
      title: "Risk Areas"
    };
    initializeTasks = function(obj) {
      var firebaseId, firebaseTasks, name;
      firebaseId = obj.firebaseId;
      firebaseTasks = firebaseRef.child(firebaseId);
      obj.sortTasks = function() {
        var compare;
        compare = function(a, b) {
          if (a.order < b.order) {
            return -1;
          }
          if (a.order > b.order) {
            return 1;
          }
          return 0;
        };
        return obj.taskList = obj.taskList.sort(compare);
      };
      obj.addTask = function() {
        var item;
        item = {
          task: obj.newModel.task,
          rating: obj.newModel.rating,
          order: 9999
        };
        return firebaseRef.child(firebaseId).push(item);
      };
      obj.removeTask = function(task) {
        var id;
        id = task.id;
        obj.taskList = $filter("filter")(obj.taskList, {
          id: "!" + id
        });
        return firebaseTasks.child(id).remove();
      };
      obj.saveTask = function(task) {
        var id, item, obj1;
        id = task.id;
        item = {
          task: task.task,
          rating: task.rating,
          order: task.order
        };
        return firebaseTasks.update((
          obj1 = {},
          obj1["" + id] = item,
          obj1
        ));
      };
      name = firebaseId;
      firebaseTasks.on("child_added", function(snapshot) {
        var id, item;
        id = snapshot.key();
        item = snapshot.val();
        item["id"] = id;
        return $timeout(function() {
          obj.taskList.push(item);
          return obj.sortTasks();
        });
      });
      firebaseTasks.on("child_removed", function(snapshot) {
        return $timeout(function() {
          var id;
          id = snapshot.key();
          obj.taskList = $filter("filter")(obj.taskList, {
            id: "!" + id
          });
          return obj.sortTasks();
        });
      });
      firebaseTasks.on("child_changed", function(snapshot) {
        return $timeout(function() {
          var id, item;
          id = snapshot.key();
          item = snapshot.val();
          obj.taskList = $filter("filter")(obj.taskList, {
            id: "!" + id
          });
          item["id"] = id;
          obj.taskList.push(item);
          return obj.sortTasks();
        });
      });
      return obj.dragControlListeners = {
        orderChanged: function(event) {
          var i, k, len, order, ref, task, updates;
          updates = {};
          i = 0;
          ref = obj.taskList;
          for (k = 0, len = ref.length; k < len; k++) {
            task = ref[k];
            order = task.id + "/order";
            updates[order] = i;
            i++;
          }
          return firebaseTasks.update(updates);
        }
      };
    };
    initializeMisc = function() {
      var firebaseId, firebaseMisc;
      $scope.misc = {};
      $scope.misc.question = function(projectId) {
        return $scope.misc[miscQuestionMapping[projectId]];
      };
      firebaseId = "misc";
      firebaseMisc = firebaseRef.child(firebaseId);
      firebaseMisc.on("child_changed", function(snapshot) {
        return $timeout(function() {
          var id, item;
          id = snapshot.key();
          item = snapshot.val();
          return $scope.misc[id] = item;
        });
      });
      return firebaseMisc.on("child_added", function(snapshot) {
        var id, item;
        id = snapshot.key();
        item = snapshot.val();
        return $timeout(function() {
          return $scope.misc[id] = item;
        });
      });
    };
    $scope.saveMisc = function() {
      var firebaseId, obj1;
      firebaseId = "misc";
      return firebaseRef.update((
        obj1 = {},
        obj1["" + firebaseId] = $scope.misc,
        obj1
      ));
    };
    initializeCountdown = function() {
      return jQuery(function() {
        var firebaseTime, format, resetTimer, timer, updateDisplay;
        timer = new CountDownTimer(5);
        firebaseTime = firebaseRef.child("time");
        firebaseTime.on("child_changed", function(snapshot) {
          var id, item;
          id = snapshot.key();
          item = snapshot.val();
          $("#new-time").val(item);
          return resetTimer(item);
        });
        firebaseTime.on("child_added", function(snapshot) {
          var id, item;
          id = snapshot.key();
          item = snapshot.val();
          if (id === "val") {
            $("#new-time").val(item);
            return resetTimer(item);
          }
        });
        resetTimer = function(t) {
          var min, newTime, newTimeParts, sec, seconds;
          newTime = $("#new-time").val();
          $(".timer").removeClass("expired");
          timer.pause();
          newTimeParts = newTime.split(":");
          min = 0;
          sec = 0;
          if (newTimeParts.length > 1) {
            min = parseInt(newTimeParts[0]);
            sec = parseInt(newTimeParts[1]);
          } else {
            sec = parseInt(newTimeParts[1]);
          }
          seconds = sec + min * 60;
          timer.setDur(seconds);
          updateDisplay(min, sec);
          timer.onTick(updateDisplay);
          return timer.start();
        };
        format = function(minutes, seconds) {
          minutes = minutes < 10 ? "0" + minutes : minutes;
          seconds = seconds < 10 ? "0" + seconds : seconds;
          return minutes + ":" + seconds;
        };
        updateDisplay = function(minutes, seconds) {
          $(".timer").text(format(minutes, seconds));
          if (this.expired && this.expired()) {
            return $(".timer").addClass("expired");
          }
        };
        return $("#reset-timer").on("click", function() {
          var newTime;
          newTime = $("#new-time").val();
          return firebaseTime.update({
            val: newTime
          });
        });
      });
    };
    init = function() {
      $scope.loaded = false;
      initializeTaskRotator();
      generateInitialWowMeter();
      initializeTasks($scope.solidTaskList);
      initializeTasks($scope.riskAreaList);
      initializeMisc();
      return initializeCountdown();
    };
    init();
    return $socket.on('heartbeat', function(data) {
      $scope.loaded = true;
      return updateOnHeartbeat(data);
    });
  };

  mainController.$inject = ["$scope", "$timeout", "$socket", "$filter", "InsightFactory"];

  angular.module("insight").controller("mainController", mainController);

  taskListEdit = function($timeout) {
    return {
      restrict: "E",
      templateUrl: "templates/task-list-edit.html",
      replace: true,
      scope: {
        obj: "="
      },
      link: function($scope, elem, attrs) {
        return $timeout(function() {});
      }
    };
  };

  taskListEdit.$inject = ["$timeout"];

  angular.module("insight").directive("taskListEdit", taskListEdit);

  taskListDisplay = function($timeout) {
    return {
      restrict: "E",
      templateUrl: "templates/task-list-display.html",
      replace: true,
      scope: {
        obj: "="
      },
      link: function($scope, elem, attrs) {
        return $timeout(function() {});
      }
    };
  };

  taskListDisplay.$inject = ["$timeout"];

  angular.module("insight").directive("taskListDisplay", taskListDisplay);

  insightHeader = function($timeout) {
    return {
      restrict: "E",
      templateUrl: "templates/insight-header.html",
      replace: false,
      scope: {
        misc: "="
      },
      link: function($scope, elem, attrs) {
        return $timeout(function() {});
      }
    };
  };

  insightHeader.$inject = ["$timeout"];

  angular.module("insight").directive("insightHeader", insightHeader);

  teamCard = function($timeout) {
    return {
      restrict: "E",
      templateUrl: "templates/team-card.html",
      replace: true,
      scope: {
        team: "=",
        misc: "="
      },
      link: function($scope, elem, attrs) {
        return $timeout(function() {});
      }
    };
  };

  teamCard.$inject = ["$timeout"];

  angular.module("insight").directive("teamCard", teamCard);

  InsightFactory = function($http) {
    var getInitialWowCounts, projects, projectsWithTasks, tasks;
    projects = function() {
      return $http.get("/projects");
    };
    tasks = function(projectId) {
      return $http.get('/tasks/' + projectId);
    };
    projectsWithTasks = function() {
      return $http.get('/projects-with-tasks');
    };
    getInitialWowCounts = function() {
      return $http.get("/wowcounts.csv");
    };
    return {
      projects: projects,
      projectsWithTasks: projectsWithTasks,
      getInitialWowCounts: getInitialWowCounts
    };
  };

  InsightFactory.$inject = ['$http'];

  angular.module('insight').factory('InsightFactory', InsightFactory);

}).call(this);
