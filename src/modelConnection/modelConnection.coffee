fs = require 'fs'
assert = require 'assert'
mysql = require 'mysql'

Stripe = require 'stripe'

LicenseMetadataConnection = require './helpers/licenseMetadataConnection'
LicenseTypeConnection = require './helpers/licenseTypeConnection'
LicenseValidationConnection = require './helpers/licenseValidationConnection'
LicensePermissionsConnection = require './helpers/licensePermissionsConnection'


exports.create = (configurationParams, logger) ->
	modelConnection = new ModelConnection configurationParams, logger
	modelConnection.initialize()
	return modelConnection


class ModelConnection
	constructor: (@configurationParams, @logger) ->
		assert.ok @configurationParams? and typeof @configurationParams is 'object'
		assert.ok @logger? and typeof @logger is 'object'


	initialize: () =>
		@stripe = new Stripe @configurationParams.stripe.privateKey
		@sqlPool = mysql.createPool @configurationParams.mysqlConnectionParams

		@metadata = LicenseMetadataConnection.create @configurationParams, @sqlPool, @stripe, @logger
		@type = LicenseTypeConnection.create @configurationParams, @sqlPool, @stripe, @logger
		@validation = LicenseValidationConnection.create @configurationParams, @sqlPool, @stripe, @logger
		@permissions = LicensePermissionsConnection.create @configurationParams, @sqlPool, @stripe, @logger

		fs.readFile @configurationParams.schemaFile, 'utf8', (error, schema) =>
			if error? then throw error
			else
				for statement, index in schema.split ';'
					statement = statement.trim()
					continue if statement is ''

					do (statement) =>
						@sqlPool.getConnection (error, connection) =>
							throw error if error?

							connection.query statement, (statementError, statementResult) =>
								connection.end()
								throw statementError if statementError?


	generateLicenseKey: (licenseType, callback) =>
		crypto.randomBytes 16, (error, buffer) =>
			if error? then callback error
			else
				licenseKey = (byte.toString(36).toUpperCase().split('').pop() for byte in buffer).join ''

				query = 'INSERT INTO license SET ?'
				params =
					license_key: licenseKey
					is_valid: true
					type: licenseType
					used_trial: false

				@sqlPool.getConnection (error, connection) =>
					if error? then callback error
					else 
						connection.query query, params, (error, results) =>
							connection.end()
							if error? then callback error
							else callback null,
								id: results.insertId,
								key: licenseKey


	getLicenseFromKey: (licenseKey, callback) =>
		query = 'SELECT id, 
					account_id as accountId, 
					license.type as type, 
					license.used_trial as usedTrial, 
					license.license_key as licenseKey,
					server_id as serverId,
					is_valid as isValid,
					account.stripe_customer_id as stripeCustomerId,
					used_trial as usedTrial, 
					unpaid_expiration as unpaidExpiration, 
					last_ping as lastPing, 
					type
				FROM license
				LEFT JOIN account ON
					license.account_id = account.id WHERE
					license_key = ?'	

		@sqlPool.getConnection (error, connection) =>
			if error? then callback error
			else 
				connection.query query, [licenseKey], (error, results) =>
					connection.end()
					if error? then callback error
					else if results.length isnt 1 then callback 404, 'No such license key'
					else callback null, results[0]
