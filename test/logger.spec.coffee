define ["logger"], (logger) ->

  ###
    Create a mock WebSocket implementation to avoid browser-dependencies.
  ###
  class MockWS
    @messages = []

    constructor: (@url) ->

    send: (message) ->
      @messages.push message

  ####
  #  replace _createWebSocket method on Logger prototype so that we use a mock WebSocket impl
  #  instead of the real impl.
  ####
  Logger::_createWebSocket = (apiUrl) ->
    return new MockWS(apiUrl)

  describe "Verify main classes in WeblogNG client library exist", ->
    it "Logger should be defined", ->
      console.log "Logger: " + Logger
      expect(Logger).toBeDefined()
      return

    it "Timer should be defined", ->
      console.log "Timer: " + Timer
      expect(Timer).toBeDefined()

    it "Socket should be defined", ->
      console.log "Socket: " + Socket
      expect(Socket).toBeDefined()

  describe 'Logger', ->
    apiHost = "localhost:9000"
    apiKey = "abcd-1234"
    logger = null

    beforeEach () ->
      logger = new Logger(apiHost, apiKey)

    it 'Logger be defined',  ->
      expect(Logger).toBeDefined()

    it 'should set properties', ->
      logger = new Logger(apiHost, apiKey)

      expect(logger.id).toBeDefined()
      expect(logger.apiHost).toBe(apiHost)
      expect(logger.apiKey).toBe(apiKey)

    it 'should print property data in toString', ->
      s = logger.toString()

      expect(s).toContain(logger.id)
      expect(s).toContain(logger.apiHost)
      expect(s).toContain(logger.apiKey)

    it 'should build WebSocket urls', ->
      expect(logger.apiUrl).toBe("ws://#{apiHost}/log/ws")

    it 'should send metrics via the websocket', ->
      spyOn(logger.webSocket, 'send')
      spyOn(logger, '_createMetricMessage')

      logger.sendMetric('metric_name', 34)

      expect(logger._createMetricMessage).toHaveBeenCalled()
      expect(logger.webSocket.send).toHaveBeenCalled()

    it 'should create a metric message using provided name and value, defaulting to current epoch time', ->
      metricName = "metric_name_" + Math.floor(Math.random() * 1000)
      metricValue = Math.random()
      timestamp = epochTimeInSeconds()

      message = logger._createMetricMessage(metricName, metricValue)

      truncatedTimestamp = Math.floor(timestamp / 10)
      expect(message).toContain("v1.metric #{apiKey} #{metricName} #{metricValue} #{truncatedTimestamp}")

    it 'should create a metric message using provided name and value time, when provided', ->
      metricName = "metric_name"
      metricValue = 42
      timestamp = 1362714242

      message = logger._createMetricMessage(metricName, metricValue, timestamp)

      expect(message).toBe("v1.metric #{apiKey} #{metricName} #{metricValue} #{timestamp}")

    it 'should sanitize metric names', ->
      forbiddenChars = ['.', '!', ',', ';', ':', '?', '/', '\\', '@', '#', '$', '%', '^', '&', '*', '(', ')']
      for forbiddenChar in forbiddenChars
        expect(logger._sanitizeMetricName("metric-name_1#{forbiddenChar}2")).toBe("metric-name_1_2")

    it 'should sanitize metric names when sending a metric', ->
      spyOn(logger, '_sanitizeMetricName')

      logger._createMetricMessage("metric name", 42)

      expect(logger._sanitizeMetricName).toHaveBeenCalled()

    it 'should record the current time when recordStart is called for a given metric name', ->
      metricName = 'save'

      timer = logger.recordStart(metricName)

      expect(timer).toBe(logger.timers[metricName])
      now = epochTimeInMilliseconds()
      expect(timer.tStart - now).toBeLessThan(2)

    it 'should record the current time when recordFinish is called for a given metric name', ->
      metricName = 'save'

      logger.recordStart(metricName)
      timer = logger.recordFinish(metricName)

      now = epochTimeInMilliseconds()
      expect(timer.tFinish - now).toBeLessThan(2)

    it 'should call recordFinish and send metric when recordFinishAndSendMetric is called', ->
      metric_name = 'some-important-operation'
      timer = logger.recordStart(metric_name)

      spyOn(logger, 'sendMetric')

      logger.recordFinishAndSendMetric(metric_name)

      expect(logger.sendMetric).toHaveBeenCalledWith(metric_name, timer.getElapsedTime())
      expect(logger.timers[metric_name]).toBeUndefined()

    it '#time should execute provided method with timing instrumentation', ->
      executed = false
      my_awesome_function = ->
        executed = true
        return

      metric_name = "some_operation"
      spyOn(logger, 'sendMetric')
      spyOn(logger, 'recordStart')
      spyOn(logger, 'recordFinishAndSendMetric')

      logger.executeWithTiming(metric_name, my_awesome_function)

      expect(executed).toBeTruthy()
      expect(logger.sendMetric).toHaveBeenCalledWith(metric_name, 0)
      expect(logger.recordStart).not.toHaveBeenCalled()
      expect(logger.recordFinishAndSendMetric).not.toHaveBeenCalled()

    it '#time should not leak memory when provided method throws exception', ->
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
      expect(logger.recordStart).not.toHaveBeenCalled()
      expect(logger.recordFinishAndSendMetric).not.toHaveBeenCalled()

  describe 'Socket', ->
    it 'Socket be defined', ->
      expect(Socket).toBeDefined()

  describe 'Timer', ->
    timer = null

    beforeEach () ->
      timer = new Timer

    it 'should default members to undefined', ->
      timer = new Timer
      expect(timer.tStart).toBeUndefined()
      expect(timer.tFinish).toBeUndefined()

    it 'should record current time when start is called', ->
      timer.start()

      expect(timer.tStart).toBe(epochTimeInMilliseconds())
      expect(timer.tFinish).toBeUndefined()

    it 'should record current time when finish is called', ->
      timer.finish()

      expect(timer.tStart).toBeUndefined()
      expect(timer.tFinish).toBe(epochTimeInMilliseconds())

    it 'should compute elapsed time based on start and finish times', ->
      timer.tStart = 42
      timer.tFinish = 100

      expect(timer.getElapsedTime()).toBe(58)

  describe 'epochTimeInSeconds', ->
    it 'epochTimeInSeconds be defined', ->
      expect(epochTimeInSeconds).toBeDefined()

    it 'should compute current epoch time, in seconds', ->
      expect((epochTimeInSeconds() * 1000) - new Date().getTime()).toBeLessThan(1001)

    it 'should be fast', ->
      t_start = new Date().getTime()
      num = 1000
      while num -= 1
        timeInSeconds = epochTimeInSeconds()
        expect(timeInSeconds).toBeDefined()

      t_elapsed = new Date().getTime() - t_start
      expect(t_elapsed).toBeLessThan(1000)

