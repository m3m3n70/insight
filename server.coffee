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
# wowTagId = 57545435627264
# deadTagId = 57545435627266

validatedTagId = 61101326856187
redTagId       = 61101326856210
yellowTagId    = 61101326856215
greenTagId     = 61101326856220



heartbeatDelay = 60000

# Firebase config
firebaseUrl = "https://sizzling-torch-5381.firebaseio.com/"
myFirebaseRef =  new Firebase(firebaseUrl)





# wowTagId       = 57532266416864
# deadTagId      = 56967458494204
# validatedTagId = 60712069729657
# redTagId       = 60712069729677
# yellowTagId    = 60712069729679
# greenTagId     = 60712069729681

# apiKey = "gFjQNCw.qpqlr3z4wwsFMBYCm5FPvjkH"
# projectId = 52963906013475
# workspaceId = 52963906013474




# These are dummy data from KJ's account
# projectIds = [
#   60711844335784
#   60711844335786
#   60711844335788
#   60711844335790
#   60711844335792
# ]

# Hardcoded for Cisco
teamId = 59388416160829

projectIds = [
  60701423699181
  60701423699183
  60701423699185
  60701423699187
  60701423699189
]




ignoreProjectIds = [
  # 59996830669742
  61575639942816
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
    ret = {} # JSON.parse(JSON.stringify(teams)) # hardcoded for now, clone it!
    i = 0
    projects = []
    projectsHash = {}
    for proj in projs
      do (proj) ->
        id = proj.id
        return if ignoreProjectIds.indexOf(id) > -1
        i++
        setTimeout ->
          client.projects.findById(id).then (response) ->
            projects.push(response)
            projectsHash[id] = response
            count++
            # Only return once all the async calls have completed
            if count == (projs.length - ignoreProjectIds.length)
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
              continue unless t
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

  # client.projects.findByWorkspace(workspaceId).then projectsCallback

  # console.log teamId
  client.projects.findByTeam(teamId).then projectsCallback

# TODO: uncomment when we want to listen
setupHeartbeatEmitter()

app.use express.static(__dirname + "/public")

app.get "/heartbeat", (req, res) ->
  heartbeat(res)

server.listen process.env.PORT, ->
  console.log "Listening at port " + process.env.PORT

io.sockets.on "connection", handleSocketConnection
