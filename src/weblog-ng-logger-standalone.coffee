weblog = this
window?.weblog = weblog

weblog.generateUniqueId = (length=8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length

class weblog.Logger
  constructor: (@apiHost)

  toString: ->
    "[Logger name: " + @name + "]"

