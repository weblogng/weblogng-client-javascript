(function() {
  var weblogng;

  weblogng = this;

  if (typeof window !== "undefined" && window !== null) {
    window.weblogng = weblogng;
  }

  weblogng.generateUniqueId = function(length) {
    var id;
    if (length == null) {
      length = 12;
    }
    id = "";
    while (id.length < length) {
      id += Math.random().toString(36).substr(2);
    }
    return id.substr(0, length);
  };

  weblogng.throttle = function(fn, delay) {
    var timer;
    if (delay === 0) {
      return fn;
    }
    timer = false;
    return function() {
      var timeoutFn;
      if (timer) {
        return;
      }
      timer = true;
      timeoutFn = function() {
        timer = false;
        return timer;
      };
      if (delay !== -1) {
        setTimeout(timeoutFn, delay);
      }
      return fn.apply(null, arguments);
    };
  };

  weblogng.epochTimeInMilliseconds = function() {
    return new Date().getTime();
  };

  weblogng.epochTimeInSeconds = function() {
    return Math.round(new Date().getTime() / 1000);
  };

  weblogng.locatePerformanceObject = function() {
    return window.performance || window.mozPerformance || window.msPerformance || window.webkitPerformance;
  };

  weblogng.locateNavigatorObject = function() {
    return navigator;
  };

  weblogng.getUserAgent = function() {
    var navigator;
    navigator = locateNavigatorObject();
    if (navigator && navigator.userAgent) {
      return navigator.userAgent;
    } else {
      return void 0;
    }
  };

  weblogng.hasNavigationTimingAPI = function() {
    var _ref;
    if ((_ref = locatePerformanceObject()) != null ? _ref.timing : void 0) {
      return true;
    } else {
      return false;
    }
  };

  weblogng.patterns = {
    MATCH_LEADING_AND_TRAILING_SLASHES: /^\/+|\/+$/g,
    MATCH_SLASHES: /\/+/g,
    MATCH_FORBIDDEN_METRIC_NAME_CHARS: /[^\w\d\:\\?\=\/\\\._\-\%]+/g
  };

  weblogng.toPageName = function(location) {
    var pageName;
    if (location && location.pathname) {
      pageName = location.pathname.replace(patterns.MATCH_LEADING_AND_TRAILING_SLASHES, '').replace(patterns.MATCH_SLASHES, '-');
      if ("" === pageName) {
        return "root";
      } else {
        return pageName;
      }
    } else {
      return "unknown-page";
    }
  };

  weblogng.addListener = function(root, eventName, listener) {
    if (root && eventName && listener) {
      if (root.addEventListener) {
        return root.addEventListener(eventName, listener, true);
      } else if (root.attachEvent) {
        return root.attachEvent(eventName, listener, true);
      }
    }
  };


  /*
    APIConnection is a simple abstraction wrapping browser-provided mechanisms for sending data to the WeblogNG api
   */

  weblogng.APIConnection = (function() {
    function APIConnection(apiUrl) {
      this.apiUrl = apiUrl;
    }

    APIConnection.prototype.send = function(logMessage) {
      var xhr;
      xhr = new XMLHttpRequest();
      xhr.open("POST", this.apiUrl, true);
      xhr.setRequestHeader("Content-Type", "application/json");
      xhr.setRequestHeader("Accept", "application/json, text/javascript, */*; q=0.01");
      xhr.send(JSON.stringify(logMessage));
    };

    return APIConnection;

  })();

  weblogng.Timer = (function() {
    function Timer() {}

    Timer.prototype.start = function() {
      this.tStart = epochTimeInMilliseconds();
    };

    Timer.prototype.finish = function() {
      this.tFinish = epochTimeInMilliseconds();
    };

    Timer.prototype.getElapsedTime = function() {
      return this.tFinish - this.tStart;
    };

    return Timer;

  })();

  weblogng.Scope = (function() {
    function Scope() {}

    Scope.APPLICATION = 'application';

    return Scope;

  })();

  weblogng.Category = (function() {
    function Category() {}

    Category.NAVIGATION_TIMING = 'navigation timing';

    return Category;

  })();

  weblogng.Logger = (function() {
    function Logger(apiHost, apiKey, options) {
      var _ref, _ref1, _sendToAPI;
      this.apiHost = apiHost;
      this.apiKey = apiKey;
      this.options = options != null ? options : {
        publishNavigationTimingMetrics: true,
        publishUserActive: true,
        application: ""
      };
      this.id = generateUniqueId();
      this.apiUrl = "https://" + apiHost + "/v2/log";
      this.defaultContext = {};
      this.apiConnection = this._createAPIConnection(this.apiUrl);
      this.timers = {};
      this.buffers = {
        events: [],
        metrics: []
      };
      this.userActivityCheckInterval = 60000;
      this.timeOfLastUserActivity = epochTimeInMilliseconds();
      this.publishNavigationTimingMetrics = (_ref = this.options && this.options.publishNavigationTimingMetrics) != null ? _ref : {
        "true": false
      };
      this.publishUserActive = (_ref1 = this.options && this.options.publishUserActive) != null ? _ref1 : {
        "true": false
      };
      if (this.options && this.options.application) {
        this.defaultContext.application = this.options.application;
      } else {
        delete this.defaultContext.application;
      }
      if (this.publishNavigationTimingMetrics && hasNavigationTimingAPI()) {
        this._initNavigationTimingPublishProcess();
      }
      if (this.publishUserActive) {
        this._initUserActivityPublishProcess();
      }
      _sendToAPI = (function(_this) {
        return function() {
          return _this._sendToAPI();
        };
      })(this);
      this._throttledSendToAPI = weblogng.throttle(_sendToAPI, 5000);
    }

    Logger.prototype._addAttributesToLogItem = function(obj, scope, category) {
      if (scope) {
        obj.scope = scope;
      }
      if (category) {
        obj.category = category;
      }
      return obj;
    };

    Logger.prototype.makeEvent = function(name, timestamp, scope, category) {
      var event;
      if (timestamp == null) {
        timestamp = epochTimeInMilliseconds();
      }
      if (scope == null) {
        scope = Scope.APPLICATION;
      }
      if (category == null) {
        category = void 0;
      }
      event = {
        "name": name,
        "timestamp": timestamp
      };
      return this._addAttributesToLogItem(event, scope, category);
    };

    Logger.prototype.makeMetric = function(name, value, timestamp, scope, category) {
      var metric;
      if (timestamp == null) {
        timestamp = epochTimeInMilliseconds();
      }
      if (scope == null) {
        scope = Scope.APPLICATION;
      }
      if (category == null) {
        category = void 0;
      }
      metric = {
        "name": name,
        "value": value,
        "unit": "ms",
        "timestamp": timestamp
      };
      return this._addAttributesToLogItem(metric, scope, category);
    };

    Logger.prototype._sendToAPI = function() {
      var events, metrics;
      events = this.buffers.events;
      metrics = this.buffers.metrics;
      this.buffers.events = [];
      this.buffers.metrics = [];
      return this.apiConnection.send(this._createLogMessage(events, metrics));
    };

    Logger.prototype._triggerSendToAPI = function() {
      return this._throttledSendToAPI();
    };

    Logger.prototype.sendMetric = function(metricName, metricValue, timestamp, scope, category) {
      if (timestamp == null) {
        timestamp = epochTimeInMilliseconds();
      }
      if (scope == null) {
        scope = Scope.APPLICATION;
      }
      if (category == null) {
        category = void 0;
      }
      this.buffers.metrics.push(this.makeMetric(metricName, metricValue, timestamp, scope, category));
      return this._triggerSendToAPI();
    };

    Logger.prototype._createAPIConnection = function(apiUrl) {
      return new weblogng.APIConnection(apiUrl);
    };

    Logger.prototype._createLogMessage = function(events, metrics) {
      var context, event, message, metric, userAgent, _i, _j, _len, _len1;
      if (events == null) {
        events = [];
      }
      if (metrics == null) {
        metrics = [];
      }
      for (_i = 0, _len = events.length; _i < _len; _i++) {
        event = events[_i];
        event.name = this._sanitizeMetricName(event.name);
      }
      for (_j = 0, _len1 = metrics.length; _j < _len1; _j++) {
        metric = metrics[_j];
        metric.name = this._sanitizeMetricName(metric.name);
      }
      context = {};
      if (this.options.application) {
        context.application = this.options.application;
      }
      userAgent = getUserAgent();
      if (userAgent) {
        context.userAgent = userAgent;
      }
      message = {
        "apiAccessKey": this.apiKey,
        "context": context,
        "events": events,
        "metrics": metrics
      };
      return message;
    };

    Logger.prototype._sanitizeMetricName = function(metricName) {
      return metricName.replace(patterns.MATCH_FORBIDDEN_METRIC_NAME_CHARS, ' ');
    };

    Logger.prototype.recordStart = function(metricName) {
      var timer;
      timer = new weblogng.Timer();
      timer.start();
      this.timers[metricName] = timer;
      return timer;
    };

    Logger.prototype.recordFinish = function(metricName) {
      var timer;
      if (this.timers[metricName]) {
        timer = this.timers[metricName];
        timer.finish();
        return timer;
      } else {
        return null;
      }
    };

    Logger.prototype.recordFinishAndSendMetric = function(metricName) {
      var timer;
      timer = this.recordFinish(metricName);
      if (timer) {
        this.sendMetric(metricName, timer.getElapsedTime());
        delete this.timers[metricName];
      }
    };

    Logger.prototype.executeWithTiming = function(metric_name, function_to_exec) {
      var error, timer;
      if (function_to_exec) {
        timer = new weblogng.Timer();
        timer.start();
        try {
          function_to_exec();
          timer.finish();
          this.sendMetric(metric_name, timer.getElapsedTime());
        } catch (_error) {
          error = _error;
        }
      }
    };

    Logger.prototype.recordEvent = function(eventName, timestamp, scope, category) {
      if (timestamp == null) {
        timestamp = epochTimeInMilliseconds();
      }
      if (scope == null) {
        scope = Scope.APPLICATION;
      }
      if (category == null) {
        category = void 0;
      }
      this.buffers.events.push(this.makeEvent(eventName, timestamp, scope, category));
      return this._triggerSendToAPI();
    };

    Logger.prototype._initNavigationTimingPublishProcess = function() {
      var onReadyStateComplete;
      if (!hasNavigationTimingAPI()) {
        return;
      }
      onReadyStateComplete = (function(_this) {
        return function() {
          return _this._publishNavigationTimingData();
        };
      })(this);
      this._waitForReadyStateComplete(onReadyStateComplete, 10);
    };

    Logger.prototype._waitForReadyStateComplete = function(callback, attemptsRemaining) {
      attemptsRemaining--;
      setTimeout((function(_this) {
        return function() {
          if ("complete" === document.readyState) {
            if (callback != null) {
              callback();
            }
          } else {
            if (attemptsRemaining > 0) {
              console.log("WeblogNG: readyState was not complete, " + attemptsRemaining + " re-scheduling");
              return _this._waitForReadyStateComplete(callback, attemptsRemaining);
            } else {
              return console.log("WeblogNG: readyState is not complete and no attempts remain; giving-up");
            }
          }
        };
      })(this), 1000);
    };

    Logger.prototype._publishNavigationTimingData = function() {
      var logMessage, timingData;
      timingData = this._generateNavigationTimingData();
      logMessage = this._createLogMessage(timingData.events, timingData.metrics);
      this.apiConnection.send(logMessage);
    };

    Logger.prototype._generateNavigationTimingData = function() {
      var category, data, events, metric, metrics, performance, scope, timestamp;
      performance = locatePerformanceObject();
      scope = toPageName(location);
      category = weblogng.Category.NAVIGATION_TIMING;
      timestamp = epochTimeInMilliseconds();
      events = [];
      metrics = [];
      if (performance.timing.dnsLookupStart > 0 && performance.timing.dnsLookupEnd > 0) {
        metric = this.makeMetric("dns_lookup_time", performance.timing.dnsLookupEnd - performance.timing.dnsLookupStart, timestamp, scope, category);
        metrics.push(metric);
      }
      if (performance.timing.connectStart > 0 && performance.timing.responseStart > 0) {
        metric = this.makeMetric("first_byte_time", performance.timing.responseStart - performance.timing.connectStart, timestamp, scope, category);
        metrics.push(metric);
      }
      if (performance.timing.responseStart > 0 && performance.timing.responseEnd > 0) {
        metric = this.makeMetric("response_recv_time", performance.timing.responseEnd - performance.timing.responseStart, timestamp, scope, category);
        metrics.push(metric);
      }
      if (performance.timing.loadEventStart > 0) {
        metric = this.makeMetric("page_load_time", performance.timing.loadEventStart - performance.timing.navigationStart, timestamp, scope, category);
        metrics.push(metric);
        events.push(this.makeEvent("page_load", timestamp, scope, category));
      }
      data = {
        metrics: metrics,
        events: events
      };
      return data;
    };

    Logger.prototype._initUserActivityPublishProcess = function(root) {
      var userActivityOccurred;
      if (root == null) {
        root = window;
      }
      userActivityOccurred = (function(_this) {
        return function() {
          return _this._userActivityOccurred();
        };
      })(this);
      addListener(root, 'mousemove', userActivityOccurred);
      addListener(root, 'keyup', userActivityOccurred);
      return this._scheduleRecurringUserActivityPublish();
    };

    Logger.prototype._userActivityOccurred = function() {
      this.timeOfLastUserActivity = epochTimeInMilliseconds();
    };

    Logger.prototype._scheduleRecurringUserActivityPublish = function() {
      var recordRecentUserActivity;
      recordRecentUserActivity = (function(_this) {
        return function() {
          return _this._recordRecentUserActivity();
        };
      })(this);
      return setInterval(recordRecentUserActivity, this.userActivityCheckInterval);
    };

    Logger.prototype._recordRecentUserActivity = function() {
      var now, tStartActivityInterval;
      now = epochTimeInMilliseconds();
      tStartActivityInterval = now - this.userActivityCheckInterval;
      if (this.timeOfLastUserActivity > tStartActivityInterval && this.timeOfLastUserActivity <= now) {
        return this.recordEvent('user_active', this.timeOfLastUserActivity);
      }
    };

    Logger.prototype.toString = function() {
      return "[Logger id: " + this.id + ", apiHost: " + this.apiHost + ", apiKey: " + this.apiKey + " ]";
    };

    return Logger;

  })();

}).call(this);
