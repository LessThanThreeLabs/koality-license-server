fs = require 'fs'


describe 'webserver', () ->

	it 'should successfully load all of the project requires', () ->
		index = fs.readFileSync('libs/index.js').toString()
		
		indexLines = index.split '\n'
		for line in indexLines
			if line.indexOf('= require(\'') isnt -1
				requireText = line.substring line.indexOf('\'') + 1, line.lastIndexOf('\'')

				continue if requireText.indexOf('./') is -1
				require '../libs/' + requireText.substring(2)
