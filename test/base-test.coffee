Async    = require 'async'
Mongoose = require 'mongoose'
TSON     = require 'tson'
Schemo   = require '../src'
test     = require 'tapes'

log = require('../src/log')(module)

NS = {}
NS.XSD           = 'http://www.w3.org/2001/XMLSchema#'
NS.RDF           = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
NS.RDF_TYPE      = NS.RDF + "type"
NS.BASEURI       = 'http://infolis.gesis.org/infolink'
NS.SCHEMABASE    = 'http://infolis.gesis.org/infolink/schema/'
NS.URI_EXECUTION = NS.SCHEMABASE + "Execution"
NS.URI_ALGORITHM = NS.SCHEMABASE + "algorithm"

module.exports =
	NS: NS
	BaseTest: class BaseTest
		connect: ->
			@schemo = new Schemo(
				mongoose: Mongoose.createConnection('localhost:27018/mongoose-test')
				baseURI: NS.BASEURI
				apiPrefix: '/api'
				schemo: TSON.load "#{__dirname}/../../infolis-web/data/infolis.tson"
			)

		disconnect: ->
			log.info("Closing connection")
			@schemo.mongoose.close()
