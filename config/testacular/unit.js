var autoWatch, basePath, browsers, files, junitReporter, logLevel, port, preprocessors, proxies, reporter, runnerPort, singleRun;

basePath = '../../';

files = ['build/development/js/*.js', 'test/**/*.coffee'];

autoWatch = false;

browsers = ['PhantomJS'];

singleRun = false;

runnerPort = 9201;

port = 9878;

reporter = 'progress';

proxies = {
  '/': 'http://localhost:8002/'
};

junitReporter = {
  outputFile: 'test_out/e2e.xml',
  suite: 'e2e'
};

preprocessors = {
  '**/*.coffee': 'coffee'
};

logLevel = LOG_DEBUG;
