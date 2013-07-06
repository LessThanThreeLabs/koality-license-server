fs = require 'fs'
assert = require 'assert'
colors = require 'colors'
https = require 'https'
express = require 'express'

LicenseKeySanitizer = require './helpers/licenseKeySanitizer'


exports.create = (serverConfigurationParams, modelConnection, logger) ->
	licenseKeySanitizer = LicenseKeySanitizer.create()
	return new PublicServer serverConfigurationParams, modelConnection, logger, licenseKeySanitizer


class PublicServer
	constructor: (@configurationParams, @modelConnection, @logger, @licenseKeySanitizer) ->
		assert.ok @configurationParams? and typeof @configurationParams is 'object'
		assert.ok @modelConnection? and typeof @modelConnection is 'object'
		assert.ok @logger? and typeof @logger is 'object'
		assert.ok @licenseKeySanitizer? and typeof @licenseKeySanitizer is 'object'


	start: () =>
		addProjectBindings = () =>
			expressServer.get '/license/check', @_licenseCheckHandler
			expressServer.get '*', (request, response) =>
				response.send 404, '404'

		expressServer = express()
		expressServer.use express.query()
		expressServer.use express.bodyParser()
		addProjectBindings()

		await
			fs.readFile @configurationParams.certificates.location + '/key.pem', defer keyError, key
			fs.readFile @configurationParams.certificates.location + '/cert.pem', defer certificateError, certificate

		httpsOptions =
			key: key
			cert: certificate
		server = https.createServer httpsOptions, expressServer
		server.listen @configurationParams.port

		@logger.info 'public server started'
		console.log "PUBLIC SERVER STARTED on port #{@configurationParams.port}".bold.magenta


	_licenseCheckHandler: (request, response) =>
		licenseKey = @licenseKeySanitizer.getSanitizedKey request.query?.licenseKey
		serverId = request.query?.serverId
		userCount = request.query?.userCount

		if not licenseKey? then response.send 400, 'Invalid license key'
		else if not serverId? then response.send 400, 'Invalid server id'
		else if not userCount? then response.send 400, 'Invalid user count'
		else 
			@modelConnection.validation.validateLicenseKey licenseKey, serverId, (error, licenseResult) =>
				if error?
					@logger.error error
					response.send 500, 'Internal error'
				else if not licenseResult.isValid
					response.json licenseResult
				else
					@modelConnection.permissions.getLicensePermissions licenseKey, (error, permissions) ->
						if error?
							@logger.error error
							response.send 500, 'Internal error'
						else
							licenseResult.permissions = permissions

							@modelConnection.metadata.updateLicenseMetadata licenseKey, {userCount: userCount}, (error) ->
								if error?
									@logger.error error
									response.send 500, 'Internal error'
								else
									response.json licenseResult
