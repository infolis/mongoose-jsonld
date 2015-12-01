Async    = require 'async'
Mongoose = require 'mongoose'
TSON     = require 'tson'
Schemo   = require '../src'
test     = require 'tapes'

log = require('infolis-logging')(module)

{NS, BaseTest} = require('./base-test')

ALL_TESTS = [

	# Neither S nor P nor O
	'_handle_none'

	# Pattern
	'_handle_s'
	'_handle_sp'
	'_handle_spo'
	'_handle_so'
	'_handle_p'
	'_handle_po'
	'_handle_o'

	# Special case
	'_handle_rdftype_sp'
	'_handle_rdftype_spo'
	'_handle_rdftype_p'
	'_handle_rdftype_po'
	'_handle_rdftype_so'
	'_handle_rdftype_o'

	# NOT IMPLEMENTED
	# '_handle_number'
	# '_handle_uri'
	# '_handle_boolean'

]

NR_EXECUTIONS = 0

data2 = data1 =
	status:'PENDING'
	algorithm: 'io.github.infolis.algorithm.Indexer'
doc1 = doc2 = null

DEBUG_METADATA_CALLBACK = (metadata) ->
	log.debug "Metadata:", metadata
	throw new Error("No totalCount!") if typeof metadata.totalCount isnt 'number' or Number.isNaN(metadata.totalCount)
	throw new Error("No nrFound!") if typeof metadata.nrFound isnt 'number' or Number.isNaN(metadata.nrFound) or metadata.nrFound <= 0


