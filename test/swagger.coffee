Fs = require 'fs'
Util = require 'util'
Async = require 'async'
test = require 'tapes'
Mongoose = require 'mongoose'
{Schema} = Mongoose
YAML = require 'yamljs'
TSON = require 'tson'

Schemo = require '../src'

db = Mongoose.createConnection()

schemo = new Schemo(
	mongoose: db
	baseURL: 'http://www-test.bib-uni-mannheim.de/infolis'
	apiPrefix: '/api/v1'
	expandContext: 'basic'
	# schemo: TSON.load "#{__dirname}/../data/infolis.tson"
	schemo: require "#{__dirname}/../data/simple-schema"
)
dump = (stuff) ->
	console.log JSON.stringify stuff, null, 2


PublicationModel = schemo.models.Publication

test 'swagger', (t) ->
	schemo.once 'ready', ->
		swagger = schemo.handlers.swagger.getSwagger({})
		t.ok swagger, 'Swagger produced'
		t.end()
