assert = require 'assert'


exports.create = (configurationParams, sqlPool, stripe, logger) ->
	return new LicensePermissionsConnection configurationParams, sqlPool, stripe, logger


class LicensePermissionsConnection
	constructor: (@configurationParams, @sqlPool, @stripe, @logger) ->
		assert.ok @configurationParams? and typeof @configurationParams is 'object'
		assert.ok @sqlPool? and typeof @sqlPool is 'object'
		assert.ok @stripe? and typeof @stripe is 'object'
		assert.ok @logger? and typeof @logger is 'object'


	getPermissionsFromLicenseType: (licenseType, callback) =>
		if licenseType is 'bronze'
			permissions =
				largestInstanceType: 'm1.medium'
				parallelizationCap: 2
				maxRepositoryCount: 3
		else if licenseType is 'silver'
			permissions =
				parallelizationCap: 16
		else if licenseType is 'gold'
			permissions =
				parallelizationCap: 64
		else
			permissions = {}

		callback null, permissions


	getLicensePermissions: (licenseKey, callback) =>
		query = 'SELECT license_permission.name as name, license_permission.value as value FROM license_permission
			INNER JOIN license ON
				license.id = license_permission.license_id
				AND license.license_key = ?'

		@sqlPool.getConnection (error, connection) =>
			if error? then callback error
			else 
				connection.query query, [licenseKey], (error, results) =>
					connection.end()
					if error? then callback error
					else
						permissions = {}
						permissions[result.name] = result.value for result in results
						callback null, permissions


	clearLicensePermissions: (licenseKey, callback) =>
		@sqlPool.getConnection (error, connection) =>
			if error? then callback error
			else 
				connection.query 'DELETE FROM license_permission WHERE license_key = ?', [licenseKey], (error, result) =>
					connection.end()
					callback error, result


	updateLicensePermissions: (licenseKey, permissions, callback) =>
		@sqlPool.getConnection (error, connection) =>
			if error? then callback error
			else 
				connection.query 'SELECT id FROM license WHERE license_key = ?', [licenseKey], (error, results) =>
					connection.end()

					if error? then callback error
					else if results.length isnt 1 then callback 'License key not found'
					else
						licenseId = results[0].id
						
						errors = []
						await
							for name, index in Object.keys permissions
								query = 'INSERT INTO license_permission (license_id, name, value) VALUES (?, ?, ?)
									ON DUPLICATE KEY UPDATE value = ?'

								@sqlPool.getConnection (error, connection) =>
									if error? then errors[index] = error
									else 
										connection.query query, [licenseId, name, permissions[name], permissions[name]], defer errors[index]
										connection.end()

						errors = (error for error in errors when error?)
						if errors.length > 0 then callback errors[0]
						else callback()


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
					connection.query 'UPDATE license SET type = ? WHERE license_key = ?', [newLicenseType, license.licenseKey], (error, results) =>
						connection.end()
						if error? then callback error
						else if results.affectedRows isnt 1 then callback 'License key not found'
						else
							@clearLicensePermissions license.licenseKey, (error) =>
								if error? then callback error
								else @updateLicensePermissions license.licenseKey, permissions, callback

		await 
			@stripe.customers.retrieve license.stripeCustomerId, defer stripeError, stripeCustomer
			@getPermissionsFromLicenseType licenseType, defer permissionsError, permissions

		if stripeError? then callback stripeError
		else if permissionsError? then callback permissionsError
		else
			setLicenseTypeInStripe license, stripeCustomer, (error) =>
				if error? then callback error
				else setLicenseTypeInDb license, permissions, callback
