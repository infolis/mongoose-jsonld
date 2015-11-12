Async    = require 'async'
Mongoose = require 'mongoose'
TSON     = require 'tson'
Schemo   = require '../src'
test     = require 'tapes'

log = require('infolis-logging')(module)

schemo = null
db = null

BASEURI = 'http://infolis.gesis.org/infolink'
_connect = ->
	schemo = new Schemo(
		mongoose: Mongoose.createConnection('mongodb://localhost:27018/infolis-web')
		baseURI: BASEURI
		apiPrefix: '/api'
		schemo: TSON.load "#{__dirname}/../../infolis-web/data/infolis.tson"
	)

_disconnect = ->
	schemo.mongoose.close()

test 'ldf-limit', (t) ->
	_connect()
	tripleStream = []
	doc1 = new schemo.models.Execution(
		status:'PENDING'
		algorithm: 'io.github.infolis.algorithm.Indexer'
	)
	doc2 = new schemo.models.Execution(
		status:'PENDING'
		algorithm: 'io.github.infolis.algorithm.Indexer'
	)
	Async.series [
		(cb) -> doc1.save cb
		(cb) ->
			schemo.handlers.ldf.handleLinkedDataFragmentsQuery {subject: doc1.uri(), predicate: 'type'}, tripleStream, (err) ->
				return cb err if err
				t.equals tripleStream.length, 1, 'One type'
				t.equals tripleStream[0].object, BASEURI + '/schema/Execution', 'correct type'
				return cb()
		(cb) ->
			schemo.handlers.ldf.handleLinkedDataFragmentsQuery {object: '"PENDING"'}, tripleStream, (err) ->
				return cb err if err
				t.ok tripleStream.length >= 1, 'At least one PENDING execution'
				return cb()
		(cb) -> doc2.save cb
		(cb) ->
			schemo.handlers.ldf.handleLinkedDataFragmentsQuery {predicate: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'}, tripleStream, (err) ->
				return cb err if err
				t.ok tripleStream.length > 1, 'More than one with rdf:type'
				t.equals tripleStream[0].object, BASEURI + '/schema/Execution', 'correct type'
				return cb()
	], (err) ->
		t.fail "Error: #{err}" if err
		_disconnect()
		t.end()

