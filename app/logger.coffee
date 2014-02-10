generateUniqueId = (length = 8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length

epochTimeInMilliseconds = () ->
  new Date().getTime()

epochTimeInSeconds = () ->
  Math.round(new Date().getTime() / 1000)

###
  WS is a simple abstraction wrapping the browser-provided WebSocket class
###
class Socket
  constructor: (apiUrl) ->
    WS = if window['MozWebSocket'] then MozWebSocket else window['WebSocket']
    @socket = new WS(apiUrl)

  _waitForSocketConnection: (socket, callback, attemptsRemaining) ->
    attemptsRemaining--

    setTimeout ->
      if socket.readyState is 1
        callback() if callback?
        return
      else
        if attemptsRemaining > 0
          console.log "WeblogNG: websocket was not ready, #{attemptsRemaining} re-scheduling"
          @_waitForSocketConnection socket, callback, attemptsRemaining
        else
          console.log "WeblogNG: websocket was not ready and no attempts remain; giving-up"
    , 1000
    return

  send: (message) ->
    socket = @socket

    onSuccessfulConnection = ->
      socket.send(message)

    @_waitForSocketConnection(@socket, onSuccessfulConnection, 5)
    return

class Timer
  constructor: () ->

  start: () ->
    @tStart = epochTimeInMilliseconds()
    return

  finish: () ->
    @tFinish = epochTimeInMilliseconds()
    return

  getElapsedTime: () ->
    return @tFinish - @tStart

class Logger
  constructor: (@apiHost, @apiKey) ->
    @id = generateUniqueId()
    @apiUrl = "ws://#{apiHost}/log/ws"
    @webSocket = @_createWebSocket(@apiUrl)
    @timers = {}

  sendMetric: (metricName, metricValue) ->
    metricMessage = @_createMetricMessage(metricName, metricValue)
    @webSocket.send(metricMessage)

  _createWebSocket: (apiUrl) ->
    return new Socket(apiUrl)

  _createMetricMessage: (metricName, metricValue, timestamp = epochTimeInSeconds()) ->
    sanitizedMetricName = @_sanitizeMetricName(metricName)
    return "v1.metric #{@apiKey} #{sanitizedMetricName} #{metricValue} #{timestamp}"

  _sanitizeMetricName: (metricName) ->
    metricName.replace /[^\w\d_-]/g, '_'

  recordStart: (metricName) ->
    timer = new Timer()
    timer.start()
    @timers[metricName] = timer
    return timer

  recordFinish: (metricName) ->
    if @timers[metricName]
      timer = @timers[metricName]
      timer.finish()
      return timer
    else
      return null

  recordFinishAndSendMetric: (metricName) ->
    timer = @recordFinish(metricName)

    if timer
      @sendMetric(metricName, timer.getElapsedTime())
      delete @timers[metricName]

    return

  executeWithTiming: (metric_name, function_to_exec) ->
    if function_to_exec
      @recordStart(metric_name)
      try
        function_to_exec()
        @recordFinishAndSendMetric(metric_name)
      catch error
        delete @timers[metric_name]

    return

  toString: ->
    "[Logger id: #{@id}, apiHost: #{@apiHost}, apiKey: #{@apiKey} ]"
