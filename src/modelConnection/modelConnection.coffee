assert = require 'assert'
mysql = require 'mysql'


exports.create = (configurationParams, logger) ->
	modelConnection = new ModelConnection configurationParams, logger
	modelConnection.initialize()
	return modelConnection


class ModelConnection
	constructor: (@configurationParams, @logger) ->
		assert.ok @configurationParams? and typeof @configurationParams is 'object'
		assert.ok @logger? and typeof @logger is 'object'


	initialize: () =>
		@sqlPool = mysql.createPool @configurationParams.mysqlConnectionParams
