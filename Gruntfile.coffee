module.exports = (grunt) ->

	grunt.initConfig
		package: grunt.file.readJSON 'package.json'
		sourceDirectory: 'src'
		testDirectory: 'test'
		compiledDirectory: 'libs'
		uglifiedDirectory: 'uglified'
		tarredPackageName: '<%= package.name %>-<%= package.version %>.tgz'
		s3Hash: 'cd855575be99a357'
		s3TarredPackageLocation: 's3://koality_code/libraries/private-<%= s3Hash %>/<%= tarredPackageName %>'

		shell:
			options:
				stdout: true
				stderr: true
				failOnError: true

			compile:
				command: 'iced --compile --output <%= compiledDirectory %>/ <%= sourceDirectory %>/'

			runServer:
				command: 'node --harmony <%= compiledDirectory %>/index.js --mode development'

			runServerProduction:
				command: 'node --harmony <%= compiledDirectory %>/index.js --mode production'

			removeCompile:
				command: 'rm -rf <%= compiledDirectory %>'

			removeUglify:
				command: 'rm -rf <%= uglifiedDirectory %>'

			replaceCompiledWithUglified:
				command: [
					'rm -rf <%= compiledDirectory %>'
					'mv <%= uglifiedDirectory %> <%= compiledDirectory %>'
					].join ' && '

			pack:
				command: 'npm pack'

			publish:
				command: 's3cmd put --acl-public --guess-mime-type <%= tarredPackageName %> <%= s3TarredPackageLocation %>'

			test:
				command: 'jasmine-node --color --coffee --forceexit <%= testDirectory %>/'

		uglify:
			options:
				preserveComments: 'some'

			libs:
				files: [
					expand: true
					cwd: '<%= compiledDirectory %>/'
					src: ['**/*.js']
					dest: '<%= uglifiedDirectory %>/'
					ext: '.js'
				]

		watch:
			compile:
				files: '<%= sourceDirectory %>/**/*.coffee'
				tasks: ['compile']

			test:
				files: ['<%= sourceDirectory %>/**/*.coffee', '<%= testDirectory %>/**/*.spec.coffee']
				tasks: ['compile', 'test']

	grunt.loadNpmTasks 'grunt-contrib-uglify'
	grunt.loadNpmTasks 'grunt-contrib-watch'
	grunt.loadNpmTasks 'grunt-shell'

	grunt.registerTask 'default', ['compile']
	grunt.registerTask 'compile', ['shell:removeCompile', 'shell:compile']

	grunt.registerTask 'run', ['shell:runServer']
	grunt.registerTask 'run-production', ['shell:runServerProduction']

	grunt.registerTask 'test', ['shell:test']

	grunt.registerTask 'make-ugly', ['shell:removeUglify', 'uglify']
	grunt.registerTask 'production', ['compile', 'make-ugly', 'shell:replaceCompiledWithUglified']
	grunt.registerTask 'publish', ['production', 'shell:pack', 'shell:publish']
