# Libraries
express = require("express")
app = express()
server = require("http").Server(app)
io = require("socket.io")(server)
asana = require("asana")

# Config

apiKey = "gbNGGU78.LoEgfkUIdCHOOxCQoI8Mm3R"
workspaceId = 20868448192120 # fact0ry organization workspace
wowTagId = 57545435627264
deadTagId = 57545435627266

# wowTagId = 57532266416864
# deadTagId = 56967458494204
# apiKey = "gFjQNCw.qpqlr3z4wwsFMBYCm5FPvjkH"
# projectId = 52963906013475
# workspaceId = 52963906013474

# Hardcoded for Nike, but will be able to pull from asana in the future
teams = {
  56815679044828: { id: "56815679044828", name: 'Nike Team #1 - Invite & Join'       , projects: [], taskCount: 0}
  56815685307709: { id: "56815685307709", name: 'Nike Team #2 - Do More, Do Better'  , projects: [], taskCount: 0}
  56815679044829: { id: "56815679044829", name: 'Nike Team #3 - Inside Access'       , projects: [], taskCount: 0}
  56815679044830: { id: "56815679044830", name: 'Nike Team #4 - Elevate the Athlete' , projects: [], taskCount: 0}
  56909588915212: { id: "56909588915212", name: 'Nike Team #5 - Command Center'      , projects: [], taskCount: 0}
}

# Hardcoded for Nike, but will be able to pull from asana in the future
teamIds = [
  56815685307709
  56815679044828
  56815679044829
  56815679044830
  56909588915212
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
  , 15000

heartbeat = (res) ->
  console.log("heartbeat")
  # 1. Get the teams
  teamIds = teamIds # hardcoded for now
  ret = JSON.parse(JSON.stringify(teams)) # hardcoded for now, clone it!

  # TODO: refactor the steps into chained promises using Q

  # 2. Get the projects
  # We are getting all the projects for the workspace instead of per team
  # Because this saves us 1 api call per team
  workspaceId = workspaceId
  projects = []

  projectsCallback = (response) ->
    projs = response.data
    count = 0
    # Get the full project objects to get the color of the project
    for proj in projs
      do (proj) ->
        id = proj.id
        client.projects.findById(id).then (response) ->
          projects.push(response)
          count++
          # Only return once all the async calls have completed
          if count == projs.length
            findTasks(projects)

  # 2. Get the tasks for each project
  findTasks = (projects) ->
    count = 0
    for proj in projects
      do (proj) ->
        id = proj.id
        client.tasks.findByProject(id, {completed_since: "now"}).then (collection) ->
          proj["tasks"] = collection.data
          proj["taskCount"] = collection.data.length
          count++
          # Only return once all the async calls have completed
          if count == projects.length
            assignProjectsToTeams(projects)

  # 3. Hook the projects up to their respective teams
  assignProjectsToTeams = (projects) ->
    for proj in projects
      # WHY IS THIS CAUSING A BUG?
      if ret[proj.team.id]
        ret[proj.team.id].projects.push(proj)
        ret[proj.team.id].taskCount += proj["taskCount"]
    getTaggedTasks(projects)

  # 4. Grab the count of tasks marked with "wow"
  # 5. Grab the count of tasks marked with "dead"
  getTaggedTasks = (projects) ->
    count = 0
    wowTasks = null
    deadTasks = null

    client.tasks.findByTag(wowTagId).then (response) ->
      wowTasks = response.data
      count++
      if count == 2
        buildEmitResponse(projects, wowTasks, deadTasks)

    client.tasks.findByTag(deadTagId).then (response) ->
      deadTasks = response.data
      count++
      if count == 2
        buildEmitResponse(projects, wowTasks, deadTasks)


  buildEmitResponse = (projects, wowTasks, deadTasks) ->
    keys = Object.keys(ret)
    vals = keys.map (v) -> ret[v]

    cur = {
      teams: vals
      wowTasks: wowTasks
      deadTasks: deadTasks
    }

    heartbeats[0] = cur

    emitAllClients "heartbeat", cur
    if res
      res.send(cur)


  client.projects.findByWorkspace(workspaceId).then projectsCallback


setupHeartbeatEmitter()

app.use express.static(__dirname + "/public")

app.get "/heartbeat", (req, res) ->
  heartbeat(res)

server.listen process.env.PORT, ->
  console.log "Listening at port " + process.env.PORT

io.sockets.on "connection", handleSocketConnection
