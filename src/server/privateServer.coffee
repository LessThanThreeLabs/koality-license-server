fs = require 'fs'
assert = require 'assert'
colors = require 'colors'
https = require 'https'
express = require 'express'

LicenseKeySanitizer = require './helpers/licenseKeySanitizer'


exports.create = (serverConfigurationParams, modelConnection, logger) ->
	licenseKeySanitizer = LicenseKeySanitizer.create()
	return new PrivateServer serverConfigurationParams, modelConnection, logger, licenseKeySanitizer


class PrivateServer
	constructor: (@configurationParams, @modelConnection, @logger, @licenseKeySanitizer) ->
		assert.ok @configurationParams? and typeof @configurationParams is 'object'
		assert.ok @modelConnection? and typeof @modelConnection is 'object'
		assert.ok @logger? and typeof @logger is 'object'
		assert.ok @licenseKeySanitizer? and typeof @licenseKeySanitizer is 'object'


	start: () =>
		addProjectBindings = () =>
			expressServer.get '/license', @_getLicenseHandler
			expressServer.get '/license/check', @_licenseCheckHandler
			expressServer.post '/license/generate', @_generateLicenseHandler
			expressServer.put '/license/type', @_setLicenseTypeHandler
			expressServer.get '*', (request, response) =>
				response.send 404, '404'

		expressServer = express()
		expressServer.use express.query()
		expressServer.use express.bodyParser()

		await
			fs.readFile @configurationParams.certificates.location + '/key.pem', defer keyError, key
			fs.readFile @configurationParams.certificates.location + '/cert.pem', defer certificateError, certificate

		httpsOptions =
			key: key
			cert: certificate
		server = https.createServer httpsOptions, expressServer
		server.listen @configurationParams.port

		@logger.info 'private server started'
		console.log "PRIVATE SERVER STARTED on port #{@configurationParams.port}".bold.magenta


	_getLicenseHandler: (request, response) =>
		licenseKey = @licenseKeySanitizer.getSanitizedKey request.query?.licenseKey

		if not licenseKey? then response.send 400, 'Invalid license key'
		else
			@modelConnection.getLicenseFromKey licenseKey, (error, license) ->
				if error?
					@logger.error error
					response.send 500, error
				else
					await
						@modelConnection.permissions.getLicensePermissions licenseKey, defer permissionsError, permissions
						@modelConnection.metadata.getLicenseMetadata licenseKey, defer metadataError, metadata						

					if permissionsError?
						@logger.error error
						response.send 500, error
					else if metadataError?
						@logger.error error
						response.send 500, error
					else
						license.permissions = permissions
						license.metadata = metadata

						response.json license


	_generateLicenseHandler: (request, response) =>
		licenseType = request.body?.type ? 'bronze'

		if not licenseType? then response.send 400, 'Invalid license type'
		else 
			@modelConnection.permissions.getPermissionsFromLicenseType licenseType, (error, permissions) ->
				if error?
					@logger.error error
					response.send 500, error
				else
					@modelConnection.generateLicenseKey licenseType, (error, license) ->
						if error?
							@logger.error error
							response.send 500, error
						else
							@modelConnection.permissions.updateLicensePermissions license.key, permissions, (error) ->
								if error?
									@logger.error error
									response.send 500, error
								else
									@logger.info 'Successfully generated license key: ' + license.key
									response.json license


	_setLicenseTypeHandler: (request, response) =>
		licenseKey = @licenseKeySanitizer.getSanitizedKey request.query?.licenseKey
		licenseType = request.body?.type

		if not licenseKey? then response.send 400, 'Invalid license key'
		else if not licenseType? then response.send 400, 'Invalid license type'
		else 
			@modelConnection.permissions.setLicenseType licenseKey, licenseType, (error) ->
				if error?
					@logger.error error
					response.send 500, error
				else response.send 'ok'


	_licenseCheckHandler: () =>
		licenseKey = @licenseKeySanitizer.getSanitizedKey request.query?.licenseKey
		serverId = request.query?.serverId

		if not licenseKey? then response.send 400, 'Invalid license key'
		else if not serverId? then response.send 400, 'Invalid server id'
		else 
			@modelConnection.validation.validateLicenseKey licenseKey, serverId, (error, licenseResult) ->
				if error?
					@logger.error error
					response.send 500, 'Internal error'
				else
					response.json licenseResult
