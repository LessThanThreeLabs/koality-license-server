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
		sqlConn.query 'DELETE FROM license_permission WHERE license_key = ?', [licenseKey], callback


	updateLicensePermissions: (licenseKey, permissions, callback) =>
		sqlConn.query 'SELECT id FROM license WHERE license_key = ?', [licenseKey], (error, results) =>
			if error? then callback error
			else if results.length isnt 1 then callback 'License key not found'
			else
				licenseId = results[0].id
				
				errors = []
				await
					for name, value of permissions
						query = 'INSERT INTO license_permission (license_id, name, value) VALUES (?, ?, ?)
							ON DUPLICATE KEY UPDATE value = ?'
						sqlConn.query query, [licenseId, name, value, value], defer permissionsError
						errors.push permissionsError

				errors = (error for error in errors when error?)
				if errors.length > 0 then callback errors[0]
				else callback()
