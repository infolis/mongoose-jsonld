Async    = require 'async'
Mongoose = require 'mongoose'
TSON     = require 'tson'
Schemo   = require '../src'
test     = require 'tapes'

log = require('infolis-logging')(module)

base = require('./base')

data2 = data1 =
	status:'PENDING'
	algorithm: 'io.github.infolis.algorithm.Indexer'

test 'ldf-limit', (t) ->
	base.connect()
	tripleStream = []
	doc1 = new base.schemo.models.Execution(data1)
	doc2 = new base.schemo.models.Execution(data2)
	log.start('ldf')
	Async.series [
		(cb) ->
			log.start('save')
			doc1.save ->
				log.logstop('save')
				cb.apply(this, arguments)
		(cb) ->
			log.start('ensureIndexes')
			base.schemo.models.Execution.ensureIndexes (err) ->
				log.logstop('ensureIndexes')
				log.error err if err
				cb.apply(this, arguments)
		(cb) ->
			title = 'subject+predicate [type]'
			log.start title
			base.schemo.handlers.ldf.handleLinkedDataFragmentsQuery {subject: doc1.uri(), predicate: 'type'}, tripleStream, (err) ->
				return cb err if err
				log.logstop title
				t.equals tripleStream.length, 1, title
				t.equals tripleStream[0].object, base.BASEURI + '/schema/Execution', 'correct type'
				return cb()
		(cb) ->
			title = 'subject+predicate [algorithm]'
			log.start(title)
			base.schemo.handlers.ldf.handleLinkedDataFragmentsQuery {subject: doc1.uri(), predicate: 'algorithm'}, tripleStream, (err) ->
				return cb err if err
				log.logstop(title)
				log.debug tripleStream
				t.equals tripleStream.length, 1, title
				return cb()
		(cb) ->
			title = 'object [PENDING]'
			log.start(title)
			base.schemo.handlers.ldf.handleLinkedDataFragmentsQuery {object: '"PENDING"'}, tripleStream, (err) ->
				log.logstop(title)
				return cb err if err
				t.ok tripleStream.length >= 1, 'At least one PENDING execution'
				return cb()
		(cb) ->
			log.start('save')
			doc2.save ->
				log.logstop('save')
				cb.apply(this, arguments)
		(cb) ->
			title = 'predicate [algorithm]'
			log.start(title)
			base.schemo.handlers.ldf.handleLinkedDataFragmentsQuery {predicate: 'foo.bar/algorithm'}, tripleStream, (err) ->
				log.logstop(title)
				return cb err if err
				t.ok tripleStream.length > 1, 'More than one with algorithm'
				return cb()
		(cb) ->
			title = "predicate [rdf:type]"
			log.start(title)
			base.schemo.handlers.ldf.handleLinkedDataFragmentsQuery {predicate: 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type'}, tripleStream, (err) ->
				return cb err if err
				log.logstop(title)
				t.ok tripleStream.length > 1, 'More than one with rdf:type'
				t.equals tripleStream[0].object, base.BASEURI + '/schema/Execution', 'correct type'
				return cb()
	], (err) ->
		t.fail "Error: #{err}" if err
		log.logstop('ldf')
		base.disconnect()
		t.end()

