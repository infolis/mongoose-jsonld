Async    = require 'async'
Mongoose = require 'mongoose'
TSON     = require 'tson'
Schemo   = require '../src'
test     = require 'tapes'

log = require('infolis-logging')(module)

BaseTest = require('./base')

{
	RDF_TYPE
	URI_EXECUTION
	URI_ALGORITHM
} = BaseTest

NR_EXECUTIONS = 0

data2 = data1 =
	status:'PENDING'
	algorithm: 'io.github.infolis.algorithm.Indexer'
doc1 = doc2 = null

DEBUG_METADATA_CALLBACK = (count) -> log.debug "Metadata:", count


class LdfTests extends BaseTest

	constructor: (@t) ->
		# @t.plan(13)

	prepare : (cb) ->
		@schemo = new Schemo(
			mongoose: Mongoose.createConnection('mongodb://localhost:27018/mongoose-test')
			baseURI: @BASEURI
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
		tests = [
			'_handle_s'
			# '_handle_rdftype_sp'
			# '_handle_rdftype_spo'
			# '_handle_rdftype_p'
			# '_handle_rdftype_po'
			# '_handle_sp'
			# '_handle_p'
			#
			# NOT IMPLEMENTED
			# '_handle_none'
			# '_handle_spo'
			# '_handle_so'
			# '_handle_po'
			# '_handle_o'
		]
		@prepare =>
			Async.eachSeries tests, (test, doneTest) =>
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
		log.debug doc1.uri()
		@_test '_handle_s', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) ->
			t.notOk err
			t.equals tripleStream.length, 3
			return cb()

	_handle_rdftype_p : (t, cb) ->
		query = subject: doc1.uri(), predicate: RDF_TYPE
		@_test '_handle_rdftype_p', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) =>
			t.equals tripleStream.length, 1
			t.equals tripleStream[0].object, URI_EXECUTION
			return cb()

	_handle_rdftype_sp : (t, cb) ->
		query = subject: doc1.uri(), predicate: RDF_TYPE
		@_test '_handle_rdftype [sp]', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) ->
			t.equals doc1.uri(), tripleStream[0].subject
			t.equals RDF_TYPE, tripleStream[0].predicate,
			t.equals URI_EXECUTION, tripleStream[0].object
			return cb()

	_handle_rdftype_po : (t, cb) ->
		query = predicate: RDF_TYPE, object: URI_EXECUTION
		@_test '_handle_rdftype_po', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) ->
			t.equals tripleStream[0].object, URI_EXECUTION
			return cb()

	_handle_rdftype_spo : (t, cb) ->
		query = subject: doc1.uri(), predicate: RDF_TYPE, predicate: RDF_TYPE
		@_test '_handle_rdftype [spo]', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) ->
			t.equals tripleStream[0].subject, doc1.uri()
			t.equals tripleStream[0].predicate, RDF_TYPE
			t.equals tripleStream[0].object, URI_EXECUTION
			return cb()

	_handle_sp : (t, cb) ->
		query = subject: doc1.uri(), predicate: URI_ALGORITHM
		@_test '_handle_sp', query, DEBUG_METADATA_CALLBACK, (err, tripleStream) ->
			t.equals tripleStream.length, 1
			t.equals tripleStream[0].object, "\"#{doc1.algorithm}\"^^#{BaseTest.XSD}string"
			return cb()

	_handle_p : (t, cb) ->
		query = predicate: URI_ALGORITHM
		metadataCallback = ({totalCount}) -> t.equals NR_EXECUTIONS, totalCount
		@_test '_handle_p', query, metadataCallback, (err, tripleStream) ->
			log.debug [tripleStream]
			return cb()

test 'LDF Triple Patterns', (t) ->
	log.start('ldf')
	ldfTests = new LdfTests(t)
	ldfTests.run ->
		log.debug "Finished LDF Tests"
		t.end()
		ldfTests.disconnect()
