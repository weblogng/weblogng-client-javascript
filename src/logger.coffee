weblog = this
window?.weblog = weblog

weblog.generateUniqueId = (length = 8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length

weblog.epochTimeInMilliseconds = () ->
  new Date().getTime()

weblog.epochTimeInSeconds = () ->
  Math.round(new Date().getTime() / 1000)

###
  WS is a simple abstraction wrapping the browser-provided WebSocket class
###
class weblog.Socket
  constructor: (apiUrl) ->
    WS = if window['MozWebSocket'] then MozWebSocket else window['WebSocket']
    @socket = new WS(apiUrl)

  send: (message) ->
    @socket.send(message)

class weblog.Timer
  constructor: () ->

  start: () ->
    @tStart = weblog.epochTimeInMilliseconds()
    return

  finish: () ->
    @tFinish = weblog.epochTimeInMilliseconds()
    return

  getElapsedTime: () ->
    return @tFinish - @tStart

class weblog.Logger
  constructor: (@apiHost, @apiKey) ->
    @id = weblog.generateUniqueId()
    @apiUrl = "ws://#{apiHost}/log/ws"
    @webSocket = @_createWebSocket(@apiUrl)
    @timers = {}

  sendMetric: (metricName, metricValue) ->
    metricMessage = @_createMetricMessage(metricName, metricValue)
    @webSocket.send(metricMessage)

  _createWebSocket: (apiUrl) ->
    return new weblog.Socket(@apiUrl)

  _createMetricMessage: (metricName, metricValue, timestamp = weblog.epochTimeInSeconds()) ->
    sanitizedMetricName = @_sanitizeMetricName(metricName)
    return "v1.metric #{@apiKey} #{sanitizedMetricName} #{metricValue} #{timestamp}"

  _sanitizeMetricName: (metricName) ->
    metricName.replace /[^\w\d_-]/g, '_'

  recordStart: (metricName) ->
    timer = new weblog.Timer()
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
