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
class weblogng.APIConnection
  constructor: (apiUrl) ->
    @apiUrl = apiUrl

  send: (logMessage) ->
    xhr = new XMLHttpRequest()
    xhr.open("POST", @apiUrl, true)
    xhr.setRequestHeader("Content-Type", "application/json")
    xhr.setRequestHeader("Accept", "application/json, text/javascript, */*; q=0.01")
    xhr.send(JSON.stringify(logMessage))

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
    @apiUrl = "https://#{apiHost}/v2/log"
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
    return new weblogng.APIConnection(apiUrl)

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

    setTimeout =>
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
    for name, value of @_generateNavigationTimingMetrics()
      @sendMetric("#{name}", value)

    return

  _generateNavigationTimingMetrics: () ->
    performance = locatePerformanceObject()
    baseMetricName = toPageName(location)

    metrics = {}

    if performance.timing.dnsLookupStart > 0 and performance.timing.dnsLookupEnd > 0
      metrics[(baseMetricName + "-dns_lookup_time")] = (performance.timing.dnsLookupEnd - performance.timing.dnsLookupStart)

    if performance.timing.connectStart > 0 and performance.timing.responseStart > 0
      metrics[(baseMetricName + "-first_byte_time")] = (performance.timing.responseStart - performance.timing.connectStart)

    if performance.timing.responseStart > 0 and performance.timing.responseEnd > 0
      metrics[(baseMetricName + "-response_recv_time")] = (performance.timing.responseEnd - performance.timing.responseStart)

    if performance.timing.loadEventStart > 0
      metrics[(baseMetricName + "-page_load_time")] = (performance.timing.loadEventStart - performance.timing.navigationStart)

    return metrics

  _scheduleReadyStateCheck: () ->

    if "complete" == document.readyState
      @_publishNavigationTimingMetrics()
    else
      setTimeout(@_scheduleReadyStateCheck, 1000)

    return

  toString: ->
    "[Logger id: #{@id}, apiHost: #{@apiHost}, apiKey: #{@apiKey} ]"
