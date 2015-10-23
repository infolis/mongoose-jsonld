Fs       = require 'fs'
Async    = require 'async'
test     = require 'tape'
Mongoose = require 'mongoose'
Schemo   = require '../src'
Uuid     = require 'node-uuid'
Utils    = require '../src/utils'

schemoDef = require '../data/infolis-schema.coffee'

schemo = new Schemo(
	mongoose: Mongoose
	baseURI: 'http://www-test.bib-uni-mannheim.de/infolis'
	apiPrefix: '/data'
	schemaPrefix: '/schema'
	expandContexts: ['prefix.cc', {
		rdfs: 'http://www.w3.org/2000/01/rdf-schema#'
		infolis: 'http://www-test.bib-uni-mannheim.de/infolis/schema/'
		infolis_data: 'http://www-test.bib-uni-mannheim.de/infolis/data/'
	}]
	schemo: schemoDef
)

# Publication = factory.createModel(Mongoose, 'Publication', schemaDefinitions.Publication)
# Person = factory.createModel(Mongoose, 'Person', schemaDefinitions.Person)

{Person, Publication} = schemo.models

pub1 = new Publication(
	title: "The Art of Foo"
	type: 'article'
)

testABoxProfile = (t, profile, cb) ->
	pub1.jsonldABox {profile:profile}, (err, data) ->
		t.notOk err, "no error for #{profile}"
		# if profile is 'compact'
		#     console.log data
		#     Fs.writeFileSync 'abox.jsonld', JSON.stringify(data, null, 2)
		t.ok data, "result for #{profile}"
		cb()

testTBoxProfile = (t, profile, cb) ->
	Publication.jsonldTBox {profile: profile}, (err, data) ->
		t.notOk err, "no error for #{profile}"
		t.ok data, "result for #{profile}"
		# console.log data
		# Fs.writeFileSync 'tbox.jsonld', JSON.stringify(data, null, 2)
		cb()

test 'all profiles yield a result (TBox)', (t) ->
	Async.map ['flatten', 'compact', 'expand'], (profile, cb) ->
		testABoxProfile(t, profile, cb)
	, (err, result) -> t.end()

test 'all profiles yield a result (TBox)', (t) ->
	Async.map ['flatten', 'compact', 'expand'], (profile, cb) ->
		testTBoxProfile(t, profile, cb)
	, (err, result) -> t.end()
	# Async.map ['compact'], testTBoxProfile, (err, result) -> t.end()

test 'with and without callbacl', (t) ->
	pub1.jsonldABox {profile: 'expand'}, (err, dataFromCB) ->
		schemo.jsonldRapper.convert pub1.jsonldABox(), 'jsonld', 'jsonld', {profile: 'expand'}, (err, dataFromJ2R) ->
			t.deepEquals dataFromJ2R, dataFromCB, "Callback and return give the same result"
			t.end()

test 'shorten expand with objects', (t) ->
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
		console.log data
		t.notOk err, "No error"
		t.ok (data.indexOf('dc:frobozz dc:fnep ;') > -1), "Contains correct Turtle"
		t.end()

test 'Save flat', (t) ->
	Mongoose.connect('localhost:27018')
	pub1.save (err, saved) ->
		t.notOk err, "No error saving"
		t.ok saved._id, "has an id"
		Mongoose.disconnect()
		t.end()

test 'Validate', (t) ->
	pub2 = new Publication(
		title: 'bar'
		type: '!!invalid on purpose!!'
	)
	pub2.validate (err) ->
		# console.log err
		t.ok err, 'Should have error'
		t.ok err.errors.type, 'should be on "type"'
		t.equals err.errors.type.kind, 'enum', "because value isn't from the enum"
		t.end()

test '_createDocumentFromObject', (t) ->
	Mongoose.connect('localhost:27018')
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
	t.equals pub.author, shouldBeUUID
	pers.save (err, persSaved) ->
		t.notOk err
		t.equals persSaved._id, shouldBeUUID
		pub.save (err, saved) ->
			t.notOk err
			# console.log saved
			# console.log saved.author
			Publication.findOneAndPopulate {_id: pub._id}, (err, found) ->
				t.notOk err
				t.equals found.author._id, shouldBeUUID
				t.equals found.reader.length, 2
				# console.log found.author
				# console.log found
				Mongoose.disconnect()
				t.end()


test '_findOneAndPopulate', (t) ->
	Mongoose.connect('localhost:27018')
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
					Mongoose.disconnect()
					t.end()

	# pub3 = new Publication(pub3_def)
	# console.log pub3.author
	# pub3.validate (err) -> 
	#     console.log err
	# console.log pub3


test 'xx', (t) ->
	console.log pub1.jsonldABox {profile: 'expand'}
	schemo.jsonldTBox {to:'turtle'}, (err, dat) ->
		# utils.dumplog dat
		console.log dat
		t.end()
