express = require("express")
app = express()
server = require("http").Server(app)
io = require("socket.io")(server)


asana = require("asana")
# TODO: make these env variables
apiKey = "gFjQNCw.qpqlr3z4wwsFMBYCm5FPvjkH"
projectId = 52963906013475
workspaceId = 52963906013474
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
  setupAsanaListener _socket
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
