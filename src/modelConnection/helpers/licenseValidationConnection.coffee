assert = require 'assert'


exports.create = (configurationParams, sqlPool, stripe, licenseTypeSetter, logger) ->
	return new LicenseValidationConnection configurationParams, sqlPool, stripe, licenseTypeSetter, logger


class LicenseValidationConnection
	constructor: (@configurationParams, @sqlPool, @stripe, @licenseTypeSetter, @logger) ->
		assert.ok @configurationParams? and typeof @configurationParams is 'object'
		assert.ok @sqlPool? and typeof @sqlPool is 'object'
		assert.ok @stripe? and typeof @stripe is 'object'
		assert.ok @licenseTypeSetter? and typeof @licenseTypeSetter is 'function'
		assert.ok @logger? and typeof @logger is 'object'


	_savePing: (license, callback) =>
		now = Math.round Date.now() / 1000

		@sqlPool.getConnection (error, connection) =>
			if error? then callback error
			else
				connection.query 'UPDATE license SET last_ping = ? WHERE id = ?', [now, license.id], (error, result) =>
					connection.end()
					callback error, result


	_registerServerWithLicenseKey: (licenseKey, serverId, callback) =>
		@sqlPool.getConnection (error, connection) =>
			if error? then callback error
			else
				connection.query 'UPDATE license SET server_id = ? where license_key = ?', [serverId, licenseKey], (error, result) =>
					connection.end()
					callback error, result


	_checkServerId: (license, serverId, callback) =>
		twoHoursAgo = (Math.round Date.now() / 1000) - (60 * 60 * 2)

		if not license.serverId? or not license.lastPing? or license.lastPing < twoHoursAgo
			if not serverId?
				callback null, true
			else
				@logger.info 'Registering server: ' + serverId + ' for license key: ' + license.licenseKey
				@_registerServerWithLicenseKey license.licenseKey, serverId, (error) =>
					if error? then callback error
					else
						@_savePing license, (error) =>
							if error? then callback error
							else callback null, true
		else if license.serverId isnt serverId
			callback null, false
		else
			@_savePing license, (error) =>
				if error? then callback error
				else callback null, true


	_checkPayment: (sqlConnection, license, callback) =>
		handleNoSubscription = (license, customer, callback) =>
			@licenseTypeSetter license, license.type, (error) =>
				if error? then callback error
				else callback null, {isValid: true, licenseType: license.type, trialExpiration: null, unpaidExpiration: null}

		handleTrial = (license, customer, callback) =>
			if customer.active_card?.cvc_check then unpaidExpiration = null
			else unpaidExpiration = customer.subscription.trial_end

			successResponse = {isValid: true, licenseType: license.type, trialExpiration: customer.subscription.trial_end, unpaidExpiration: unpaidExpiration}
			if not license.usedTrial
				sqlConnection.query 'UPDATE license SET used_trial = true WHERE id = ?', [license.id], (error) =>
					if error? then callback error
					else callback null, successResponse
			else
				callback null, successResponse

		handleUnpaid = (license, customer, callback) =>
			now = Math.round Date.now() / 1000
			fifteenDaysFromNow = now + (60 * 60 * 24 * 15)
			twelveHours = 60 * 60 * 12

			if customer.subscription.trial_start isnt customer.subscription.trial_end and customer.current_period_start - customer.subscription.trial_end < twelveHours
				callback null, {isValid: false, reason: 'Trial expired'}
			else if not license.unpaidExpiration?
				sqlConnection.query 'UPDATE license SET unpaid_expiration = ? WHERE id = ?', [fifteenDaysFromNow, license.id], (error) =>
					if error? then callback error
					else callback null, {isValid: true, licenseType: license.type, trialExpiration: null, unpaidExpiration: fifteenDaysFromNow}
			else if now > license.unpaidExpiration
				callback null, {isValid: false, reason: 'Subscription unpaid'}
			else
				callback null, {isValid: true, licenseType: license.type, trialExpiration: null, unpaidExpiration: license.unpaidExpiration}

		handlePaid = (license, callback) =>
			if license.unpaidExpiration?
				sqlConnection.query 'UPDATE license SET unpaid_expiration = ? WHERE id = ?', [null, license.id], (error) =>
					if error? then callback error
					else callback null, { isValid: true, licenseType: license.type, trialExpiration: null, unpaidExpiration: null }
			else
				callback null, {isValid: true, licenseType: license.type, trialExpiration: null, unpaidExpiration: null}

		if not license.stripeCustomerId?
			callback null, {isValid: false, reason: 'No subscription information'}
		else
			@stripe.customers.retrieve license.stripeCustomerId, (error, customer) =>
				if error? then callback error
				else
					if not customer.subscription?
						handleNoSubscription license, customer, callback
					else if customer.subscription.status is 'trialing'
						handleTrial license, customer, callback
					else if customer.subscription.status in ['canceled', 'past_due', 'unpaid']
						handleUnpaid license, customer, callback
					else
						handlePaid license, callback


	validateLicenseKey: (licenseKey, serverId, callback) =>
		getLicense = (callback) =>
			query = 'SELECT license.id,
					license.is_valid as isValid,
					license.server_id as serverId,
					license.type as type,
					license.used_trial as usedTrial,
					license.unpaid_expiration as unpaidExpiration,
					license.last_ping as lastPing,
					license.license_key as licenseKey,
					account.stripe_customer_id as stripeCustomerId
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
						else callback null, results[0]

		handleLicense = (license, callback) =>
			if not license.isValid
				callback null, {isValid: false, reason: 'License key deactivated'}
			else
				@_checkServerId license, serverId, (error, isValid) =>
					if error? then callback error
					else if not isValid
						callback null, {isValid: false, reason: 'License key already in use by another instance'}
					else if license.type in ['enterprise', 'internal']
						callback null, {isValid: true, licenseType: license.type, trialExpiration: null, unpaidExpiration: null}
					else
						@sqlPool.getConnection (error, connection) =>
							if error? then callback error
							else
								@_checkPayment connection, license, (error, result) =>
									connection.end()
									callback error, result

		getLicense (error, license) =>
			if error? then callback error
			else if not license? then callback null, {isValid: false, reason: 'Invalid license key'}
			else handleLicense license, callback
