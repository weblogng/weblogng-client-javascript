global.window = require("jsdom").jsdom().createWindow()

weblog = require('../src/logger')
Socket = weblog.Socket
Timer = weblog.Timer
Logger = weblog.Logger


###
  Create a mock WebSocket implementation to avoid browser-dependencies.
###
class MockWS
  @messages = []

  constructor: (@url) ->

  send: (message) ->
    @messages.push message

###
  replace _createWebSocket method on Logger prototype so that we use a mock WebSocket impl
  instead of the real impl.
###
Logger::_createWebSocket = (apiUrl) ->
  return new MockWS(apiUrl)

describe 'Logger', ->
  apiHost = "localhost:9000"
  apiKey = "abcd-1234"
  logger = null

  beforeEach () ->
    logger = new Logger(apiHost, apiKey)

  it 'Logger be defined', (done) ->
    expect(weblog.Logger).toBeDefined()

    done()

  it 'should set properties', (done) ->
    logger = new weblog.Logger(apiHost, apiKey)

    expect(logger.id).toBeDefined()
    expect(logger.apiHost).toBe(apiHost)
    expect(logger.apiKey).toBe(apiKey)

    done()

  it 'should print property data in toString', (done) ->
    s = logger.toString()

    expect(s).toContain(logger.id)
    expect(s).toContain(logger.apiHost)
    expect(s).toContain(logger.apiKey)

    done()

  it 'should build WebSocket urls', (done) ->
    expect(logger.apiUrl).toBe("ws://#{apiHost}/log/ws")

    done()

  it 'should send metrics via the websocket', (done) ->
    spyOn(logger.webSocket, 'send')
    spyOn(logger, '_createMetricMessage')

    logger.sendMetric('metric_name', 34)

    expect(logger._createMetricMessage).toHaveBeenCalled()
    expect(logger.webSocket.send).toHaveBeenCalled()

    done()

  it 'should create a metric message using provided name and value, defaulting to current epoch time', (done) ->
    metricName = "metric_name_" + Math.floor(Math.random() * 1000)
    metricValue = Math.random()
    timestamp = weblog.epochTimeInSeconds()

    message = logger._createMetricMessage(metricName, metricValue)

    truncatedTimestamp = Math.floor(timestamp / 10)
    expect(message).toContain("v1.metric #{apiKey} #{metricName} #{metricValue} #{truncatedTimestamp}")

    done()

  it 'should create a metric message using provided name and value time, when provided', (done) ->
    metricName = "metric_name"
    metricValue = 42
    timestamp = 1362714242

    message = logger._createMetricMessage(metricName, metricValue, timestamp)

    expect(message).toBe("v1.metric #{apiKey} #{metricName} #{metricValue} #{timestamp}")

    done()

  it 'should sanitize metric names', (done) ->
    forbiddenChars = ['.', '!', ',', ';', ':', '?', '/', '\\', '@', '#', '$', '%', '^', '&', '*', '(', ')']
    for forbiddenChar in forbiddenChars
      expect(logger._sanitizeMetricName("metric-name_1#{forbiddenChar}2")).toBe("metric-name_1_2")

    done()

  it 'should sanitize metric names when sending a metric', (done) ->
    spyOn(logger, '_sanitizeMetricName')

    logger._createMetricMessage("metric name", 42)

    expect(logger._sanitizeMetricName).toHaveBeenCalled()

    done()

  it 'should record the current time when recordStart is called for a given metric name', (done) ->
    metricName = 'save'

    timer = logger.recordStart(metricName)

    expect(timer).toBe(logger.timers[metricName])
    now = weblog.epochTimeInMilliseconds()
    expect(timer.tStart - now).toBeLessThan(2)
    done()

  it 'should record the current time when recordFinish is called for a given metric name', (done) ->
    metricName = 'save'

    logger.recordStart(metricName)
    timer = logger.recordFinish(metricName)

    now = weblog.epochTimeInMilliseconds()
    expect(timer.tFinish - now).toBeLessThan(2)
    done()

  it 'should call recordFinish and send metric when recordFinishAndSendMetric is called', (done) ->
    metric_name = 'some-important-operation'
    timer = logger.recordStart(metric_name)

    spyOn(logger, 'sendMetric')

    logger.recordFinishAndSendMetric(metric_name)

    expect(logger.sendMetric).toHaveBeenCalledWith(metric_name, timer.getElapsedTime())
    expect(logger.timers[metric_name]).toBeUndefined()

    done()

  it '#time should execute provided method with timing instrumentation', (done) ->
    executed = false
    my_awesome_function = ->
      executed = true
      return

    metric_name = "some_operation"
    spyOn(logger, 'recordStart')
    spyOn(logger, 'recordFinishAndSendMetric')

    logger.executeWithTiming(metric_name, my_awesome_function)

    expect(executed).toBeTruthy()
    expect(logger.recordStart).toHaveBeenCalledWith(metric_name)
    expect(logger.recordFinishAndSendMetric).toHaveBeenCalledWith(metric_name)
    done()

  it '#time should not leak memory when provided method throws exception', (done) ->
    executed = false
    my_terrible_function = ->
      executed = true
      throw new Error("my_terrible_function is terrible!")

    metric_name = "some_operation"
    spyOn(logger, 'recordStart')
    spyOn(logger, 'recordFinishAndSendMetric')

    logger.executeWithTiming(metric_name, my_terrible_function)

    expect(executed).toBeTruthy()
    expect(logger.timers[metric_name]).toBeUndefined()
    expect(logger.recordStart).toHaveBeenCalledWith(metric_name)
    expect(logger.recordFinishAndSendMetric).not.toHaveBeenCalled()
    done()

describe 'Socket', ->
  it 'Socket be defined', (done) ->
    expect(weblog.Socket).toBeDefined()

    done()

describe 'Timer', ->
  timer = null

  beforeEach () ->
    timer = new Timer

  it 'should default members to undefined', (done) ->
    timer = new Timer
    expect(timer.tStart).toBeUndefined()
    expect(timer.tFinish).toBeUndefined()
    done()

  it 'should record current time when start is called', (done) ->
    timer.start()

    expect(timer.tStart).toBe(weblog.epochTimeInMilliseconds())
    expect(timer.tFinish).toBeUndefined()

    done()

  it 'should record current time when finish is called', (done) ->
    timer.finish()

    expect(timer.tStart).toBeUndefined()
    expect(timer.tFinish).toBe(weblog.epochTimeInMilliseconds())

    done()

  it 'should compute elapsed time based on start and finish times', (done) ->
    timer.tStart = 42
    timer.tFinish = 100

    expect(timer.getElapsedTime()).toBe(58)

    done()

describe 'epochTimeInSeconds', ->
  it 'epochTimeInSeconds be defined', (done) ->
    expect(weblog.epochTimeInSeconds).toBeDefined()

    done()

  it 'should compute current epoch time, in seconds', (done) ->
    expect((weblog.epochTimeInSeconds() * 1000) - new Date().getTime()).toBeLessThan(1001)
    done()

  it 'should be fast', (done) ->
    t_start = new Date().getTime()
    num = 1000
    while num -= 1
      timeInSeconds = weblog.epochTimeInSeconds()

    t_elapsed = new Date().getTime() - t_start
    expect(t_elapsed).toBeLessThan(1000)

    done()
