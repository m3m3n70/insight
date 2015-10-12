express = require("express")
app = express()
server = require("http").Server(app)
io = require("socket.io")(server)


asana = require("asana")
# TODO: make these env variables
apiKey = "gbNGGU78.LoEgfkUIdCHOOxCQoI8Mm3R" # "gFjQNCw.qpqlr3z4wwsFMBYCm5FPvjkH"
projectId = 52963906013475
workspaceId = 20868448192120 # fact0ry organization workspace


# Hardcoded for Nike, but will be able to pull from asana in the future
teams = {
  56815685307709: { id: "56815685307709", name: 'Nike Team #2 - Do More, Do Better'  , projects: [], taskCount: 0}
  56815679044828: { id: "56815679044828", name: 'Nike Team #1 - Invite & Join'       , projects: [], taskCount: 0}
  56815679044829: { id: "56815679044829", name: 'Nike Team #3 - Inside Access'       , projects: [], taskCount: 0}
  56815679044830: { id: "56815679044830", name: 'Nike Team #4 - Elevate the Athlete' , projects: [], taskCount: 0}
  56909588915212: { id: "56909588915212", name: 'Nike Team # 5 - Command Center'     , projects: [], taskCount: 0}
}

# Hardcoded for Nike, but will be able to pull from asana in the future

teamIds = [
  56815685307709
  56815679044828
  56815679044829
  56815679044830
  56909588915212
]


# workspaceId = 52963906013474 # Keenahn's personal workspace
client = asana.Client.create().useBasicAuth(apiKey)
taskCollection = []
allClients = []
tasks = {}
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

setupAsanaListener = (socket) ->
  return true if asanaListening
  client.projects.findByWorkspace(workspaceId).then (response) ->
    i = 0
    while i < response.data.length
      _proj = response.data[i]
      i++
      ((proj) ->
        readable = client.events.stream(proj.id, periodSeconds: 5)
        readable.on "data", (item) ->
          if item["type"] == "task" and item["resource"]["name"].length > 0
            if tasks[item["resource"]["id"]]
              # Task exists already, so this was an update and not an add
              emitAllClients "task-updated", item["resource"]
            else
              emitAllClients "task-added", {project: proj, task: item["resource"]}
              # console.log item
            tasks[item["resource"]["id"]] = item["resource"]["name"]
      )(_proj)

  asanaListening = true

loadInitialTasks = (socket) ->
  client.tasks.findByProject(projectId, {completed_since: "now", limit: 50}).then (collection) ->
    taskCollection = collection.data
    socket.emit "initial-tasks-loaded", taskCollection

handleSocketConnection = (socket) ->
  _socket = socket
  allClients.push _socket
  console.log allClients.length + " users connected"
  # loadInitialTasks _socket
  # setupAsanaListener _socket
  setupHeartbeatEmitter(_socket)
  socket.on "disconnect", ->
    console.log "Got disconnect!"
    i = allClients.indexOf(socket)
    allClients.remove(i)
    console.log allClients.length + " users connected"

app.use express.static(__dirname + "/public")

app.get "/projects", (req, res) ->
  client.projects.findByWorkspace(workspaceId).then (response) ->
    res.send(response.data)

app.get "/tasks/:projectId", (req, res) ->
  client.tasks.findByProject(projectId, {completed_since: "now", limit: 50}).then (collection) ->
    res.send(collection.data)



app.get "/heartbeat", (req, res) ->
  heartbeat(res)

setupHeartbeatEmitter = (socket) ->
  setInterval ->
    heartbeat(null, socket)
  , 10000

heartbeat = (res, socket) ->
  console.log("heartbeat")
  # 1. Get the teams
  teamIds = teamIds # hardcoded for now
  ret = JSON.parse(JSON.stringify(teams)) # hardcoded for now, clone it!

  # 2. Get the projects
  # We are getting all the projects for the workspace instead of per team
  # Because this saves us 1 api call per team
  workspaceId = workspaceId
  projects = []

  # TODO: refactor using promises with Q
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
            buildEmitResponse(projects)

  # 3. Hook the projects up to their respective teams
  buildEmitResponse = (projects) ->
    for proj in projects
      # WHY IS THIS CAUSING A BUG?
      if ret[proj.team.id]
        ret[proj.team.id].projects.push(proj)
        ret[proj.team.id].taskCollection += proj["taskCount"]

    keys = Object.keys(ret)
    vals = keys.map (v) -> ret[v]

    if socket
      socket.emit "heartbeat", vals
    if res
      res.send(vals)


  # 4. Grab the count of tasks marked with "wow"
  # 5. Grab the count of tasks marked with "dead"


  client.projects.findByWorkspace(workspaceId).then projectsCallback



app.get "/projects-with-tasks", (req, res) ->
  client.projects.findByWorkspace(workspaceId).then (response) ->
    ret = {};

    i = 0
    while i < response.data.length
      proj = response.data[i]
      ret[proj.id] = proj
      i++

    count = 0

    for proj in response.data
      do (proj) ->
        id = proj.id
        client.tasks.findByProject(id, {completed_since: "now", limit: 50}).then(
          (collection) ->
            ret[id]["tasks"] = collection.data
            count++
            # Only return once all the async calls have completed
            if count == Object.keys(ret).length
              keys = Object.keys(ret)
              vals = keys.map (v) -> ret[v]
              res.send(vals)
        ).catch (err) ->
          console.log(err)

loadInitialTasks = (socket) ->
  client.tasks.findByProject(projectId, {completed_since: "now", limit: 50}).then (collection) ->
    taskCollection = collection.data
    socket.emit "initial-tasks-loaded", taskCollection

server.listen process.env.PORT, ->
  console.log "Listening at port " + process.env.PORT

io.sockets.on "connection", handleSocketConnection
