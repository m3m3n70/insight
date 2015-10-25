app = angular.module("insight", [
  "socket.io"
  "ngAnimate"
  "as.sortable"
])

app.config ($socketProvider) ->
  url = "/"
  if window.location.host.match(/localhost/)
    url = 'http://localhost:8000'
  $socketProvider.setConnectionUrl url

# TODO: move to another file
mainController = ($scope, $timeout, $socket, $filter, InsightFactory) ->

  teamIds = [
    52963906013475
    57010700420933
    57010700420935
    57010700420937
    57010700420939
  ]

  miscQuestionMapping = {
    "52963906013475": "team1title"
    "57010700420933": "team2title"
    "57010700420935": "team3title"
    "57010700420937": "team4title"
    "57010700420939": "team5title"
  }




  shuffle = (o) ->
    i = o.length
    while i
      j = Math.floor(Math.random() * i)
      x = o[--i]
      o[i] = o[j]
      o[j] = x
    o

  generateChartForTeam = (team, i) ->
    $pies = $('#pies-1')
    if i > 2
      $pies = $('#pies-2')
    display_name = team['name'] # .substring(15, 99999) # Strip off "Nike Team #1"
    $teamChart = $('<div class=\'team team-' + i + '\' id=\'team-' + team['id'] + '\'></div>')
    $teamChart.append '<h2>' + display_name + '</h2>'
    $teamChart.append '<div class=\'pie-chart\'></div>'
    $teamChartOld = $pies.find('#team-' + team['id'])

    if $teamChartOld.length == 0
      $pies.append $teamChart
    else
      $teamChartOld.replaceWith $teamChart
    chartData = []
    chartColors = {}
    projects = team['projects']
    i = 0
    while i < projects.length
      project = projects[i]
      chartData.push [
        project['name']
        project['taskCount']
      ]
      chartColors[project['name']] = asanaColors[project['color']]
      i++
    bindTo = '#team-' + team['id'] + ' .pie-chart'
    chart = c3.generate(
      bindto: bindTo
      size:
        height: team.diameter
        width: team.diameter
      pie: label: format: (value, ratio, id) ->
        value
      data:
        columns: chartData
        colors: chartColors
        type: 'pie'
      legend: hide: true)
    team.chart = chart
    chart

  generateChartsForTeams = (teams) ->
    maxWidth = 1800.0
    totalTaskCount = 0.0
    diameter = undefined
    # Set the totalTaskCount
    i = 0
    while i < teams.length
      team = teams[i]
      totalTaskCount += parseInt(team['taskCount'])
      i++
    # Calculate the diameter as a percentage of the total task count
    i = 0
    while i < teams.length
      team = teams[i]
      diameter = parseInt(team['taskCount']) / totalTaskCount * maxWidth
      team.diameter = diameter
      # Then render the chart
      generateChartForTeam team, i
      i++
    return

  generateCardForTeam = (team, i) ->
    display_name = team['name']

    $teamChart = $('<div class=\'team team-' + i + '\' id=\'team-' + team['id'] + '\'></div>')
    $teamChart.append '<h2>' + display_name + '</h2>'

    #     <p>{{ team.wowTasks[team.wowTasks.length - 1] }}</p>
    # <p>{{ team.wowTasks[team.wowTasks.length - 2] }}</p>
    # <p>{{ team.wowTasks[team.wowTasks.length - 3] }}</p>

    # projects = team['projects']
    # i = 0
    # while i < projects.length
    #   project = projects[i]
    #   chartData.push [
    #     project['name']
    #     project['taskCount']
    #   ]
    #   i++


  generateCardsForTeams = (teams) ->
    i = 0
    while i < teams.length
      team = teams[i]
      totalTaskCount += parseInt(team['taskCount'])
      generateCardForTeam team, i
      i++

  processCsv = (allText) ->
    allTextLines = allText.split(/\r\n|\n/)
    lines = []
    i = 0
    while i < allTextLines.length - 1
      data = allTextLines[i].split(',')
      tarr = []
      j = 0
      while j < data.length
        tarr.push data[j]
        j++
      lines.push tarr
      i++
    lines


  # TODO: rename to validated
  generateInitialWowMeter = () ->
    # console.log $scope.wowTimes
    InsightFactory.getInitialWowCounts().then (data) ->
      # console.log(data.data)
      rows = processCsv(data.data)
      $scope.wowTimes = rows.map (a) ->
        x = new Date(0)
        x.setSeconds(a[0])
        x

      $scope.wowTimes.unshift "x"
      $scope.wowCounts = rows.map((a) -> a[1])
      $scope.wowCounts.unshift "Wows"

      # console.log($scope.wowTimes)
      # console.log($scope.wowCounts)

      # var utcSeconds = 1234567890;
      # var d = new Date(0); // The 0 there is the key, which sets the date to the epoch
      # d.setUTCSeconds(utcSeconds);

      bindTo = "#wow-chart"
      chart = c3.generate(
        bindto: bindTo
        # size:
        #   height: 640
        #   width: 1080
        data:
          x: "x"
          # xFormat: '%Y-%m-%d %H:%M:%S'
          columns: [
            $scope.wowTimes
            $scope.wowCounts
          ]
          # colors: ["Wows", "#ff00aa"]
          type: 'area'

        axis: x:
          type: 'timeseries'
          tick:
            format: '%H:%M'
            multiline:false
            rotate: 75
            culling:
              max: 10
        legend:
          show: false
      )
      $scope.wowChart = chart

  # TODO: rename to validated
  generateWowMeterForTeams = (teams) ->
    wowCount = 0
    i = 0
    while i < teams.length
      team = teams[i]
      wowCount += parseInt(team.validatedCount)
      i++

    $scope.wowTimes.push(new Date())
    $scope.wowCounts.push(wowCount)

    chartData = {
      columns: [
        $scope.wowTimes
        $scope.wowCounts
      ]
    }

    # console.log(chartData)
    $scope.wowChart.load(chartData)

  generateGraveyardForTeams = (teams) ->
    deadTasks = []
    for team in teams
      do (team) ->
        deadTasks = deadTasks.concat(team.deadTasks)

    $graveyard = $('#graveyard')

    $('#graveyard').empty();

    maxX = 900
    maxY = 450
    left = 0
    top = 0
    i = 0
    while i < deadTasks.length
      left = Math.floor(Math.random() * maxX / 95) * 95
      top = Math.floor(Math.random() * maxY / 150) * 150
      $img = $('<img src=\'images/grave2.png\' width=100 title=\'' + deadTasks[i].name + '\' />')
      $img.css
        left: left
        bottom: top
      $('#graveyard').append $img
      i++

    $graveyard = $('#graveyard')

    $('#graveyard').empty();

    maxX = 900
    maxY = 450
    left = 0
    top = 0
    i = 0
    while i < deadTasks.length
      left = Math.floor(Math.random() * maxX / 95) * 95
      top = Math.floor(Math.random() * maxY / 150) * 150
      $img = $('<img src=\'images/grave2.png\' width=100 title=\'' + deadTasks[i].name + '\' />')
      $img.css
        left: left
        bottom: top
      $('#graveyard').append $img
      i++

  $scope.wowTaskIds = {}
  $scope.wowTasks = []

  generateWowTasks = (teams) ->
    tempWowTasks = []
    for team in teams
      do (team) ->
        for task in team.wowTasks
          if $scope.wowTaskIds[task.id]
            continue
          else
            $scope.wowTaskIds[task.id] = true
            $scope.wowTasks.push(
              {
                teamName: team.name
                task: task
              }
            )
            true

  conditionallyAddTask = (team, task) ->
    # console.log(team)
    # console.log(task)
    if $scope.allTaskIds[task.id]
      true
    else
      $scope.allTaskIds[task.id] = true
      $scope.allTasks.unshift(
        {
          teamName: team.name
          task: task
        }
      )
      true

  $scope.allTaskIds = {}
  $scope.allTasks = []
  generateAllTasks = (teams) ->
    # console.log(teams)
    firstTime = true
    if $scope.allTasks.length > 0
      firstTime = false
    for team in teams
      team.validatedTasks = []
      tasksHash = team.tasksHash
      keys = Object.keys(tasksHash)
      vals = keys.map (v) ->
        task = tasksHash[v]
        conditionallyAddTask(team, task)
        team.validatedTasks.push(task) if task.validated
        task

      compare = (a, b) ->
        if a.order < b.order
          return -1
        if a.order > b.order
          return 1
        0
      team.validatedTasks = team.validatedTasks.sort compare
      team.validatedTasksSub = team.validatedTasks.splice(-3)
      team.validatedTasksSub = team.validatedTasksSub.reverse()




      # do (team) ->
      #   if team.wowTasks
      #     for task in team.wowTasks
      #       do (task) ->
      #         task.wow = true
      #         conditionallyAddTask(team, task)
      #   if team.validatedTasks
      #     for task in team.validatedTasks
      #       do (task) ->
      #         task.validated = true
      #         conditionallyAddTask(team, task)
      # projects = team.projects
      # i = 0
      # while i < projects.length
      #   project = projects[i]
      #   for task in project.tasks
      #     do (task) ->
      #       conditionallyAddTask(team, task)
      #   i++
    if firstTime
      shuffle($scope.allTasks)

  $scope.taskClass = (task) ->
    return "wow" if task.wow
    if task.validated
      return "validated #{task.confidence}"
    return "dead" if task.dead
    ""

  initializeTaskRotator = () ->
    $ ->
      setInterval (->
        return unless $scope.allTasks.length > 0
        $timeout ->
          lastEl = $scope.allTasks.pop()
          $scope.allTasks.unshift(lastEl)
          taskId = lastEl.task.id
          $("#task-#{taskId}").css({opacity: 0}).animate({opacity: 1})
      ), 10000

  updateOnHeartbeat = (heartbeat) ->
    teams = heartbeat.teams
    console.log(teams)
    $scope.teams = teams
    # generateChartsForTeams teams
    generateWowMeterForTeams teams
    generateAllTasks teams
    # generateGraveyardForTeams teams
    # generateWowTasks teams

  $scope.loaded = false
  $scope.page = 3

  $scope.togglePage = () ->
    return $scope.page = 2 if $scope.page == 1
    return $scope.page = 3 if $scope.page == 2
    $scope.page = 1
    return $timeout -> $(window).trigger("resize")

  $scope.wowTimes =  ['x', new Date()]
  $scope.wowCounts = ["Wows", 2]
  # TODO: move to a constant

  asanaColors =
    'dark-pink':      "#B8D0DE" # '#ed03b1'
    'dark-green':     "#9FC2D6" # '#12ae3e'
    'dark-blue':      "#86B4CF" # '#0056f7'
    'dark-red':       "#107FC9" # '#ee2400'
    'dark-teal':      "#0E4EAD" # '#008eaa'
    'dark-brown':     "#0B108C" # '#cc2f25'
    'dark-orange':    "#B8D0DE" # '#e17000'
    'dark-purple':    "#9FC2D6" # '#AA00FF'
    'dark-warm-gray': "#86B4CF" # '#6a1b21'
    'light-pink':     "#107FC9" # '#FF00AA'
    'light-green':    "#0E4EAD" # '#AAFF00'
    'light-blue':     "#0B108C" # '#9bbbf6'
    'light-red':      "#B8D0DE" # '#ffadad'
    'light-teal':     "#9FC2D6" # '#96d5ff'
    'light-yellow':   "#86B4CF" # '#ffeda4'
    'light-orange':   "#107FC9" # '#FFAA00'
    'light-purple':   "#0E4EAD" # '#e4b5f5'
    'light-warm-gray':"#0B108C" # '#e9aab1'

  fireBaseUrl = "https://sizzling-torch-5381.firebaseio.com/"
  firebaseRef = new Firebase(fireBaseUrl)

  $scope.solidTaskList = {
    firebaseId: "solid-tasks"
    taskList: []
    newModel: {}
    title: "Solid Insights"
  }

  $scope.riskAreaList = {
    firebaseId: "risk-areas"
    taskList: []
    newModel: {}
    title: "Risk Areas"
  }


  initializeTasks = (obj) ->
    firebaseId = obj.firebaseId
    firebaseTasks = firebaseRef.child(firebaseId)

    obj.sortTasks = () ->
      compare = (a, b) ->
        if a.order < b.order
          return -1
        if a.order > b.order
          return 1
        0
      obj.taskList = obj.taskList.sort compare

    obj.addTask = () ->
      # TODO
      item = {
        task: obj.newModel.task
        rating: obj.newModel.rating
        order: 9999
      }
      firebaseRef.child(firebaseId).push item

    obj.removeTask = (task) ->
      id = task.id
      obj.taskList = $filter("filter")(obj.taskList, {id: "!#{id}"})
      firebaseTasks.child(id).remove()

    obj.saveTask = (task) ->
      id = task.id
      # $("#solid-#{id} .display").show()
      # $("#solid-#{id} .edit").hide()

      item = {
        task: task.task
        rating: task.rating
        order: task.order
      }

      firebaseTasks.update("#{id}": item)

    name = firebaseId
    firebaseTasks.on "child_added", (snapshot) ->
      id = snapshot.key()
      item = snapshot.val()
      item["id"] = id
      $timeout ->
        obj.taskList.push(item)
        obj.sortTasks()

    firebaseTasks.on "child_removed", (snapshot) ->
      $timeout ->
        id = snapshot.key()
        obj.taskList = $filter("filter")(obj.taskList, {id: "!#{id}"})
        obj.sortTasks()

    firebaseTasks.on "child_changed", (snapshot) ->
      $timeout ->
        id = snapshot.key()
        item = snapshot.val()
        # console.log(item)
        obj.taskList = $filter("filter")(obj.taskList, {id: "!#{id}"})
        item["id"] = id
        obj.taskList.push(item)
        obj.sortTasks()

    obj.dragControlListeners =
      orderChanged: (event) ->
        # console.log(event)
        updates = {}
        i = 0
        for task in obj.taskList
          order = "#{task.id}/order"
          updates[order] = i
          i++

        firebaseTasks.update(updates)



  initializeMisc = () ->
    $scope.misc = {}
    $scope.misc.question = (projectId) ->
      $scope.misc[miscQuestionMapping[projectId]]

    firebaseId = "misc"
    firebaseMisc = firebaseRef.child(firebaseId)
    firebaseMisc.on "child_changed", (snapshot) ->
      $timeout ->
        id = snapshot.key()
        item = snapshot.val()
        # console.log(item)
        $scope.misc[id] = item

    firebaseMisc.on "child_added", (snapshot) ->
      id = snapshot.key()
      item = snapshot.val()
      $timeout ->
        $scope.misc[id] = item


  $scope.saveMisc = () ->
    firebaseId = "misc"
    firebaseRef.update("#{firebaseId}": $scope.misc)


  initializeCountdown = () ->
    jQuery ->

      timer = new CountDownTimer(5)

      firebaseTime = firebaseRef.child("time")

      firebaseTime.on "child_changed", (snapshot) ->
        id = snapshot.key()
        item = snapshot.val()
        $("#new-time").val(item)
        resetTimer(item)

      firebaseTime.on "child_added", (snapshot) ->
        id = snapshot.key()
        item = snapshot.val()
        if id == "val"
          $("#new-time").val(item)
          resetTimer(item)


      resetTimer = (t) ->
        newTime = $("#new-time").val()
        $(".timer").removeClass("expired")
        timer.pause()
        newTimeParts = newTime.split(":")
        min = 0
        sec = 0
        if newTimeParts.length > 1
          min = parseInt(newTimeParts[0])
          sec = parseInt(newTimeParts[1])
        else
          sec = parseInt(newTimeParts[1])

        seconds = sec + min * 60
        timer.setDur(seconds)

        updateDisplay(min, sec)
        timer.onTick updateDisplay
        timer.start()


      format = (minutes, seconds) ->
        minutes = if minutes < 10 then "0" + minutes else minutes
        seconds = if seconds < 10 then "0" + seconds else seconds
        minutes + ":" + seconds

      updateDisplay = (minutes, seconds) ->
        $(".timer").text format(minutes, seconds)
        if this.expired && this.expired()
          $(".timer").addClass("expired")


      $("#reset-timer").on "click", ->
        newTime = $("#new-time").val()
        firebaseTime.update({val: newTime})



  init = () ->
    $scope.loaded = true
    initializeTaskRotator()
    generateInitialWowMeter()
    initializeTasks($scope.solidTaskList)
    initializeTasks($scope.riskAreaList)
    initializeMisc()
    initializeCountdown()

  init()

  $socket.on 'heartbeat', (data) ->
    $scope.loaded = true
    updateOnHeartbeat data

