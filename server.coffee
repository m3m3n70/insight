express = require("express")
app = express()
server = require("http").Server(app)
io = require("socket.io")(server)


asana = require("asana")
# TODO: make these env variables
apiKey = "gFjQNCw.qpqlr3z4wwsFMBYCm5FPvjkH"
projectId = 52963906013475
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
  readable = client.events.stream(projectId, periodSeconds: 3)
  readable.on "data", (item) ->
    # console.log(item);
    if item["type"] == "task" and item["resource"]["name"].length > 0
      # console.log(Math.floor(Date.now() / 1000))
      if tasks[item["resource"]["id"]]
        # Task exists already, so this was an update and not an add
        emitAllClients "task-updated", item["resource"]
      else
        emitAllClients "task-added", item["resource"]
      tasks[item["resource"]["id"]] = item["resource"]["name"]
  asanaListening = true

loadInitialTasks = (socket) ->
  client.tasks.findByProject(projectId, {completed_since: "now", limit: 50}).then (collection) ->
    taskCollection = collection.data
    socket.emit "initial-tasks-loaded", taskCollection

handleSocketConnection = (socket) ->
  _socket = socket
  allClients.push _socket
  console.log allClients.length + " users connected"
  loadInitialTasks _socket
  setupAsanaListener _socket
  socket.on "disconnect", ->
    console.log "Got disconnect!"
    i = allClients.indexOf(socket)
    allClients.remove(i)
    console.log allClients.length + " users connected"

app.use express.static(__dirname + "/public")

server.listen process.env.PORT, ->
  console.log "Listening at port " + process.env.PORT

io.sockets.on "connection", handleSocketConnection
