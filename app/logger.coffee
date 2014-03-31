weblogng = this
window?.weblogng = weblogng

weblogng.generateUniqueId = (length = 8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length

weblogng.epochTimeInMilliseconds = () ->
  new Date().getTime()

weblogng.epochTimeInSeconds = () ->
  Math.round(new Date().getTime() / 1000)

weblogng.locatePerformanceObject = () ->
  return window.performance || window.mozPerformance || window.msPerformance || window.webkitPerformance

weblogng.hasNavigationTimingAPI = () ->
  if locatePerformanceObject()?.timing
    return true
  else
    return false

weblogng.patterns = {
  MATCH_LEADING_AND_TRAILING_SLASHES: /^\/+|\/+$/g
  , MATCH_SLASHES: /\/+/g
}

weblogng.toPageName = (location) ->
  if location and location.pathname
    pageName = location.pathname
      .replace(patterns.MATCH_LEADING_AND_TRAILING_SLASHES, '')
      .replace(patterns.MATCH_SLASHES, '-')
    if "" == pageName
      return "root"
    else
      return pageName
  else
    return "unknown-page"

###
  WS is a simple abstraction wrapping the browser-provided WebSocket class
###
class weblogng.Socket
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

class weblogng.Timer
  constructor: () ->

  start: () ->
    @tStart = epochTimeInMilliseconds()
    return

  finish: () ->
    @tFinish = epochTimeInMilliseconds()
    return

  getElapsedTime: () ->
    return @tFinish - @tStart

class weblogng.Logger
  constructor: (@apiHost, @apiKey, @options = {
    publishNavigationTimingMetrics: true
    , metricNamePrefix: ""
  }) ->
    @id = generateUniqueId()
    @apiUrl = "ws://#{apiHost}/log/ws"
    @webSocket = @_createWebSocket(@apiUrl)
    @timers = {}

    @publishNavigationTimingMetrics = @options && @options.publishNavigationTimingMetrics ? true : false

    if @options && @options.metricNamePrefix
      @metricNamePrefix = @options.metricNamePrefix
    else
      @metricNamePrefix = ""

    if @publishNavigationTimingMetrics and hasNavigationTimingAPI()
      @_initNavigationTimingPublishProcess()


  sendMetric: (metricName, metricValue) ->
    metricMessage = @_createMetricMessage(@metricNamePrefix + metricName, metricValue)
    @webSocket.send(metricMessage)

  _createWebSocket: (apiUrl) ->
    return new weblogng.Socket(apiUrl)

  _createMetricMessage: (metricName, metricValue, timestamp = epochTimeInSeconds()) ->
    sanitizedMetricName = @_sanitizeMetricName(metricName)
    return "v1.metric #{@apiKey} #{sanitizedMetricName} #{metricValue} #{timestamp}"

  _sanitizeMetricName: (metricName) ->
    metricName.replace /[^\w\d_-]/g, '_'

  recordStart: (metricName) ->
    timer = new weblogng.Timer()
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
      timer = new weblogng.Timer()
      timer.start()
      try
        function_to_exec()
        timer.finish()
        @sendMetric(metric_name, timer.getElapsedTime())
      catch error

    return

  _initNavigationTimingPublishProcess: () ->

    if not hasNavigationTimingAPI()
      return

    onReadyStateComplete = =>
      @_publishNavigationTimingMetrics()

    @_waitForReadyStateComplete(onReadyStateComplete, 10)

    return

  _waitForReadyStateComplete: (callback, attemptsRemaining) ->
    attemptsRemaining--

    setTimeout ->
      if "complete" == document.readyState
        callback() if callback?
        return
      else
        if attemptsRemaining > 0
          console.log "WeblogNG: readyState was not complete, #{attemptsRemaining} re-scheduling"
          @_waitForReadyStateComplete callback, attemptsRemaining
        else
          console.log "WeblogNG: readyState is not complete and no attempts remain; giving-up"
    , 1000
    return

  _publishNavigationTimingMetrics: () ->
    performance = locatePerformanceObject()
    pageLoadTime = (performance.timing.loadEventStart - performance.timing.navigationStart)
    @sendMetric(toPageName(location) + "-page_load_time", pageLoadTime)

    return

  _scheduleReadyStateCheck: () ->

    if "complete" == document.readyState
      @_publishNavigationTimingMetrics()
    else
      setTimeout(@_scheduleReadyStateCheck, 1000)

    return

  toString: ->
    "[Logger id: #{@id}, apiHost: #{@apiHost}, apiKey: #{@apiKey} ]"
