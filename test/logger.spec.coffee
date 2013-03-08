global.window = require("jsdom").jsdom().createWindow()

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
    metricName = "metric_name_" + Math.random()
    metricValue = Math.random()
    timestamp = epochTimeInSeconds()

    message = logger._createMetricMessage(metricName, metricValue)

    truncatedTimestamp = Math.floor(timestamp / 10)
    expect(message).toContain("#{apiKey} #{metricName} #{metricValue} #{truncatedTimestamp}")

    done()

  it 'should create a metric message using provided name and value time, when provided', (done) ->
    metricName = "metric_name"
    metricValue = 42
    timestamp = 1362714242

    message = logger._createMetricMessage(metricName, metricValue, timestamp)

    expect(message).toBe("#{apiKey} #{metricName} #{metricValue} #{timestamp}")

    done()

describe 'epochTimeInSeconds', ->

  it 'should compute current epoch time, in seconds', (done) ->
    expect((epochTimeInSeconds() * 1000) - new Date().getTime()).toBeLessThan(1001)
    done()
