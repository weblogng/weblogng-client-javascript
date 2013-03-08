Logger = require('../src/logger').Logger

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

    console.log s

    expect(s).toContain(logger.id)
    expect(s).toContain(logger.apiHost)
    expect(s).toContain(logger.apiKey)

    done()

  it 'should build WebSocket urls', (done) ->

    expect(logger.apiUrl).toBe("ws://#{apiHost}/log/ws")

    done()
