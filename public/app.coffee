app = angular.module('insight', [
  'socket.io'
  'ngAnimate'
])
app.config ($socketProvider) ->
  url = '/'
  if window.location.host.match(/localhost/)
    url = 'http://localhost:8000'
  $socketProvider.setConnectionUrl url

# TODO: move to another file
mainController = ($scope, $timeout, $socket, InsightFactory) ->

  generateChartForTeam = (team, i) ->
    `var i`
    $pies = $('#pies-1')
    if i > 2
      $pies = $('#pies-2')
    display_name = team['name'].substring(15, 99999)
    # Strip off "Nike Team #1"
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
    maxWidth = 900.0
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

  generateInitialWowMeter = () ->
    console.log $scope.wowTimes
    bindTo = "#wow-chart"
    chart = c3.generate(
      bindto: bindTo
      size:
        height: 640
        width: 1080
      data:
        x: "x"
        # xFormat: '%Y-%m-%d %H:%M:%S'
        columns: [
          $scope.wowTimes
          $scope.wowCounts
        ]
        # colors: ["Wows", "#ff00aa"]
        type: 'bar'

      axis: x:
        type: 'timeseries'
        tick: format: '%H:%M'
      legend:
        hide: false
    )
    $scope.wowChart = chart

  generateWowMeterForTeams = (teams) ->
    wowCount = 0
    i = 0
    while i < teams.length
      team = teams[i]
      wowCount += parseInt(team.wowTasks.length)
      i++

    $scope.wowTimes.push(new Date())
    $scope.wowCounts.push(wowCount)

    chartData = {
      columns: [
        $scope.wowTimes
        $scope.wowCounts
      ]
    }

    console.log(chartData)
    $scope.wowChart.load(chartData)

  updateOnHeartbeat = (heartbeat) ->
    teams = heartbeat.teams
    generateChartsForTeams teams
    generateWowMeterForTeams teams



  $scope.tasks = []
  $scope.projects = null
  $scope.loaded = false
  $scope.page = 1

  $scope.togglePage = () ->
    if $scope.page == 1
      return $scope.page = 2
    $scope.page = 1

  $scope.wowTimes =  ['x', new Date()]

  # ['2015-10-13 10:00:00', '2015-10-13 10:05:00', '2015-10-13 10:10:00', '2015-10-13 10:15:00', '2015-10-13 10:20:00', '2015-10-13 10:25:00', '2015-10-13 10:30:00', '2015-10-13 10:35:00', '2015-10-13 10:40:00', '2015-10-13 10:45:00', '2015-10-13 10:50:00', '2015-10-13 10:55:00']
  $scope.wowCounts = ["Wows", 2]
  # TODO: move to a constant

  asanaColors =
    'dark-pink':       '#ed03b1'
    'dark-green':      '#12ae3e'
    'dark-blue':       '#0056f7'
    'dark-red':        '#ee2400'
    'dark-teal':       '#008eaa'
    'dark-brown':      '#cc2f25'
    'dark-orange':     '#e17000'
    'dark-purple':     '#AA00FF'
    'dark-warm-gray':  '#6a1b21'
    'light-pink':      '#FF00AA'
    'light-green':     '#AAFF00'
    'light-blue':      '#9bbbf6'
    'light-red':       '#ffadad'
    'light-teal':      '#96d5ff'
    'light-yellow':    '#ffeda4'
    'light-orange':    '#FFAA00'
    'light-purple':    '#e4b5f5'
    'light-warm-gray': '#e9aab1'

  generateInitialWowMeter()

  $socket.on 'heartbeat', (data) ->
    $scope.loaded = true
    updateOnHeartbeat data

mainController.$inject = [
  '$scope'
  '$timeout'
  '$socket'
  'InsightFactory'
]
angular.module('insight').controller 'mainController', mainController
# TODO: move to another file
# Currently unused since we have one socket that just listens for heartbeats

InsightFactory = ($http) ->

  projects = ->
    $http.get '/projects'

  tasks = (projectId) ->
    $http.get '/tasks/' + projectId

  projectsWithTasks = ->
    $http.get '/projects-with-tasks'

  return {
    projects: projects
    projectsWithTasks: projectsWithTasks
  }

InsightFactory.$inject = [ '$http' ]
angular.module('insight').factory 'InsightFactory', InsightFactory
