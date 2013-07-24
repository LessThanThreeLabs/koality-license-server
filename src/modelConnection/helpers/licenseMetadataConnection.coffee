assert = require 'assert'


exports.create = (configurationParams, sqlPool, stripe, logger) ->
	return new LicenseMetadataConnection configurationParams, sqlPool, stripe, logger


class LicenseMetadataConnection
	constructor: (@configurationParams, @sqlPool, @stripe, @logger) ->
		assert.ok @configurationParams? and typeof @configurationParams is 'object'
		assert.ok @sqlPool? and typeof @sqlPool is 'object'
		assert.ok @stripe? and typeof @stripe is 'object'
		assert.ok @logger? and typeof @logger is 'object'


	getLicenseMetadata: (licenseKey, callback) =>
		query = 'SELECT license_metadata.name as name,
					license_metadata.value as value
				FROM license_metadata
				INNER JOIN license ON
					license.id = license_metadata.license_id
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


	setLicenseMetadata: (licenseKey, metadata, callback) =>
		getLicense = (callback) =>
			query = 'SELECT license.id as id,
						license.type as type,
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
						else if results.length isnt 1 then callback 'License key not found'
						else
							callback null, results[0]

		updateMetadata = (license) =>
			query = 'INSERT INTO license_metadata (license_id, name, value) VALUES ?
				ON DUPLICATE KEY UPDATE value = VALUES(value)'

			getBulkQueryParams = () =>
				queryParams = []
				for name, value of metadata
					queryParams.push [license.id, name, value]
				return queryParams

			@sqlPool.getConnection (error, connection) =>
				if error? then callback error
				else
					connection.query query, [getBulkQueryParams()], (error) =>
						connection.end()
						if error? then callback error
						else if license.type in ['enterprise', 'internal'] then callback()
						else if not metadata.userCount? then callback()
						else 
							# Stripe gets mad if you try to charge for 0 users
							newQuantity = Math.max metadata.userCount, 1

							@stripe.customers.retrieve license.stripeCustomerId, (error, customer) =>
								if error? then callback error
								else if customer.subscription.quantity is newQuantity then callback()
								else
									planData =
										plan: customer.subscription.plan.id
										quantity: newQuantity
									@stripe.customers.update_subscription license.stripeCustomerId, planData, (error, results) =>
										if error? then callback error
										else callback()

		if Object.keys(metadata).length is 0 then callback()
		else
			getLicense (error, license) =>
				if error? then callback error
				else updateMetadata license
