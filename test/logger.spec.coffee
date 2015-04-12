randInt = (max = 10)->
  Math.floor((Math.random() * max) + 1)

define ['logger'], (logger) ->

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
  Logger::_createAPIConnection = (apiUrl) ->
    return new MockWS(apiUrl)

  makeRandomString = (base, index = 10) ->
    randModValue = randInt(5)
    if (index % randModValue == 0)
      return undefined
    else
      return "#{base}_#{index}-#{generateUniqueId()}"

  makeMetric = () ->
    metric = {}
    metric.name = "metric_name_" + randInt(25)
    metric.value = Math.random() * 100
    metric.unit = "ms"
    metric.timestamp = epochTimeInMilliseconds()
    metric.scope = makeRandomString("scope")
    metric.category = makeRandomString("category")

    return metric

  makeMetrics = (numMetrics) ->
    (makeMetric() for num in [1..numMetrics])

  makeEvent = () ->
    event = {}
    event.name = "event_name_" + randInt(25)
    event.scope = "application"
    event.timestamp = epochTimeInMilliseconds()

    return event

  makeEvents = (numEvents) ->
    (makeEvent() for num in [1..numEvents])

  makeMessage = (num) ->
    message = {}
    message.level = "info"
    message.scope = "application"
    message.value = "message_" + num
    message.timestamp = epochTimeInMilliseconds()

    return message

  makeMessages = (numMessages) ->
    (makeMessage(num) for num in [1..numMessages])

  describe "Verify utility functions in WeblogNG client library exist", ->
    it "generateUniqueId should be defined", ->
      expect(generateUniqueId).toBeDefined()

    it "epochTimeInMilliseconds should be defined", ->
      expect(epochTimeInMilliseconds).toBeDefined()

    it "locatePerformanceObject should be defined", ->
      expect(locatePerformanceObject).toBeDefined()

    it "hasNavigationTimingAPI should be defined", ->
      expect(hasNavigationTimingAPI).toBeDefined()

    it "addListener should be defined", ->
      expect(addListener).toBeDefined()

  describe "Verify main classes in WeblogNG client library exist", ->
    it "Logger should be defined", ->
      expect(Logger).toBeDefined()
      return

    it "Timer should be defined", ->
      expect(Timer).toBeDefined()

    it "APIConnection should be defined", ->
      expect(APIConnection).toBeDefined()

  describe "weblogng.addListener", ->

    it 'should ignore bad inputs', ->
      window =
        addEventListener: jasmine.createSpy()
      eventName = "event-#{generateUniqueId()}"
      listener = () ->

      addListener(undefined, undefined, undefined)
      addListener(undefined, eventName, listener)
      addListener(window, undefined, listener)
      addListener(window, eventName, undefined)

      expect(window.addEventListener).not.toHaveBeenCalled()

    it 'should add listener to the window, preferring addEventListener', ->
      # make the window with both common listener attachment methods so
      # preference for addEventListener can be verified
      window =
        addEventListener: jasmine.createSpy()
        attachEvent: jasmine.createSpy()

      eventName = "event-#{generateUniqueId()}"
      listener = () ->

      expect(window.addEventListener).toBeDefined()

      addListener(window, eventName, listener)

      expect(window.addEventListener).toHaveBeenCalledWith(eventName, listener, true)
      expect(window.attachEvent).not.toHaveBeenCalled()

    it 'should add listener to the window via attachEvent, when addEventListener is undefined', ->
      eventName = "event-#{generateUniqueId()}"
      listener = () ->

      window =
        attachEvent: jasmine.createSpy()

      addListener(window, eventName, listener)

      expect(window.attachEvent).toHaveBeenCalledWith(eventName, listener, true)

  describe 'weblogng.generateUniqueId', ->

    it 'should generate unique identifiers with default length', ->
      ids = {}
      iterations = 10000

      for num in [0..iterations]
        ids[generateUniqueId()] = num

      expect(Object.keys(ids).length).toBeGreaterThan(iterations - 1)

  describe 'Category', ->

    it 'should have well-known categories supported by the dashboard builder', ->
      expect(Category.NAVIGATION_TIMING).toEqual('navigation timing')
      expect(Category.HTTP_REQUEST).toEqual('http request')

  describe 'Logger', ->
    apiHost = "localhost:9000"
    apiKey = "abcd-1234"
    logger = null
    window = null
    forbiddenMetricNameChars = ['\'', '"', '\n']

    beforeEach () ->
      logger = new Logger(apiHost, apiKey)
      window = {}

    it 'Logger be defined',  ->
      expect(Logger).toBeDefined()

    it 'should set properties via constructor', ->
      options = {}
      logger = new Logger(apiHost, apiKey, options)

      expect(logger.id).toBeDefined()
      expect(logger.apiHost).toBe(apiHost)
      expect(logger.apiKey).toBe(apiKey)
      expect(logger.options).toBe(options)

    it 'should use default values for unspecified options', ->
      logger = new Logger(apiHost, apiKey)

      expect(logger.publishNavigationTimingMetrics).toBeTruthy()
      expect(logger.publishUserActive).toBeTruthy()
      expect(logger.defaultContext.application).toBeUndefined()

    it 'should use publishNavigationTimingMetrics option when specified', ->
      logger = new Logger(apiHost, apiKey, {publishNavigationTimingMetrics: true})

      expect(logger.publishNavigationTimingMetrics).toBeTruthy()

      logger = new Logger(apiHost, apiKey, {publishNavigationTimingMetrics: false})

      expect(logger.publishNavigationTimingMetrics).toBeFalsy()

    it 'should use publishUserActive option when specified', ->
      logger = new Logger(apiHost, apiKey, {publishUserActive: true})

      expect(logger.publishUserActive).toBeTruthy()

      logger = new Logger(apiHost, apiKey, {publishUserActive: false})

      expect(logger.publishUserActive).toBeFalsy()

    it 'should retain optional application name as part of default context, when specified', ->
      application = "unit-test"
      logger = new Logger(apiHost, apiKey, {application: application})

      expect(logger.defaultContext.application).toBe(application)

    it 'should print property data in toString', ->
      s = logger.toString()

      expect(s).toContain(logger.id)
      expect(s).toContain(logger.apiHost)
      expect(s).toContain(logger.apiKey)

    it 'should build secure logging api urls', ->
      expect(logger.apiUrl).toBe("https://#{apiHost}/v2/log")

    it 'should make events using the minimal-required data', ->
      logger = new Logger(apiHost, apiKey)

      name = "event_name_" + randInt(1000)
      event = logger.makeEvent(name)

      expect(event.name).toBe(name)
      expect(event.timestamp).toBeCloseTo(epochTimeInMilliseconds(), 5)
      expect(event.scope).toBe(Scope.APPLICATION)
      expect(event.category).toBeUndefined()

    it 'should make events using the provided data', ->
      application = "application"
      logger = new Logger(apiHost, apiKey, {application: application})

      for num in [1..50]
        eventName = "event_name_#{num}_" + randInt(1000)
        timestamp = epochTimeInMilliseconds()
        scope = makeRandomString("scope", num)
        category = makeRandomString("category", num)

        event = logger.makeEvent(eventName, timestamp, scope, category)

        expect(event.name).toBe(eventName)
        expect(event.timestamp).toBe(timestamp)

        if scope
          expect(event.scope).toBe(scope)
        else
          expect(event.scope).toBe(Scope.APPLICATION)

        expect(event.category).toBe(category)

    it 'should make messages using the minimal-required data', ->
      logger = new Logger(apiHost, apiKey)

      level = "info"
      value = "message_" + randInt(1000)
      message = logger.makeMessage(level, value)

      expect(message.level).toBe(level)
      expect(message.value).toBe(value)
      expect(message.timestamp).toBeCloseTo(epochTimeInMilliseconds(), 5)
      expect(message.scope).toBe(Scope.APPLICATION)
      expect(message.category).toBeUndefined()

    it 'should make messages using the provided data', ->
      application = "application"
      logger = new Logger(apiHost, apiKey, {application: application})

      for num in [1..50]
        messageLevel = "event_name_#{num}_" + randInt(1000)
        messageValue = "event_name_#{num}_" + randInt(1000)
        timestamp = epochTimeInMilliseconds()
        scope = makeRandomString("scope", num)
        category = makeRandomString("category", num)

        message = logger.makeMessage(messageLevel, messageValue, timestamp, scope, category)

        expect(message.level).toBe(messageLevel)
        expect(message.value).toBe(messageValue)
        expect(message.timestamp).toBe(timestamp)

        if scope
          expect(message.scope).toBe(scope)
        else
          expect(message.scope).toBe(Scope.APPLICATION)

        expect(message.category).toBe(category)



    it 'should make metrics using the minimal-required data', ->
      logger = new Logger(apiHost, apiKey)

      for num in [1..10]
        name = "metric_name_" + randInt(1000)
        metric = logger.makeMetric(name, randInt(1000))

        expect(metric.name).toBe(name)
        expect(metric.timestamp / 1000).toBeCloseTo(epochTimeInMilliseconds() / 1000, 2)
        expect(metric.scope).toBe(Scope.APPLICATION)
        expect(metric.category).toBeUndefined()

    it 'should make metrics using the provided data', ->
      application = makeRandomString("application")
      logger = new Logger(apiHost, apiKey, {application: application})

      for num in [1..50]
        metricName = "metric_name_#{num}_" + randInt(1000)
        metricValue = Math.random()
        timestamp = epochTimeInMilliseconds()
        scope = makeRandomString("scope", num)
        category = makeRandomString("category", num)

        metric = logger.makeMetric(metricName, metricValue, timestamp, scope, category)

        expect(metric.name).toBe(metricName)

        if scope
          expect(metric.scope).toBe(scope)
        else
          expect(metric.scope).toBe(Scope.APPLICATION)

        expect(metric.category).toBe(category)
        expect(metric.value).toBe(metricValue)
        expect(metric.timestamp).toBe(timestamp)
        expect(metric.unit).toBe("ms")

    it 'should create a log message using provided events, messages, and metrics', ->

      for num in [1..10]
        numMetrics = randInt()
        metrics = makeMetrics(numMetrics)

        numEvents = randInt()
        events = makeEvents(numEvents)

        numMessages = randInt()
        messages = makeMessages(numMessages)

        logMessage = logger._createLogMessage(events, metrics, messages)

        expectedLogMessage =
          "apiAccessKey": apiKey,
          "context": { userAgent : navigator.userAgent},
          "events": events,
          "messages": messages,
          "metrics": metrics

        expect(events.length).toBe(numEvents)
        expect(metrics.length).toBe(numMetrics)
        expect(messages.length).toBe(numMessages)
        expect(logMessage).toEqual(expectedLogMessage)

    it 'should include default context in log message', ->
      options =
        "application" : "App Name - #{randInt()}"

      logger = new Logger(apiHost, apiKey, options)

      for num in [1..10]
        metrics = makeMetrics(randInt())
        events = makeEvents(randInt())
        messages = makeMessages(randInt())

        message = logger._createLogMessage(events, metrics, messages)

        expectedContext =
          "application": options.application
          "userAgent" : navigator.userAgent

        expect(message.context).toEqual(expectedContext)

    it 'should allow desired metric names', ->
      for metricName in [ 'GET localhost:8443',
                          'POST www.weblogng.com',
                          'PUT api.weblogng.com',
                          'GET http://host.com/some/query/path?param=1',
                          'GET https://host.com/some%20url%20encoded%20path?param=1',
                          't.co' ]
        expect(logger._sanitizeMetricName(metricName)).toBe(metricName)

    it 'should sanitize metric names of forbidden characters', ->
      forbiddenMetricNameChars = ['\'', '"', '\n']
      for forbiddenChar in forbiddenMetricNameChars
        expect(logger._sanitizeMetricName("forbidden#{forbiddenChar}char")).toBe("forbidden char")

    it 'should sanitize metric names of multiple forbidden characters', ->
      expect(logger._sanitizeMetricName("forbidden#{forbiddenMetricNameChars.toString()}char")).toBe("forbidden char")

    it 'should record the current time when recordStart is called for a given metric name', ->
      metricName = 'save'

      timer = logger.recordStart(metricName)

      expect(timer).toBe(logger.timers[metricName])
      now = epochTimeInMilliseconds()
      expect(timer.tStart - now).toBeLessThan(2)

    describe 'sendMetric', ->
      it 'should store metrics in buffer and trigger a send via the apiConnection', ->
        spyOn(logger.apiConnection, 'send')
        spyOn(logger, '_createLogMessage')
        spyOn(logger, '_triggerSendToAPI')

        metricName = 'metric_name'
        metricValue = 34
        timestamp = epochTimeInMilliseconds()

        logger.sendMetric(metricName, metricValue, timestamp)

        expect(logger._triggerSendToAPI).toHaveBeenCalled()

        expect(logger._createLogMessage).not.toHaveBeenCalled()
        expect(logger.apiConnection.send).not.toHaveBeenCalled()

        expect(logger.buffers.events).toEqual([])
        expect(logger.buffers.metrics).toEqual([logger.makeMetric(metricName, metricValue, timestamp)])

    it 'should send metrics using the provided parameters', ->
      spyOn(logger, '_triggerSendToAPI')

      for num in [1..25]
        metricName = "metric_name_#{randInt(1000)}"
        metricValue = randInt(1000)
        timestamp = epochTimeInMilliseconds()
        scope = makeRandomString("scope")
        category = makeRandomString("category")

        logger.sendMetric(metricName, metricValue, timestamp, scope, category)

        expectedMetric = logger.makeMetric(metricName, metricValue, timestamp, scope, category)
        expect(logger.buffers.metrics).toContain(expectedMetric)

        expect(logger._triggerSendToAPI).toHaveBeenCalled()

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

    it 'executeWithTiming should execute provided method with timing instrumentation', ->
      executed = false
      my_awesome_function = ->
        executed = true
        return

      metric_name = "some_operation"
      spyOn(logger, 'sendMetric').andCallThrough()
      spyOn(logger, '_triggerSendToAPI')
      spyOn(logger, 'recordStart')
      spyOn(logger, 'recordFinishAndSendMetric')

      logger.executeWithTiming(metric_name, my_awesome_function)

      expect(executed).toBeTruthy()

      expect(logger.buffers.metrics.length).toBe(1)
      expect(logger.buffers.metrics[0].name).toBe(metric_name)
      expect(logger.buffers.metrics[0].value).toBeGreaterThan(-1)
      expect(logger.buffers.metrics[0].value).toBeLessThan(3)

      expect(logger.sendMetric).toHaveBeenCalled()
      expect(logger._triggerSendToAPI).toHaveBeenCalled()
      expect(logger.recordStart).not.toHaveBeenCalled()
      expect(logger.recordFinishAndSendMetric).not.toHaveBeenCalled()

    it 'executeWithTiming should not leak memory when provided method throws exception', ->
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

  describe 'Logger event support', ->
    logger = null
    apiHost = "localhost:9000"
    apiKey = "abcd-1234"

    beforeEach () ->
      logger = new Logger(apiHost, apiKey)

    it 'should buffer an event with the provided parameters when recordEvent is called', ->
      spyOn(logger, '_triggerSendToAPI')

      for num in [1..25]
        eventName = "appEvent-#{generateUniqueId(3)}"
        timestamp = epochTimeInMilliseconds()
        scope = makeRandomString("scope")
        category = makeRandomString("category")

        logger.recordEvent(eventName, timestamp, scope, category)

        expectedEvent = logger.makeEvent(eventName, timestamp, scope, category)
        expect(logger.buffers.events).toContain(expectedEvent)

        expect(logger._triggerSendToAPI).toHaveBeenCalled()



  describe 'Logger message support', ->
    logger = null
    apiHost = "localhost:9000"
    apiKey = "abcd-1234"

    beforeEach () ->
      logger = new Logger(apiHost, apiKey)

    it 'should buffer a message with the provided parameters when recordMessage is called', ->
      spyOn(logger, '_triggerSendToAPI')

      for num in [1..25]
        messageLevel = "level-#{generateUniqueId(3)}"
        messageValue = "appMessage-#{generateUniqueId(3)}"
        timestamp = epochTimeInMilliseconds()
        scope = makeRandomString("scope")
        category = makeRandomString("category")

        logger.recordMessage(messageLevel, messageValue, timestamp, scope, category)

        expectedMessage = logger.makeMessage(messageLevel, messageValue, timestamp, scope, category)
        expect(logger.buffers.messages).toContain(expectedMessage)

        expect(logger._triggerSendToAPI).toHaveBeenCalled()


  describe 'Logger Navigation Timing API support', ->
    logger = null
    timing = null
    apiHost = "localhost:9000"
    apiKey = "abcd-1234"

    beforeEach () ->
      logger = new Logger(apiHost, apiKey)
      window.performance = window.mozPerformance = window.msPerformance = window.webkitPerformance = undefined
      timing = {}

    it '_initNavigationTimingPublishProcess should return when Navigation Timing API is unavailable', ->
      window.performance = undefined

      expect(hasNavigationTimingAPI()).toBeFalsy()

      spyOn(weblogng, 'toPageName')
      spyOn(logger, 'sendMetric')

      logger._initNavigationTimingPublishProcess()

      expect(weblogng.toPageName).not.toHaveBeenCalled()
      expect(logger.sendMetric).not.toHaveBeenCalled()

    it '_initNavigationTimingPublishProcess should schedule a readyState check if Navigation Timing API is available', ->
      timing = {}
      window.performance = {vendor: 'standard', timing: timing}

      expect(window.performance.timing).toBe(timing)

      expect(weblogng.hasNavigationTimingAPI()).toBeTruthy()

      spyOn(logger, '_waitForReadyStateComplete')

      logger._initNavigationTimingPublishProcess()

      expect(hasNavigationTimingAPI()).toBeTruthy()

      expect(logger._waitForReadyStateComplete).toHaveBeenCalled()

    it '_publishNavigationTimingData should generate nav timing metrics and then send metrics to server', ->
      timing = {}
      window.performance = {vendor: 'standard', timing: timing}

      expect(window.performance.timing).toBe(timing)

      expect(weblogng.hasNavigationTimingAPI()).toBeTruthy()

      mockData =
        events: [
          logger.makeEvent("app-page_load")
        ]
        metrics: [
          logger.makeMetric("metricName", 42)
        ]

      spyOn(logger, '_generateNavigationTimingData').andReturn(mockData)
      spyOn(logger.apiConnection, 'send')

      logger._publishNavigationTimingData()

      expect(hasNavigationTimingAPI()).toBeTruthy()

      expect(logger._generateNavigationTimingData).toHaveBeenCalled()
      expect(logger.apiConnection.send).toHaveBeenCalledWith(logger._createLogMessage(mockData.events, mockData.metrics))

    it '_generateNavigationTimingData should generate metrics using performance object', ->
      timing =
        navigationStart: 1000
        dnsLookupStart: 1100
        dnsLookupEnd: 1250
        connectStart: 1500
        responseStart: 1750
        responseEnd: 1950
        loadEventStart: 2000

      window.performance = {vendor: 'standard', timing: timing}

      pageName = 'some'
      spyOn(weblogng, 'toPageName').andReturn(pageName);

      category = weblogng.Category.NAVIGATION_TIMING

      navTimingData = logger._generateNavigationTimingData()

      expect(weblogng.toPageName).toHaveBeenCalledWith(location)

      expect(navTimingData.events).not.toBeNull()
      expect(navTimingData.metrics).not.toBeNull()

      metrics = navTimingData.metrics

      actualTimestamp = metrics[0].timestamp

      expect(metrics[0]).toEqual(logger.makeMetric('dns_lookup_time', 150, actualTimestamp, pageName, category))
      expect(metrics[1]).toEqual(logger.makeMetric('first_byte_time', 250, actualTimestamp, pageName, category))
      expect(metrics[2]).toEqual(logger.makeMetric('response_recv_time', 200, actualTimestamp, pageName, category))
      expect(metrics[3]).toEqual(logger.makeMetric('page_load_time', 1000, actualTimestamp, pageName, category))

      events = navTimingData.events
      expect(events[0]).toEqual(logger.makeEvent('page_load', actualTimestamp, pageName, category))

    it '_generateNavigationTimingData should only generate metrics for events that have occurred', ->
      T_HAS_NOT_OCCURRED = 0
      timing =
        navigationStart: 1000
        dnsLookupStart: 1100
        dnsLookupEnd: T_HAS_NOT_OCCURRED
        connectStart: 1100
        responseStart: T_HAS_NOT_OCCURRED
        responseEnd: T_HAS_NOT_OCCURRED
        loadEventStart: T_HAS_NOT_OCCURRED

      window.performance = {vendor: 'standard', timing: timing}

      pageName = 'some'
      spyOn(weblogng, 'toPageName').andReturn(pageName);

      navTimingData = logger._generateNavigationTimingData()

      expect(weblogng.toPageName).toHaveBeenCalledWith(location)

      expect(navTimingData.events).toEqual([])
      expect(navTimingData.metrics).toEqual([])

  describe 'Logger user activity support', ->
    window = null
    logger = null
    apiHost = "localhost:9000"
    apiKey = "abcd-1234"


    beforeEach () ->
      window =
        addEventListener: jasmine.createSpy()

      logger = new Logger(apiHost, apiKey, {publishUserActive: true})

    it '_initUserActivityPublishProcess should register listeners for important events', ->
      logger._initUserActivityPublishProcess(window)

      # would like to assert that _userActivityOccurred is provided as 2nd arg, but it needs to be
      # wrapped in a Function so there is a dynamic layer of indirection
      expect(window.addEventListener).toHaveBeenCalledWith('mousemove', jasmine.any(Function), true)
      expect(window.addEventListener).toHaveBeenCalledWith('keyup', jasmine.any(Function), true)

    it '_initUserActivityPublishProcess should schedule a recurring activity check', ->
      spyOn(logger, '_scheduleRecurringUserActivityPublish')

      logger._initUserActivityPublishProcess(window)

      expect(logger._scheduleRecurringUserActivityPublish).toHaveBeenCalled()

    it '_userActivityOccurred should update timeOfLastUserActivity when user activity occurs', ->
      logger.timeOfLastUserActivity = undefined

      tBefore = epochTimeInMilliseconds()

      logger._userActivityOccurred()

      tAfter = epochTimeInMilliseconds()

      expect(logger.timeOfLastUserActivity).toBeGreaterThan(tBefore - 1)
      expect(logger.timeOfLastUserActivity).toBeLessThan(tAfter + 1)

    it '_recordRecentUserActivity should record an user_active event when timeOfLastUserActivity occurs within activity check interval', ->

      insideIntervalEnd = epochTimeInMilliseconds()
      insideIntervalStart = insideIntervalEnd - logger.userActivityCheckInterval + 50
      insideIntervalMidway = insideIntervalEnd - (logger.userActivityCheckInterval / 2)

      spyOn(logger, 'recordEvent')

      for timeOfLastUserActivity in [insideIntervalStart, insideIntervalMidway, insideIntervalEnd]
        logger.timeOfLastUserActivity = timeOfLastUserActivity

        logger._recordRecentUserActivity()

        expect(logger.recordEvent).toHaveBeenCalledWith('user_active', timeOfLastUserActivity)

    it '_recordRecentUserActivity should not record a user_active event when timeOfLastUserActivity occurs outside activity check interval', ->

      outsideIntervalStart = epochTimeInMilliseconds() - logger.userActivityCheckInterval - 1
      outsideIntervalEnd = epochTimeInMilliseconds() + 50

      spyOn(logger, 'recordEvent')

      for timeOfLastUserActivity in [outsideIntervalStart, outsideIntervalEnd]
        logger.timeOfLastUserActivity = timeOfLastUserActivity

        logger._recordRecentUserActivity()

        expect(logger.recordEvent).not.toHaveBeenCalledWith('user_active', timeOfLastUserActivity)

  describe 'Timing API helpers', ->

    timing = null

    beforeEach () ->
      window.performance = window.mozPerformance = window.msPerformance = window.webkitPerformance = undefined
      timing = {}

    it 'locatePerformanceObject should return undefined when performance object is not present', ->

      expect(locatePerformanceObject()).toBeUndefined()
      expect(hasNavigationTimingAPI()).toBeFalsy()

    it 'hasNavigationTimingAPI should return false when performance object is defined, but timing is not', ->
      # note: not sure if performance would ever be defined without timing in real-life
      performanceObject = {vendor: 'standard'}
      window.performance = performanceObject

      expect(locatePerformanceObject()).toBeDefined()
      expect(hasNavigationTimingAPI()).toBeFalsy()

    it 'locatePerformanceObject should find the performance object in its standard location', ->
      performanceObject = {vendor: 'standard', timing: timing}
      window.performance = performanceObject

      expect(locatePerformanceObject()).toBe(performanceObject)
      expect(hasNavigationTimingAPI()).toBeTruthy()

    it 'locatePerformanceObject should find the performance object in its mozilla-specific location', ->
      performanceObject = {vendor: 'mozilla', timing: timing}
      window.mozPerformance = performanceObject

      expect(window.performance).toBeUndefined()
      expect(locatePerformanceObject()).toBe(performanceObject)
      expect(hasNavigationTimingAPI()).toBeTruthy()

    it 'locatePerformanceObject should find the performance object in its microsoft-specific location', ->
      performanceObject = {vendor: 'microsoft', timing: timing}
      window.msPerformance = performanceObject

      expect(window.performance).toBeUndefined()
      expect(locatePerformanceObject()).toBe(performanceObject)
      expect(hasNavigationTimingAPI()).toBeTruthy()

    it 'locatePerformanceObject should find the performance object in its webkit-specific location', ->
      performanceObject = {vendor: 'webkit', timing: timing}
      window.webkitPerformance = performanceObject

      expect(window.performance).toBeUndefined()
      expect(locatePerformanceObject()).toBe(performanceObject)
      expect(hasNavigationTimingAPI()).toBeTruthy()

  describe 'Navigator helpers', ->

    beforeEach () ->
      window.navigator = undefined

    it 'locateNavigatorObject should return undefined when navigator object is not present', ->

      expect(window.navigator).toBeUndefined()
      expect(locateNavigatorObject()).toBeUndefined()
      expect(getUserAgent()).toBeUndefined()

    it 'locateNavigatorObject should return navigator when navigator object is defined, but userAgent is not', ->

      navigatorObject = {}

      window.navigator = navigatorObject

      expect(locateNavigatorObject()).toBe(navigatorObject)
      expect(getUserAgent()).toBeUndefined()

    it 'locateNavigatorObject should return navigator object', ->

      userAgent = "User Agent / #{randInt()}"
      navigatorObject =
        userAgent: userAgent

      window.navigator = navigatorObject

      expect(locateNavigatorObject()).toBe(navigatorObject)
      expect(getUserAgent()).toBe(userAgent)

  describe 'APIConnection', ->
    it 'APIConnection be defined', ->
      expect(APIConnection).toBeDefined()

  describe 'Timer', ->
    timer = null

    beforeEach () ->
      timer = new Timer

    it 'should default members to undefined', ->
      timer = new Timer
      expect(timer.tStart).toBeUndefined()
      expect(timer.tFinish).toBeUndefined()

    it 'should record current time when start is called', ->
      for i in [1..100]
        before = epochTimeInMilliseconds()
        timer.start()
        after = epochTimeInMilliseconds()

        expect(timer.tStart).toBeGreaterThan(before - 1)
        expect(timer.tStart).toBeLessThan(after + 1)
        expect(timer.tFinish).toBeUndefined()

    it 'should record current time when finish is called', ->
      timer.finish()

      expect(timer.tStart).toBeUndefined()
      expect(timer.tFinish).toBeLessThan(epochTimeInMilliseconds() + 1)

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

  describe 'toPageName', ->

    location = null

    beforeEach: () ->
      location = {pathname: "/"}

    it 'should be defined', ->
      expect(toPageName).toBeDefined()

    it 'should convert query paths to a WeblogNG compatible metric name component', ->

      expect(toPageName({ pathname: "/" })).toBe("root")
      expect(toPageName({ pathname: "////" })).toBe("root")

      expect(toPageName({ pathname: "/some/page" })).toBe("some-page")
      expect(toPageName({ pathname: "/some/page/" })).toBe("some-page")
      expect(toPageName({ pathname: "//some///page////" })).toBe("some-page")
      expect(toPageName({ pathname: "some/page/" })).toBe("some-page")
      expect(toPageName({ pathname: "some/page" })).toBe("some-page")

    it 'should convert bad location and location.pathname inputs to "unknown-page"', ->

      expect(toPageName()).toBe("unknown-page")
      expect(toPageName(null)).toBe("unknown-page")

      expect(toPageName({pathname: undefined})).toBe("unknown-page")
      expect(toPageName({pathname: null})).toBe("unknown-page")

  describe 'addExceptionHandler', ->
    window = {}
    logger  = new Logger(apiHost, apiKey)
    apiHost = "localhost:9000"
    apiKey = "abcd-1234"


    it 'should set handler message to listen to onerror events', ->
      handler = jasmine.createSpy()
      window.onerror = () ->

      onErrorFn = addExceptionHandler(handler)
      onErrorFn({}, "error message")

      expect(handler).toHaveBeenCalledWith('Critical', "error message")




