fs = require 'fs'
assert = require 'assert'
colors = require 'colors'
http = require 'http'
express = require 'express'


exports.create = (serverConfigurationParams, modelConnection, logger) ->
	return new PrivateServer serverConfigurationParams, modelConnection, logger


class PrivateServer
	constructor: (@configurationParams, @modelConnection, @logger) ->
		assert.ok @configurationParams? and typeof @configurationParams is 'object'
		assert.ok @modelConnection? and typeof @modelConnection is 'object'
		assert.ok @logger? and typeof @logger is 'object'


	start: () =>
		addProjectBindings = () =>
			expressServer.get '/', (request, response) =>
				response.send 'hello'

			expressServer.get '*', (request, response) =>
				response.send 404, '404'

		expressServer = express()
		expressServer.use express.query()
		expressServer.use express.bodyParser()

		addProjectBindings()

		server = http.createServer expressServer
		server.listen @configurationParams.port

		@logger.info 'private server started'
		console.log "PRIVATE SERVER STARTED on port #{@configurationParams.port}".bold.magenta
