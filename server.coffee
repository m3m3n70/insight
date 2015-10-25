# Libraries
express = require("express")
app = express()
server = require("http").Server(app)
io = require("socket.io")(server)
asana = require("asana")
fs = require("fs")
Firebase = require("firebase")


# Config

apiKey = "gbNGGU78.LoEgfkUIdCHOOxCQoI8Mm3R"
workspaceId = 20868448192120 # fact0ry organization workspace
wowTagId = 57545435627264
deadTagId = 57545435627266

heartbeatDelay = 60000

# Firebase config
firebaseUrl = "https://sizzling-torch-5381.firebaseio.com/"
myFirebaseRef =  new Firebase(firebaseUrl)




wowTagId       = 57532266416864
deadTagId      = 56967458494204
validatedTagId = 60712069729657
redTagId       = 60712069729677
yellowTagId    = 60712069729679
greenTagId     = 60712069729681

apiKey = "gFjQNCw.qpqlr3z4wwsFMBYCm5FPvjkH"
projectId = 52963906013475
workspaceId = 52963906013474


# Hardcoded for Nike, but will be able to pull from asana in the future
teams = {
  56815679044828: {
    id: "56815679044828"
    name: "Invite & Join"
    # name: "Nike Team #1 - Invite & Join"
    projects: []
    ignoreProjectIds: [
      57753556680343
      57753556680345
      57753556680363
    ]
    wowProjectId: 57753556680345
    validatedProjectId: 57753556680343
    deadProjectId: 57753556680363
    taskCount: 0
  }
  56815685307709: {
    id: "56815685307709"
    name: "Do More, Do Better"
    # name: "Nike Team #2 - Do More, Do Better"
    projects: []
    ignoreProjectIds: [
      57753556680347
      57753556680349
      57753556680365
    ]
    wowProjectId: 57753556680349
    validatedProjectId: 57753556680347
    deadProjectId: 57753556680365
    taskCount: 0
  }
  56815679044829: {
    id: "56815679044829"
    name: "Inside Access"
    # name: "Nike Team #3 - Inside Access"
    projects: []
    ignoreProjectIds: [
      57753556680351
      57753556680353
      57753556680367
    ]
    wowProjectId: 57753556680353
    validatedProjectId: 57753556680351
    deadProjectId: 57753556680367
    taskCount: 0
  }
  56815679044830: {
    id: "56815679044830"
    name: "Elevate the Athlete"
    # name: "Nike Team #4 - Elevate the Athlete"
    projects: []
    ignoreProjectIds: [
      57753556680355
      57753556680357
      57753556680371
    ]
    wowProjectId: 57753556680357
    validatedProjectId: 57753556680355
    deadProjectId: 57753556680371
    taskCount: 0
  }
  56909588915212: {
    id: "56909588915212",
    name: "Command Center"
    # name: "Nike Team #5 - Command Center"
    projects: []

    ignoreProjectIds: [
      57753556680359
      57753556680361
      57753556680373
    ]
    wowProjectId: 57753556680361
    validatedProjectId: 57753556680359
    deadProjectId: 57753556680373
    taskCount: 0
  }
}

# Hardcoded for Nike, but will be able to pull from asana in the future
teamIds = [
  56815685307709
  56815679044828
  56815679044829
  56815679044830
  56909588915212
]


projectIds = [
  60711844335784
  60711844335786
  60711844335788
  60711844335790
  60711844335792
]









client = asana.Client.create().useBasicAuth(apiKey)
taskCollection = []
allClients = []
tasks = {}
heartbeats = [false]

# TODO: move these to another file
asanaListening = false

Array::remove = (from, to) ->
  rest = @slice((to or from) + 1 or @length)
  @length = if from < 0 then @length + from else from
  @push.apply this, rest

emitAllClients = (event, data) ->
  i = 0
  while i < allClients.length
    if allClients[i]
      allClients[i].emit event, data
    i++

handleSocketConnection = (socket) ->
  _socket = socket
  allClients.push _socket
  _socket.emit("heartbeat", heartbeats[0]) if heartbeats[0]
  console.log allClients.length + " users connected"
  socket.on "disconnect", ->
    console.log "Got disconnect!"
    i = allClients.indexOf(socket)
    allClients.remove(i)
    console.log allClients.length + " users connected"

setupHeartbeatEmitter = (socket) ->
  heartbeat(null, socket)
  setInterval ->
    heartbeat(null, socket)
  , heartbeatDelay

