Async    = require 'async'
Mongoose = require 'mongoose'
TSON     = require 'tson'
Schemo   = require '../src'
test     = require 'tapes'

log = require('infolis-logging')(module)

class Base

	@XSD: 'http://www.w3.org/2001/XMLSchema#'
	@RDF: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
	@RDF_TYPE = Base.RDF + "type"
	@BASEURI: 'http://infolis.gesis.org/infolink'
	@SCHEMABASE:'http://infolis.gesis.org/infolink/schema/'
	@URI_EXECUTION = Base.SCHEMABASE + "Execution"
	@URI_ALGORITHM = Base.SCHEMABASE + "algorithm"

	connect: ->
		@schemo = new Schemo(
			mongoose: Mongoose.createConnection('localhost:27018/mongoose-test')
			baseURI: @Base.BASEURI
			apiPrefix: '/api'
			schemo: TSON.load "#{__dirname}/../../infolis-web/data/infolis.tson"
		)

	disconnect: ->
		log.info("Closing connection")
		@schemo.mongoose.close()


module.exports = Base
