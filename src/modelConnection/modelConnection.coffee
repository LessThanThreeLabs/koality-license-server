fs = require 'fs'
assert = require 'assert'
crypto = require 'crypto'
mysql = require 'mysql'

Stripe = require 'stripe'

LicenseMetadataConnection = require './helpers/licenseMetadataConnection'
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
		@validation = LicenseValidationConnection.create @configurationParams, @sqlPool, @stripe, @setLicenseType, @logger
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
								licenseKey: licenseKey


	getLicenseFromKey: (licenseKey, callback) =>
		query = 'SELECT license.id as id, 
					account_id as accountId, 
					license.type as type, 
					license.used_trial as usedTrial, 
					license.license_key as licenseKey,
					server_id as serverId,
					is_valid as isValid,
					account.stripe_customer_id as stripeCustomerId,
					used_trial as usedTrial, 
					unpaid_expiration as unpaidExpiration, 
					last_ping as lastPing
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

	setLicenseType: (license, licenseType, callback) =>
		setPlanDataWithOldTrialEnd = (stripeCustomer, planData) =>
			# Setting the trial end in the past is invalid
			oneHourFromNow = Math.round(Date.now() / 1000 + (60 * 60))

			if stripeCustomer.subscription.trial_end < oneHourFromNow then planData.trial_end = 'now'
			else planData.trial_end = stripeCustomer.subscription.trial_end

		setLicenseTypeInStripe = (license, stripeCustomer, callback) =>
			planData =
				plan: licenseType + '_' + @configurationParams.stripe.planVersion
				quantity: stripeCustomer.subscription?.quantity or 1  # We can't charge for 0 users. Stripe gets mad

			if stripeCustomer.subscription?.trial_end? then setPlanDataWithOldTrialEnd stripeCustomer, planData
			else if license.usedTrial then planData.trial_end = 'now'

			@stripe.customers.update_subscription license.stripeCustomerId, planData, (error, response) =>
				if error? then callback error
				else callback()

		setLicenseTypeInDb = (license, permissions, callback) =>
			@sqlPool.getConnection (error, connection) =>
				if error? then callback error
				else 
					connection.query 'UPDATE license SET type = ? WHERE license_key = ?', [licenseType, license.licenseKey], (error, results) =>
						connection.end()
						if error? then callback error
						else if results.affectedRows isnt 1 then callback 'License key not found'
						else
							@permissions.clearLicensePermissions license, (error) =>
								if error? then callback error
								else @permissions.updateLicensePermissions license, permissions, callback

		await 
			@stripe.customers.retrieve license.stripeCustomerId, defer stripeError, stripeCustomer
			@permissions.getPermissionsFromLicenseType licenseType, defer permissionsError, permissions

		if stripeError? then callback stripeError
		else if permissionsError? then callback permissionsError
		else
			setLicenseTypeInStripe license, stripeCustomer, (error) =>
				if error? then callback error
				else setLicenseTypeInDb license, permissions, callback