heartbeat = (res) ->
  console.log("Starting heartbeat")
  console.log(new Date())
  # 1. Get the teams
  # teamIds = teamIds # hardcoded for now


  # TODO: refactor the steps into chained promises using Q

  # 2. Get the projects
  # We are getting all the projects for the workspace instead of per team
  # Because this saves us 1 api call per team
  workspaceId = workspaceId
  projectsCallback = (response) ->
    projs = response.data
    count = 0
    # Get the full project objects to get the color of the project
    ret = JSON.parse(JSON.stringify(teams)) # hardcoded for now, clone it!
    i = 0
    projects = []
    projectsHash = {}
    for proj in projs
      do (proj) ->
        i++
        id = proj.id
        setTimeout ->
          client.projects.findById(id).then (response) ->
            projects.push(response)
            projectsHash[id] = response
            count++
            # Only return once all the async calls have completed
            if count == projs.length
              findTasks(projects, projectsHash, ret)
        , i * 250

  # 2. Get the tasks for each project
  findTasks = (projects, projectsHash, ret) ->
    count = 0
    i = 0
    allTasks = {}
    for proj2 in projects
      do (proj2) ->
        i++
        id = proj2.id
        proj = projectsHash[id]
        setTimeout ->
          client.tasks.findByProject(id, {completed_since: "now"}).then (collection) ->
            #  proj["tasks"] = collection.data
            proj["tasksHash"] = {}
            j = 0
            for task in collection.data
              task["order"] = j
              task["projectId"] = proj.id
              proj["tasksHash"][task.id] = task
              allTasks[task.id] = task
              j++

            proj["taskCount"] = collection.data.length
            count++
            # Only return once all the async calls have completed
            if count == projects.length
              getTaggedTasks(projectsHash, allTasks, ret)
        , i * 1000


  getTaggedTasks = (projectsHash, allTasks, ret) ->
    count = 0
    validatedTasks = null
    tagIds = [validatedTagId, redTagId, yellowTagId, greenTagId]
    validatedCount = 0
    i = 0
    for tagId in tagIds
      do (tagId) ->
        i++
        setTimeout ->
          client.tasks.findByTag(tagId).then (response) ->
            taggedTasks = response.data
            count++
            for taggedTask in taggedTasks
              t = allTasks[taggedTask.id]
              proj = projectsHash[t.projectId]

              if tagId == validatedTagId
                proj["tasksHash"][t.id].validated = true
                proj["validatedCount"] = 0 unless proj["validatedCount"]
                proj["validatedCount"] += 1
                validatedCount++
              else if tagId == redTagId
                proj["tasksHash"][t.id].rating = "red"
              else if tagId == yellowTagId
                proj["tasksHash"][t.id].rating = "yellow"
              else if tagId == greenTagId
                proj["tasksHash"][t.id].rating = "green"

            if count == 4 # 2
              assignProjectsToTeams(projectsHash, allTasks, validatedCount, ret)
        , i * 1000

        # proj["validatedTasksHash"] = {} unless proj["validatedTasks"]
        # proj["validatedTasksHash"][t.id] = t


    # client.tasks.findByTag(deadTagId).then (response) ->
    #   deadTasks = response.data
    #   count++
    #   if count == 2
    #     buildEmitResponse(projects, wowTasks, deadTasks)

  # 3. Hook the projects up to their respective teams
  # 4. Grab the tasks marked with "wow"
  # 5. Grab the tasks marked with "dead"
  # 6. Grab the tasks marked with "validated"
  assignProjectsToTeams = (projectsHash, allTasks, validatedCount, ret) ->
    tnow = Math.floor(new Date().getTime() / 1000)

    fs.appendFile "public/wowcounts.csv", "#{tnow},#{validatedCount}\n", (err) ->
      if err
        console.log "error"
      # console.log 'The "data to append" was appended to file!'
    buildEmitResponse(projectsHash)






  buildEmitResponse = (ret) ->
    keys = Object.keys(ret)
    vals = keys.map (v) -> ret[v]

    compare = (a, b) ->
      if a.name < b.name
        return -1
      if a.name > b.name
        return 1
      0

    vals = vals.sort compare

    cur = {
      teams: vals
    }

    heartbeats[0] = cur

    emitAllClients "heartbeat", cur
    if res
      res.send(cur)
    console.log("Sent heartbeat")
    console.log(new Date())

  client.projects.findByWorkspace(workspaceId).then projectsCallback


# TODO: uncomment when we want to listen
setupHeartbeatEmitter()

app.use express.static(__dirname + "/public")

app.get "/heartbeat", (req, res) ->
  heartbeat(res)

server.listen process.env.PORT, ->
  console.log "Listening at port " + process.env.PORT

io.sockets.on "connection", handleSocketConnection
