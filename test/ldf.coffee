Mongoose = require 'mongoose'
TSON = require 'tson'
Schemo = require '../src'
test = require 'tapes'

schemo = null
db = null

_connect = ->
	schemo = new Schemo(
		mongoose: Mongoose.createConnection('mongodb://localhost:27018/infolis-web')
		baseURI: 'http://infolis.gesis.org/infolink'
		apiPrefix: '/api'
		expandContext: 'basic'
		schemo: TSON.load "#{__dirname}/../../infolis-web/data/infolis.tson"
	)

_disconnect = ->
	schemo.mongoose.close()

test 'ldf', (t) ->
	_connect()
	tripleStream = []
	ldfQuery = {
		subject: 'http://infolis.gesis.org/infolink/api/entity/feedad30-7ccc-11e5-9b91-89b7ea6546e3'
	}
	schemo.handlers.ldf.handleLinkedDataFragmentsQuery ldfQuery, tripleStream, (err) ->
		# console.log "Triplestream:"
		console.log tripleStream.length
		_disconnect()
		t.end()
