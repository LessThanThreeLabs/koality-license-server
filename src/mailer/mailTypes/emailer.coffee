assert = require 'assert'


module.exports = class Emailer
	constructor: (@configurationParams, @emailSender) ->
		assert.ok @configurationParams?
		assert.ok @emailSender?
