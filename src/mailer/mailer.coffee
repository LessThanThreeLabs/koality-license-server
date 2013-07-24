assert = require 'assert'
request = require 'request'
# nodemailer = require 'nodemailer'

LoggerEmailer = require './mailTypes/loggerEmailer'


exports.create = (configurationParams) ->
	createEmailers = () ->
		logger: LoggerEmailer.create configurationParams.logger, emailSender

	# emailSender = nodemailer.createTransport 'smtp',
	# 	service: 'Mailgun'
	# 	auth:
	# 		user: configurationParams.mailgun.user
	# 		pass: configurationParams.mailgun.password
	# 	name: configurationParams.mailgun.name

	emailSender =
		sendMail: (payload, callback) ->
			requestParams =
				uri: "https://api:#{configurationParams.mailgun.apiKey}@api.mailgun.net/v2/koalitycode.com/messages"
				form: payload
				json: true
				strictSSL: true
			request.post requestParams, (error, response, body) ->
				if error? then callback error
				else if body is 'Forbidden' then callback body
				else callback()

	return createEmailers()
