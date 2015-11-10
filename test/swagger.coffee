Fs = require 'fs'
Util = require 'util'
Async = require 'async'
test = require 'tapes'
Mongoose = require 'mongoose'
{Schema} = Mongoose
YAML = require 'js-yaml'

Schemo = require '../src'

db = Mongoose.createConnection()

schemo = new Schemo(
	mongoose: db
	baseURL: 'http://www-test.bib-uni-mannheim.de/infolis'
	apiPrefix: '/api/v1'
	expandContext: 'basic'
	schemo: require '../data/infolis-schema'
)
dump = (stuff) ->
	console.log JSON.stringify stuff, null, 2


PublicationModel = schemo.models.Publication

myConsoleLog = (data) ->
	console.log Util.inspect data, { colors: true, depth: 3 }

console.log YAML.safeDump schemo.handlers.swagger.getSwagger({}), {skipInvalid: true}
