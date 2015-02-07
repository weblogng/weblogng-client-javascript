'use strict';

module.exports = function (grunt) {
  // Project configuration.
  grunt.initConfig({
    // Metadata.
    pkg: grunt.file.readJSON('package.json'),
    banner: '/*! <%= pkg.name %> - v<%= pkg.version %> - ' +
      '<%= grunt.template.today("yyyy-mm-dd") %>\n' +
      '<%= pkg.homepage ? "* " + pkg.homepage + "\\n" : "" %>' +
      '* Copyright (c) <%= grunt.template.today("yyyy") %> <%= pkg.author.name %>;' +
      ' Licensed <%= _.pluck(pkg.licenses, "type").join(", ") %> */\n',
    // Task configuration.
    clean: {
      files: ['dist']
    },

    coffee: {
      config: {
        options: {
          bare: true
        },
        files: [
          {
            expand: true,
            cwd: 'config',
            src: ['**/*.coffee'],
            dest: 'config',
            ext: '.js'
          }
        ]
      },
      development: {
        options: {
          bare: false
        },
        files: {
          'dist/app/logger.js': ['app/logger.coffee']
          ,'dist/test/logger.spec.js': ['test/logger.spec.coffee']
        }
      }
    },

    copy: {
      development: {
        files: [
          {
            nonull: true,
            src: 'test/test-main.js',
            dest: 'dist/test/test-main.js'
          }
        ]
      }
    },

    uglify: {
      options: {
        banner: '<%= banner %>'
      },
      dist: {
        src: 'dist/app/logger.js',
        dest: 'dist/app/logger.min.js'
      }
    },

    karma: {
      options: {
        configFile: 'karma.conf.js'
      }
      , unit: {
        background: true
      }
      , continuous: {
        singleRun: true, browsers: ['PhantomJS']
      }

    },

    jshint: {
      gruntfile: {
        options: {
          jshintrc: '.jshintrc'
        },
        src: 'Gruntfile.js'
      },
      app: {
        options: {
          jshintrc: 'app/.jshintrc'
        },
        src: ['dist/app/logger.js']
      }
    },

    watch: {
      gruntfile: {
        files: 'Gruntfile.js',
        tasks: ['jshint:gruntfile']
      },
      src: {
        files: ['app/**/*.coffee'],
        tasks: ['default']
      },
      test: {
        files: ['test/**/*.coffee'],
        tasks: ['default']
      }
    },

    release: {
      options: {
        additionalFiles: ['bower.json']
      }
    }
  });

  // These plugins provide necessary tasks.
  grunt.loadNpmTasks('grunt-contrib-clean');
  grunt.loadNpmTasks('grunt-contrib-coffee');
  grunt.loadNpmTasks('grunt-contrib-copy');
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-karma');
  grunt.loadNpmTasks('grunt-release');

  // Default task.
  grunt.registerTask('default', [
    'clean',
    'coffee:development',
    'copy:development',
    'jshint',
    'karma:continuous',
    'uglify'
  ]);

  grunt.registerTask('test', ['karma:continuous']);
};
