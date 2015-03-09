Fs = require 'fs'
Async = require 'async'
test = require 'tapes'
mongoose = require 'mongoose'
request = require 'supertest'
{Schema} = mongoose
SuperAgent = require 'superagent'

MongoseJSONLD = require '../src'
mongooseJSONLD = new MongoseJSONLD(
	baseURL: 'http://www-test.bib-uni-mannheim.de/infolis'
	apiPrefix: '/api'
	expandContext: 'basic'
)
dump = (stuff) ->
	console.log JSON.stringify stuff, null, 2

schemaDefinitions = require '../data/infolis-schema'
db = mongoose.createConnection()

PublicationSchema = new Schema(schemaDefinitions.Publication.schema, {'@context': schemaDefinitions.Publication.jsonld})
PublicationSchema.plugin(mongooseJSONLD.createMongoosePlugin())
PublicationModel = db.model('Publication', PublicationSchema)

test 'CRUD', (t) ->
	app = require('express')()
	bodyParser = require('body-parser')
	app.use(bodyParser.json())
	mongooseJSONLD.injectRestfulHandlers(app, PublicationModel)
	db.open  'localhost:27018/test'
	db.once 'open', ->
		Async.series [
			(cb) -> 
				request(app)
				.get('/api/v1/publications')
				.end (err, res) ->
					t.equals res.text, '[]', 'No things published yet'
					cb()
			(cb) -> 
				request(app)
				.post '/api/v1/publications'
				.send {'FOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO': 44444444444444343434343434343434343434343333333333333343}
				.end (err, res) ->
					t.equals res.text, '[]', 'No things published yet'
					cb()
		], (err) ->
			db.close()
			t.end()
