assert = require 'assert'
commander = require 'commander'


exports.create = () ->
	commandLineParser = new CommandLineParser
	commandLineParser.initialize()
	return commandLineParser


class CommandLineParser
	initialize: () =>
		commander.version('0.1.0')
			.option('--mode <development/production>', 'The mode to use')
			.option('--privatePort <n>', 'The https port to use for the private server', parseInt)
			.option('--publicPort <n>', 'The https port to use for the public server', parseInt)
			.option('--configFile <file>', 'The configuration file to use')
			.parse(process.argv)


	getMode: () =>
		return commander.mode


	getPrivatePort: () =>
		return commander.privatePort


	getPublicPort: () =>
		return commander.publicPort


	getConfigFile: () =>
		return commander.configFile
