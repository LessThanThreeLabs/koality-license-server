assert = require 'assert'
crypto = require 'crypto'


exports.create = () ->
	return new LicenseKeySanitizer()


class LicenseKeySanitizer

	getSanitizedKey: (licenseKey) =>
		if licenseKey?
			return licenseKey.replace(/[^a-zA-Z0-9]/g, '').toUpperCase()
		else
			return null
