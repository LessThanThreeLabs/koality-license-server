assert = require 'assert'


exports.create = (configurationParams, sqlPool, stripe, logger) ->
	return new LicenseTypeConnection configurationParams, sqlPool, stripe, logger


class LicenseTypeConnection
	constructor: (@configurationParams, @sqlPool, @stripe, @logger) ->
		assert.ok @configurationParams? and typeof @configurationParams is 'object'
		assert.ok @sqlPool? and typeof @sqlPool is 'object'
		assert.ok @stripe? and typeof @stripe is 'object'
		assert.ok @logger? and typeof @logger is 'object'


	setLicenseType: (licenseKey, licenseType, callback) =>
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
			sqlConn.query 'UPDATE license SET type = ? WHERE license_key = ?', [newLicenseType, license.licenseKey], (error, results) =>
				if error? then callback error
				else if results.affectedRows isnt 1 then callback 'License key not found'
				else
					clearLicensePermissions license.licenseKey, (error) =>
						if error? then callback error
						else updateLicensePermissions license.licenseKey, permissions, callback

		@getLicenseFromKey licenseKey, (error, license) =>
			if error? then callback error
			else
				await 
					@stripe.customers.retrieve license.stripeCustomerId, defer stripeError, stripeCustomer
					@getPermissionsFromLicenseType licenseType, defer permissionsError, permissions

				if stripeError? then callback stripeError
				else if permissionsError? then callback permissionsError
				else
					setLicenseTypeInStripe license, stripeCustomer, (error) =>
						if error? then callback error
						else setLicenseTypeInDb license, permissions, callback