mainController.$inject = [
  "$scope"
  "$timeout"
  "$socket"
  "$filter"
  "InsightFactory"
]
angular.module("insight").controller "mainController", mainController
# TODO: move to another file
# Currently unused since we have one socket that just listens for heartbeats



taskListEdit = ($timeout) ->
  restrict: "E"
  templateUrl: "templates/task-list-edit.html"
  replace: true
  scope: {
    obj: "="
  }
  link: ($scope, elem, attrs) ->
    $timeout ->
      # console.log($scope.obj)
      # Do stuff

taskListEdit.$inject = [
  "$timeout"
]

angular.module("insight").directive "taskListEdit", taskListEdit

taskListDisplay = ($timeout) ->
  restrict: "E"
  templateUrl: "templates/task-list-display.html"
  replace: true
  scope: {
    obj: "="
  }
  link: ($scope, elem, attrs) ->
    $timeout ->
      # console.log($scope.obj)
      # Do stuff

taskListDisplay.$inject = [
  "$timeout"
]

angular.module("insight").directive "taskListDisplay", taskListDisplay

insightHeader = ($timeout) ->
  restrict: "E"
  templateUrl: "templates/insight-header.html"
  replace: false
  scope: {
    misc: "="
  }

  link: ($scope, elem, attrs) ->
    $timeout ->
      # Do stuff

insightHeader.$inject = [
  "$timeout"
]

angular.module("insight").directive "insightHeader", insightHeader

teamCard = ($timeout) ->
  restrict: "E"
  templateUrl: "templates/team-card.html"
  replace: true
  scope: {
    team: "="
    misc: "="
  }
  link: ($scope, elem, attrs) ->
    $timeout ->
      # Do stuff

teamCard.$inject = [
  "$timeout"
]

angular.module("insight").directive "teamCard", teamCard



InsightFactory = ($http) ->

  projects = ->
    $http.get "/projects"

  tasks = (projectId) ->
    $http.get '/tasks/' + projectId

  projectsWithTasks = ->
    $http.get '/projects-with-tasks'

  getInitialWowCounts = () ->
    $http.get "/wowcounts.csv"

  return {
    projects: projects
    projectsWithTasks: projectsWithTasks
    getInitialWowCounts: getInitialWowCounts
  }

InsightFactory.$inject = [ '$http' ]
angular.module('insight').factory 'InsightFactory', InsightFactory
