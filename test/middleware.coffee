Fs = require 'fs'
Async = require 'async'
test = require 'tapes'
Mongoose = require 'mongoose'
request = require 'supertest'
SuperAgent = require 'superagent'
TSON = require 'tson'

Schemo = require '../src'

db = Mongoose.createConnection()

schemo = new Schemo(
	mongoose: db
	baseURL: 'http://www-test.bib-uni-mannheim.de/infolis'
	apiPrefix: '/api/v1'
	expandContext: 'basic'
	# schemo: TSON.load "#{__dirname}/../data/simple-schema.tson"
	schemo: require "#{__dirname}/../data/simple-schema"
)

PublicationSchema = schemo.schemas.Publication
PublicationModel = schemo.models.Publication

titles = [
	'test1'
	'test2'
	'test3'
]

test 'CRUD', (t) ->
	app = require('express')()
	bodyParser = require('body-parser')
	app.use(bodyParser.json())
	schemo.handlers.restful.inject(app)
	db.open 'localhost:27018/test'
	id = null
	db.once 'open', ->
		Async.series [

			(cb) ->
				request(app)
				.delete('/api/v1/publication/!!')
				.end (err, res) ->
					t.equals res.statusCode, 200, "DELETE /!! 200"
					cb()

			(cb) ->
				request(app)
				.post '/api/v1/publication'
				.send {'title': 'The Art of Kung-Foo'}
				.end (err, res) ->
					t.equals res.statusCode, 201, 'POST / 201'
					id = res.body._id
					request(app)
					.get "/api/v1/publication/#{id}"
					.accept('text/turtle')
					.end (err, res) ->
						t.ok res.text.indexOf('@prefix') > -1, 'Converted to Turtle'
						t.ok res.headers['content-type'].indexOf('text/turtle') > -1, 'Correct content-type'
						t.equals res.statusCode, 200, 'GET /:id 200'
						t.comment("Waiting a second to test timestamps")
						setTimeout ->
							request(app)
							.get "/api/v1/publication/#{id}"
							.end (err, res) ->
								t.equals res.body.resource_modified, res.body.resource_created
								cb()
						, 1000

			(cb) ->
				request(app)
				.get "/api/v1/publication/64fd946ceaa8dd8e5d2e202e"
				.end (err, res) ->
					t.equals res.statusCode, 404, 'GET /:id 404'
					cb()

			(cb) ->
				request(app)
				.put "/api/v1/publication/#{id}"
				.send {title: 'Bars and Quuxes'}
				.end (err, res) ->
					t.equals res.statusCode, 201, 'PUT /:id 201'
					request(app)
					.get "/api/v1/publication/#{id}"
					.end (err, res) ->
						t.equals res.body.title, 'Bars and Quuxes', 'Title updated'
						t.notEquals res.body.resource_modified, res.body.resource_created, 'time diverged'
						t.equals res.statusCode, 200, 'GET /:id 200'
						cb()
			
			(cb) ->
				# POST dummy data
				Async.each titles, (title, postCB) ->
					request(app)
					.post '/api/v1/publication'
					.send {title: title}
					.end (err, res) ->
						t.equals res.statusCode, 201, "POST / [title=#{title}]"
						postCB()
				, (err) ->
					request(app)
					.get "/api/v1/publication?q=title:#{titles[0]}"
					.end (err, res) ->
						t.equals res.body.length, 1, 'Found exactly one with matching title'
						cb()

			(cb) ->
				request(app)
				.delete('/api/v1/publication/!!')
				.accept('text/turtle')
				.end (err, res) ->
					t.equals res.statusCode, 200, "DELETE /!! 200"
					request(app)
					.get "/api/v1/publication/"
					.end (err, res) ->
						t.equals res.body.length, 0, 'No more docs after delete'
						cb()

		], (err) ->
			console.log err if err
			db.close()
			t.end()
