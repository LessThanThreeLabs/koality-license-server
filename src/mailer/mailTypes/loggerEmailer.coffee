assert = require 'assert'

Emailer = require './emailer'


exports.create = (configurationParams, emailSender) ->
	return new LoggerEmailer configurationParams, emailSender


class LoggerEmailer extends Emailer
	send: (body, callback) =>
		payload =
			from: "#{@configurationParams.from.name} <#{@configurationParams.from.email}>"
			to: @configurationParams.to.email
			subject: 'Logs'
			text: body

		if process.env.NODE_ENV is 'production'
			@emailSender.sendMail payload, callback
		else
			console.log 'Not sending logger email while in development mode'
