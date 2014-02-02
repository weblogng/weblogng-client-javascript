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
          , 'build/test/js/logger.spec.js': [
            'test/logger.spec.coffee'
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
          ]
          'build/development/js/vendor.css': 'vendor/style/**/*.css'

    copy:
      development:
        files:
          'build/development/app.html': 'src/app.html'

    connect:
      server:
        options:
          port: 8002
          base: "./#{DEV_PATH}"

    karma:
      options:
        configFile: 'config/karma.conf.js'
      unit:
        background: true
      continuous:
        singleRun: true
        browsers: ['PhantomJS']

    watch:
      coffee:
        files: ['src/*.coffee', 'src/**/*.coffee', 'test/*.spec.coffee']
        tasks: 'coffee:development'
      concat:
        files: ['vendor/script/**/*.js', 'vendor/style/**/*.css']
        tasks: 'concat:development'
      copy:
        files: ['src/app.html']
        tasks: 'copy:development'
      karma:
        files: ['build/development/js/**/*.js', 'build/test/js/logger.spec.js'],
        tasks: ['karma:unit:run']


  # Dependencies
  grunt.loadNpmTasks 'grunt-contrib-concat'
  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadNpmTasks 'grunt-contrib-watch'

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-contrib-clean'
  
  grunt.loadNpmTasks 'grunt-karma'

  # Aliases
  grunt.registerTask 'config', 'coffee:config'
  grunt.registerTask 'development', [
    'clean:development'
    'coffee:development'
    'concat:development'
    'copy:development'
  ]

  grunt.registerTask 'test', 'karma:unit:run'

  grunt.registerTask 'default', [
    'config'
    'development'
    'test'
    'watch'
  ]
