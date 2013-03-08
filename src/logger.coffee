weblog = this
window?.weblog = weblog

weblog.generateUniqueId = (length=8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length

weblog.epochTimeInSeconds = () ->
  Math.round(new Date().getTime() / 1000)

###
  WS is a simple abstraction wrapping the browser-provided WebSocket class
###
class weblog.WebSocket
  send: (message) ->


class weblog.Logger
  constructor: (@apiHost, @apiKey) ->
    @id = weblog.generateUniqueId()
    @apiUrl = "ws://#{apiHost}/log/ws"
    @webSocket = new weblog.WebSocket(@apiUrl)

  sendMetric: (metricName, metricValue) ->
    metricMessage = @_createMetricMessage(metricName, metricValue)
    @webSocket.send(metricMessage)

  _createMetricMessage: (metricName, metricValue, timestamp=weblog.epochTimeInSeconds()) ->
    return "#{@apiKey} #{metricName} #{metricValue} #{timestamp}"

  toString: ->
    "[Logger id: #{@id}, apiHost: #{@apiHost}, apiKey: #{@apiKey} ]"
