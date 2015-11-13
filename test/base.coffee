Async    = require 'async'
Mongoose = require 'mongoose'
TSON     = require 'tson'
Schemo   = require '../src'
test     = require 'tapes'

log = require('infolis-logging')(module)

class Base

	BASEURI: 'http://infolis.gesis.org/infolink'

	connect: ->
		@schemo = new Schemo(
			mongoose: Mongoose.createConnection('mongodb://localhost:27017/test')
			baseURI: @BASEURI
			apiPrefix: '/api'
			schemo: TSON.load "#{__dirname}/../../infolis-web/data/infolis.tson"
		)

	disconnect: ->
		@schemo.mongoose.close()


module.exports = new Base()
