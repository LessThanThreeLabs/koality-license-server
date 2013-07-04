assert = require 'assert'


exports.setEnvironmentMode = (mode) ->
	assert.ok mode is 'development' or mode is 'production'
	process.env.NODE_ENV = mode
	