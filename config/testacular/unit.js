var autoWatch, background, basePath, browsers, files, junitReporter, logLevel, port, preprocessors, proxies, reporter, runnerPort, singleRun;

basePath = '../../';

files = ['build/development/js/*.js', 'build/test/js/logger.spec.js'];

autoWatch = false;

browsers = ['PhantomJS'];

singleRun = false;

runnerPort = 9100;

port = 9878;

reporter = 'progress';

proxies = {
  '/': 'http://localhost:8002/'
};

junitReporter = {
  outputFile: 'test_out/unit.xml',
  suite: 'unit'
};

preprocessors = {
  '**/*.coffee': 'coffee'
};

logLevel = LOG_DEBUG;

background = true;
