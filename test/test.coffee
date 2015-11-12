Fs       = require 'fs'
Async    = require 'async'
test     = require 'tape'
Mongoose = require 'mongoose'
Schemo   = require '../src'
Uuid     = require 'node-uuid'
Utils    = require '../src/utils'
{inspect}  = require 'util'

ignore = ->

schemo = null
_connect = ->
	schemo = new Schemo(
		mongoose: Mongoose.createConnection('mongodb://localhost:27018/test')
		baseURI: 'http://www-test.bib-uni-mannheim.de/infolis'
		apiPrefix: '/data'
		schemaPrefix: '/schema'
		expandContexts: ['basic', {
			rdfs: 'http://www.w3.org/2000/01/rdf-schema#'
			infolis: 'http://www-test.bib-uni-mannheim.de/infolis/schema/'
			infolis_data: 'http://www-test.bib-uni-mannheim.de/infolis/data/'
		}]
		schemo: require '../data/simple-schema.coffee'
	)
_disconnect = -> schemo.mongoose.close()

test 'sanity mongoose instance check', (t) ->
	# _connect()
	# t.equals new schemo.mongoose.base.constructor, Mongoose
	# _disconnect()
	t.end()

# Publication = factory.createModel(Mongoose, 'Publication', schemaDefinitions.Publication)
# Person = factory.createModel(Mongoose, 'Person', schemaDefinitions.Person)

testABoxProfile = (t, profile, cb) ->
	pub1 = new schemo.models.Publication(title: "The Art of Foo", type: 'article')
	pub1.jsonldABox {profile:profile}, (err, data) ->
		t.notOk err, "no error for #{profile}"
		# if profile is 'compact'
		#     console.log data
		#     Fs.writeFileSync 'abox.jsonld', JSON.stringify(data, null, 2)
		t.ok data, "result for #{profile}"
		cb()

testTBoxProfile = (t, profile, cb) ->
	schemo.models.Publication.jsonldTBox {profile: profile}, (err, data) ->
		t.notOk err, "no error for #{profile}"
		t.ok data, "result for #{profile}"
		# console.log data
		# Fs.writeFileSync 'tbox.jsonld', JSON.stringify(data, null, 2)
		cb()

test 'all profiles yield a result (TBox)', (t) ->
	_connect()
	Async.map ['flatten', 'compact', 'expand'], (profile, cb) ->
		testABoxProfile(t, profile, cb)
	, (err, result) -> 
		_disconnect()
		t.end()

test 'all profiles yield a result (TBox)', (t) ->
	_connect()
	Async.map ['flatten', 'compact', 'expand'], (profile, cb) ->
		testTBoxProfile(t, profile, cb)
	, (err, result) -> 
		_disconnect()
		t.end()
	# Async.map ['compact'], testTBoxProfile, (err, result) -> t.end()

test 'with and without callbacl', (t) ->
	_connect()
	pub1 = new schemo.models.Publication(title: "The Art of Foo", type: 'article')
	pub1.jsonldABox {profile: 'expand'}, (err, dataFromCB) ->
		schemo.jsonldRapper.convert pub1.jsonldABox(), 'jsonld', 'jsonld', {profile: 'expand'}, (err, dataFromJ2R) ->
			t.deepEquals dataFromJ2R, dataFromCB, "Callback and return give the same result"
			_disconnect()
			t.end()

test 'shorten expand with objects', (t) ->
	_connect()
	schemo.addClass 'FooBarQuux', {
		'@context':
			'dc:foo':
				'@id': 'dc:bar'
			'dc:quux':
				'@id': 'dc:froop'
		blork:
			'@context':
				'dc:frobozz':
					'@id': 'dc:fnep'
			type: 'String'
	}
	# console.log FooBarQuux.jsonldTBox()
	schemo.models.FooBarQuux.jsonldTBox {to:'turtle'}, (err, data) ->
		t.notOk err, "No error"
		t.ok (data.indexOf('dc:frobozz dc:fnep ;') > -1), "Contains correct Turtle"
		_disconnect()
		t.end()

test 'Save flat', (t) ->
	_connect()
	pub1 = new schemo.models.Publication(title: "The Art of Foo", type: 'article')
	pub1.save (err, saved) ->
		t.notOk err, "No error saving"
		t.ok saved._id, "has an id"
		_disconnect()
		t.end()

test 'Validate', (t) ->
	pub2 = new schemo.models.Publication(
		title: 'bar'
		type: '!!invalid on purpose!!'
	)
	pub2.validate (err) ->
		# console.log err
		t.ok err, 'Should have error'
		t.ok err.errors.type, 'should be on "type"'
		t.equals err.errors.type.kind, 'enum', "because value isn't from the enum"
		t.end()

test 'filter_predicate', (t) ->
	_connect()
	{Publication} = schemo.models
	pub = new Publication(title:'foo', type:'book')
	pub.save (err) ->
		Async.series [
			(cb) -> pub.jsonldABox {filter_predicate:['title']}, (err, data) ->
				t.notOk data.type, 'type should be filtered out'
				cb()
			(cb) -> pub.jsonldABox {filter_predicate:['http://foo/title']}, (err, data) ->
				t.notOk data.type, 'here as well'
				cb()
		], () ->
			_disconnect()
			t.end()

ignore '_createDocumentFromObject', (t) ->
	_connect()
	{Person, Publication} = schemo.models
	shouldBeUUID = Uuid.v4()
	pers = new Person 
		given: "Slog"
		_id: shouldBeUUID
	# console.log pers.uri()
	pub = Publication.fromJSON
		_id: Uuid.v1()
		title: 'Bar!'
		author: pers.uri()
		reader: [pers.uri(), shouldBeUUID, Uuid.v4()]
	t.equals pub.author, shouldBeUUID, "Publication author should be uuid of author"
	pers.save (err, persSaved) ->
		t.notOk err, "No error"
		t.equals persSaved._id, shouldBeUUID, "Person saved ID as expected"
		pub.save (err, saved) ->
			t.notOk err, "No error"
			# console.log saved
			# console.log saved.author
			Publication.findOneAndPopulate {_id: pub._id}, (err, found) ->
				t.notOk err, "No error"
				t.ok found.author, "Populated author field"
				t.equals found.author._id, shouldBeUUID, "Author uuid as expected"
				t.ok found.reader, "Populated reader field"
				if found.reader
					t.equals found.reader.length, 2
				# console.log found.author
				# console.log found
				_disconnect()
				t.end()


ignore '_findOneAndPopulate', (t) ->
	_connect()
	{Person, Publication} = schemo.models
	author = new Person
		surname: 'Doe'
		given: 'John'
	pub = new Publication
		title: 'Foo!'
	author.save (err) ->
		pub.author = author._id
		for i in [0...3]
			pub.reader.push author._id
		pub.save (err) ->
			Publication.findOneAndPopulate pub, (err, found) ->
				found.jsonldABox {to:'turtle'}, (err, rdf) ->
					t.equals rdf.split(author.uri()).length, 6
					_disconnect()
					t.end()

	# pub3 = new Publication(pub3_def)
	# console.log pub3.author
	# pub3.validate (err) -> 
	#     console.log err
	# console.log pub3


test 'convert to turtle', (t) ->
	_connect()
	pub1 = new schemo.models.Publication(title: "The Art of Foo", type: 'article')
	# console.log pub1.jsonldABox {profile: 'expand'}
	schemo.jsonldTBox {to:'turtle'}, (err, dat) ->
		t.ok dat
		# Utils.dumplog dat
		# console.log dat
		_disconnect()
		t.end()
