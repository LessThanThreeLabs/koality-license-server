require 'longjohn'

fs = require 'fs'
Logger = require 'koality-logger'

environment = require './environment'

ModelConneciton = require './modelConnection/modelConnection'
CommandLineParser = require './commandLineParser'
Mailer = require './mailer/mailer'
PrivateServer = require './server/privateServer'
PublicServer = require './server/publicServer'

startEverything = () ->
	commandLineParser = CommandLineParser.create()

	configurationParams = getConfiguration commandLineParser.getConfigFile(), 
		commandLineParser.getMode(),
		commandLineParser.getPrivatePort(),
		commandLineParser.getPublicPort()

	environment.setEnvironmentMode configurationParams.mode

	mailer = Mailer.create configurationParams.mailer

	loggerPrintLevel = if process.env.NODE_ENV is 'production' then 'info' else 'warn'
	logger = Logger.create mailer.logger, 'warn', loggerPrintLevel

	process.on 'uncaughtException', (error) ->
		logger.error error, true
		setTimeout (() -> process.exit 1), 10000

	modelConnection = ModelConneciton.create configurationParams.modelConnection, logger

	privateServer = PrivateServer.create configurationParams.server.private, modelConnection, logger
	privateServer.start()

	publicServer = PublicServer.create configurationParams.server.public, modelConnection, logger
	publicServer.start()


getConfiguration = (configFileLocation = './config.json', mode, privatePort, publicPort) ->
	config = JSON.parse(fs.readFileSync configFileLocation, 'ascii')
	if mode? then config.mode = mode
	if privatePort? then config.server.private.port = privatePort
	if publicPort? then config.server.public.port = publicPort
	return Object.freeze config


startEverything()
