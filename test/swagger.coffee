Fs = require 'fs'
Util = require 'util'
Async = require 'async'
test = require 'tapes'
Mongoose = require 'mongoose'
{Schema} = Mongoose
YAML = require 'js-yaml'

SchemaFactory = require '../src'
factory = new SchemaFactory(
	mongoose: Mongoose
	baseURL: 'http://www-test.bib-uni-mannheim.de/infolis'
	apiPrefix: '/api/v1'
	expandContext: 'basic'
)
dump = (stuff) ->
	console.log JSON.stringify stuff, null, 2

schemaDefinitions = require '../data/infolis-schema'
db = Mongoose.createConnection()

PublicationSchema = factory.createSchema('Publication', schemaDefinitions.Publication)
PublicationModel = db.model('Publication', PublicationSchema)

myConsoleLog = (data) ->
	console.log Util.inspect data, { colors: true, depth: 3 }

console.log YAML.safeDump factory.getSwagger([PublicationModel]), {skipInvalid: true}
