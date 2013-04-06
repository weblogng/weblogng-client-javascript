global.window = require("jsdom").jsdom().createWindow()

#weblog = require('../src/logger')
Timer = require('../src/logger').Timer
Logger = require('../src/logger').Logger
epochTimeInSeconds = require('../src/logger').epochTimeInSeconds

describe 'Logger', ->

  apiHost = "localhost:9000"
  apiKey = "abcd-1234"
  logger = null

  beforeEach ->
    logger = new Logger(apiHost, apiKey)

  it 'should set properties', (done) ->
    logger = new Logger(apiHost, apiKey)

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
    timestamp = epochTimeInSeconds()

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

  it 'should record the current time when startTiming is called for a given metric name', (done) ->
    metricName = 'save'
#    logger.recordStart(metricName)
#
#    expect(logger.timers[metricName]).toBeCloseTo(new Date().getTime(), 3)

    done()

describe 'epochTimeInSeconds', ->

  it 'should compute current epoch time, in seconds', (done) ->
    expect((epochTimeInSeconds() * 1000) - new Date().getTime()).toBeLessThan(1001)
    done()
