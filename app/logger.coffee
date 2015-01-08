weblogng = this
window?.weblogng = weblogng

weblogng.generateUniqueId = (length = 8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length

# thanks, @contra!
# https://gist.github.com/contra/2477684
# Most throttles are actually just delays
# This will only call the function if it hasn't been triggered in (delay)ms
weblogng.throttle = (fn, delay) ->
  return fn if delay is 0
  timer = false
  return ->
    return if timer
    timer = true
    setTimeout (-> timer = false), delay unless delay is -1
    fn arguments...

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
    @buffers =
      events: []
      metrics: []

    @publishNavigationTimingMetrics = @options && @options.publishNavigationTimingMetrics ? true : false

    if @options && @options.metricNamePrefix
      @metricNamePrefix = @options.metricNamePrefix
    else
      @metricNamePrefix = ""

    if @publishNavigationTimingMetrics and hasNavigationTimingAPI()
      @_initNavigationTimingPublishProcess()

    _sendToAPI = =>
      @_sendToAPI()

    @_throttledSendToAPI = weblogng.throttle(_sendToAPI, 5000)


  makeEvent: (name, timestamp = epochTimeInMilliseconds()) ->
    return {
    "name": @metricNamePrefix + name
      , "scope": "application"
      , "timestamp": timestamp
    }

  makeMetric: (name, value, timestamp = epochTimeInMilliseconds()) ->
    return {
    "name": @metricNamePrefix + name
      , "value": value
      , "unit": "ms"
      , "timestamp": timestamp
    }

  _sendToAPI: () ->
    events = @buffers.events
    metrics = @buffers.metrics
    @buffers.events = []
    @buffers.metrics = []

    @webSocket.send(@_createLogMessage(events, metrics))


  _triggerSendToAPI: () ->
    @_throttledSendToAPI()

  sendMetric: (metricName, metricValue, timestamp = epochTimeInMilliseconds()) ->
    @buffers.metrics.push(@makeMetric(metricName, metricValue, timestamp))
    @_triggerSendToAPI()

  _createWebSocket: (apiUrl) ->
    return new weblogng.APIConnection(apiUrl)

  _createMetricMessage: (metricName, metricValue, timestamp = epochTimeInMilliseconds()) ->
    sanitizedMetricName = @_sanitizeMetricName(metricName)
    message =
      "apiAccessKey": @apiKey,
      "context": {},
      "metrics": [
        {
          "name": sanitizedMetricName,
          "value": metricValue,
          "unit": "ms",
          "timestamp": timestamp
        }
      ]

    return message

  _createLogMessage: (events = [], metrics = []) ->
    for event in events
      event.name = @_sanitizeMetricName(event.name)

    for metric in metrics
      metric.name = @_sanitizeMetricName(metric.name)

    message =
      "apiAccessKey": @apiKey,
      "context": {},
      "events": events
      "metrics": metrics

    return message

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
      @_publishNavigationTimingData()

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

  _publishNavigationTimingData: () ->
    timingData = @_generateNavigationTimingData()
    logMessage = @_createLogMessage(timingData.events, timingData.metrics)
    @webSocket.send(logMessage)

    return

  _generateNavigationTimingData: () ->
    performance = locatePerformanceObject()
    baseMetricName = toPageName(location)
    timestamp = epochTimeInMilliseconds()

    events = []
    metrics = []

    if performance.timing.dnsLookupStart > 0 and performance.timing.dnsLookupEnd > 0
      metric = @makeMetric((baseMetricName + "-dns_lookup_time"),
        (performance.timing.dnsLookupEnd - performance.timing.dnsLookupStart),
        timestamp)
      metrics.push(metric)

    if performance.timing.connectStart > 0 and performance.timing.responseStart > 0
      metric = @makeMetric((baseMetricName + "-first_byte_time"),
        (performance.timing.responseStart - performance.timing.connectStart),
        timestamp)
      metrics.push(metric)

    if performance.timing.responseStart > 0 and performance.timing.responseEnd > 0
      metric = @makeMetric((baseMetricName + "-response_recv_time"),
        (performance.timing.responseEnd - performance.timing.responseStart),
        timestamp)
      metrics.push(metric)

    if performance.timing.loadEventStart > 0
      metric = @makeMetric((baseMetricName + "-page_load_time"),
        (performance.timing.loadEventStart - performance.timing.navigationStart),
        timestamp)
      metrics.push(metric)
      events.push(@makeEvent(baseMetricName + "-page_load"))

    data =
      metrics: metrics
      events: events

    return data

  _scheduleReadyStateCheck: () ->

    if "complete" == document.readyState
      @_publishNavigationTimingData()
    else
      setTimeout(@_scheduleReadyStateCheck, 1000)

    return

  toString: ->
    "[Logger id: #{@id}, apiHost: #{@apiHost}, apiKey: #{@apiKey} ]"
