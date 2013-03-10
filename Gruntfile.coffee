module.exports = (grunt) ->

  # Constants
  BUILD_PATH = 'build'
  APP_PATH   = 'src'
  DEV_PATH   = "#{BUILD_PATH}/development"
  JS_DEV_PATH = "#{DEV_PATH}/js"

  # Project configuration
  grunt.initConfig
    clean:
      development: [DEV_PATH]

    coffee:
      development:
        files:
          'build/development/js/logger.js': [
            'src/logger.coffee'
          ]
      config:
        options:
          bare: true
        files: [
          expand: true
          cwd: 'config'
          src: ['**/*.coffee']
          dest: 'config'
          ext: '.js'
        ]
    concat:
      development:
        files:
          'build/development/js/vendor.js': [
            #'vendor/script/**/*.js'
          ]
          'build/development/js/vendor.css': 'vendor/style/**/*.css'
    connect:
      server:
        options:
          port: 8002
          base: "./#{DEV_PATH}"

    watch:
      coffee:
        files: ['src/*.coffee', 'src/**/*.coffee']
        tasks: 'coffee:development'
      concat:
        files: ['vendor/script/**/*.js', 'vendor/style/**/*.css']
        tasks: 'concat:development'
      config:
        files: ['config/testacular/*.coffee']
        tasks: 'coffee:config'

    testacular:
      unit:
        options:
          configFile: 'config/testacular/unit.js'
      e2e:
        options:
          configFile: 'config/testacular/e2e.js'
    testacularRun:
      unit:
        options:
          runnerPort: 9201
      e2e:
        options:
          runnerPort: 9202



  # Dependencies
  grunt.loadNpmTasks 'grunt-contrib-concat'
  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadNpmTasks 'grunt-contrib-watch'

  grunt.loadNpmTasks 'grunt-contrib-coffee'
#  grunt.loadNpmTasks 'grunt-contrib-jade'
#  grunt.loadNpmTasks 'grunt-contrib-less'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-contrib-clean'
  
  grunt.loadNpmTasks 'grunt-testacular'

  # Aliases
  grunt.registerTask 'config', 'coffee:config'
  grunt.registerTask 'development', [
    'clean:development'
    'coffee:development'
#    'jade:development'
    'concat:development'
#    'less:development'
  ]

  grunt.registerTask 'test', 'testacular'

  grunt.registerTask 'default', [
    'config'
    'development'
    'test'
    'connect:server'
    'watch'
  ]
