# Overview #

The WeblogNG Javascript Client library is used by web applications to record and report events and measurements
made in the client back to the WeblogNG api for collection.

# Documentation #

Documentation for using the Javascript Client library as well as other clients is available at http://docs.weblogng.com

# Building #

The library can be built and tested by following the steps below.

Setup build environment with:
```
npm install
```

Execute a clean build with:
```
./build_and_test.sh
```

The WeblogNG library will be compiled from Coffeescript, tested, and output to dist/app/logger.js.

The build_and_test.sh script contains all the build steps required to perform a release.

For normal development, with `grunt watch` is recommended.