class LdfTests extends BaseTest

	constructor: (@t) ->
		# @t.plan(13)

	prepare : (cb) ->
		@schemo = new Schemo(
			mongoose: Mongoose.createConnection('mongodb://localhost:27018/mongoose-test')
			baseURI: NS.BASEURI
			apiPrefix: '/api'
			schemo: TSON.load "#{__dirname}/../../infolis-web/data/infolis.tson"
		)
		doc1 = new @schemo.models.Execution(data1)
		doc2 = new @schemo.models.Execution(data2)
		@schemo.on 'ready', =>
			log.start('save')
			doc1.save (err) =>
				log.error err if err
				log.logstop('save')
				log.start('count')
				@schemo.models.Execution.count (err,nr) ->
					log.logstop('count')
					NR_EXECUTIONS = nr
					log.info "PREPARED"
					cb()

	run : (cb) -> 
		@prepare =>
			Async.eachSeries ALL_TESTS, (test, doneTest) =>
				if test not of @
					throw new Error("Test not implemented #{test}")
				@[test].apply(@, [@t, doneTest])
			, (err, doneTests) ->
				log.debug "Finished tests"
				cb()

	_test : (title, query, metadataCallback, cb) ->
		tripleStream = []
		log.start title
		@schemo.handlers.ldf.handleLDFQuery query, tripleStream, metadataCallback, (err) ->
			log.logstop title
			return cb err if err
			return cb null, tripleStream

	_handle_s : (t, cb) ->
		query = subject: doc1.uri()
		@_test '_handle_s', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) ->
			t.notOk err
			t.equals tripleStream.length, 3
			return cb()

	_handle_rdftype_p : (t, cb) ->
		query = predicate: NS.RDF_TYPE
		metadataCallback = ({totalCount, nrFound}) ->
			t.equals totalCount, NR_EXECUTIONS
			t.equals nrFound, 10
		@_test '_handle_rdftype [p]', query, metadataCallback, (err, tripleStream) =>
			t.equals tripleStream.length, 10
			t.equals tripleStream[0].object, NS.URI_EXECUTION
			return cb()

	_handle_rdftype_sp : (t, cb) ->
		query = subject: doc1.uri(), predicate: NS.RDF_TYPE
		@_test '_handle_rdftype [sp]', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) ->
			t.equals doc1.uri(), tripleStream[0].subject
			t.equals NS.RDF_TYPE, tripleStream[0].predicate,
			t.equals NS.URI_EXECUTION, tripleStream[0].object
			return cb()

	_handle_rdftype_so : (t, cb) ->
		query = subject: doc1.uri(), object: NS.URI_EXECUTION
		@_test '_handle_rdftype [so]', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) ->
			t.equals tripleStream.length, 1
			t.equals tripleStream[0].subject, doc1.uri()
			t.equals tripleStream[0].predicate, NS.RDF_TYPE
			t.equals tripleStream[0].object, NS.URI_EXECUTION
			return cb()

	_handle_rdftype_po : (t, cb) ->
		query = predicate: NS.RDF_TYPE, object: NS.URI_EXECUTION
		@_test '_handle_rdftype [po]', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) ->
			t.equals tripleStream[0].object, NS.URI_EXECUTION
			return cb()

	_handle_rdftype_spo : (t, cb) ->
		query = subject: doc1.uri(), predicate: NS.RDF_TYPE, type: NS.URI_EXECUTION
		@_test '_handle_rdftype [spo]', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) ->
			t.equals tripleStream[0].subject, doc1.uri()
			t.equals tripleStream[0].predicate, NS.RDF_TYPE
			t.equals tripleStream[0].object, NS.URI_EXECUTION
			return cb()

	_handle_rdftype_o : (t, cb) ->
		query = object: NS.URI_EXECUTION
		@_test '_handle_rdftype [o]', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) ->
			t.equals tripleStream[0].predicate, NS.RDF_TYPE
			t.equals tripleStream[0].object, NS.URI_EXECUTION
			return cb()

	_handle_sp : (t, cb) ->
		query = subject: doc1.uri(), predicate: NS.URI_ALGORITHM
		metadataCallback = ({totalCount, nrFound}) ->
			t.equals 1, totalCount
			t.equals 1, nrFound
		@_test '_handle_sp', query, metadataCallback, (err, tripleStream) ->
			t.equals tripleStream.length, 1
			t.equals tripleStream[0].object, "\"#{doc1.algorithm}\"^^#{NS.XSD}string"
			return cb()

	_handle_spo : (t, cb) ->
		query = subject: doc1.uri(), predicate: NS.URI_ALGORITHM, object: doc1.algorithm
		metadataCallback = ({totalCount, nrFound}) ->
			t.equals 1, totalCount
			t.equals 1, nrFound
		@_test '_handle_spo', query, metadataCallback, (err, tripleStream) ->
			t.equals tripleStream[0].subject, doc1.uri()
			t.equals tripleStream[0].predicate, NS.URI_ALGORITHM
			t.equals tripleStream[0].object, "\"#{doc1.algorithm}\"^^#{NS.XSD}string"
			return cb()

	_handle_p : (t, cb) ->
		query = predicate: NS.URI_ALGORITHM
		metadataCallback = ({totalCount, nrFound}) ->
			t.ok totalCount > 10
			t.equals nrFound, 10
		@_test '_handle_p', query, metadataCallback, (err, tripleStream) ->
			return cb()

	_handle_po : (t, cb) ->
		query = predicate: NS.URI_ALGORITHM, object: doc1.algorithm
		metadataCallback = ({totalCount, nrFound}) ->
			t.equals totalCount, NR_EXECUTIONS
			t.equals nrFound, 10
		@_test '_handle_po', query, metadataCallback, (err, tripleStream) ->
			t.equals tripleStream[0].predicate, NS.URI_ALGORITHM
			t.equals tripleStream[0].object, "\"#{doc1.algorithm}\"^^#{NS.XSD}string"
			return cb()

	_handle_so : (t, cb) ->
		query = subject: doc1.uri(), object: doc1.algorithm
		@_test '_handle_po', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) ->
			t.equals tripleStream[0].predicate, NS.URI_ALGORITHM
			t.equals tripleStream[0].object, "\"#{doc1.algorithm}\"^^#{NS.XSD}string"
			return cb()

	_handle_o : (t, cb) ->
		query = object: doc1.algorithm
		@_test '_handle_o', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) ->
			t.equals tripleStream[0].predicate, NS.URI_ALGORITHM
			t.equals tripleStream[0].object, "\"#{doc1.algorithm}\"^^#{NS.XSD}string"
			return cb()

	_handle_none : (t, cb) ->
		query = {}
		metadataCallback = ({totalCount, nrFound}) ->
			t.equals totalCount, NR_EXECUTIONS
			t.equals nrFound, 10
		# metadataCallback = DEBUG_METADATA_CALLBACK
		@_test '_handle_none', query, metadataCallback, (err, tripleStream) ->
			t.ok tripleStream.length > 1
			return cb()

test 'LDF Triple Patterns', (t) ->
	log.start('ldf')
	ldfTests = new LdfTests(t)
	ldfTests.run ->
		log.debug "Finished LDF Tests"
		t.end()
		ldfTests.disconnect()
