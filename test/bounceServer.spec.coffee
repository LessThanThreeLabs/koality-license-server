spawn = require('child_process').spawn


describe 'webserver', () ->

	it 'should successfully start', () ->
		flag = false
		successfullyStarted = false

		webserver = null
		killWebserverProcess = () ->
			webserver.kill() if webserver?

		process.on 'uncaughtException', killWebserverProcess
		process.on 'SIGINT', killWebserverProcess
		process.on 'SIGTERM', killWebserverProcess

		runs () ->
			webserver = spawn 'node', ['--harmony', 'libs/index.js']

			successfullyStarted = true

			handleWebserverFailure = (data) ->
				clearTimeout timer
				killWebserverProcess()

				successfullyStarted = false if not flag
				flag = true

			webserver.stderr.on 'data', handleWebserverFailure
			webserver.on 'close', handleWebserverFailure

			timer = setTimeout (() ->
				flag = true
				killWebserverProcess()
			), 10000

		waitsFor (() -> return flag), 'Webserver should have successfully started', 11000

		runs () ->
			killWebserverProcess()
			expect(successfullyStarted).toBe true
