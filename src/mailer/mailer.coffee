assert = require 'assert'
nodemailer = require 'nodemailer'

LoggerEmailer = require './mailTypes/loggerEmailer'


exports.create = (configurationParams) ->
	createEmailers = () ->
		logger: LoggerEmailer.create configurationParams.logger, emailSender

	emailSender = nodemailer.createTransport 'smtp',
		service: 'Mailgun'
		auth:
			user: configurationParams.mailgun.user
			pass: configurationParams.mailgun.password
		tls:
			ciphers: 'SSLv3'

	return createEmailers()
