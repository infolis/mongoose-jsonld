Fs = require 'fs'
Async = require 'async'
test = require 'tapes'
Mongoose = require 'mongoose'
SchemaFactory = require '../src'
dump = (stuff) ->
	console.log JSON.stringify stuff, null, 2

factory = new SchemaFactory(
	baseURI: 'http://www-test.bib-uni-mannheim.de/infolis'
	apiPrefix: '/data'
	schemaPrefix: '/schema'
	expandContexts: ['basic', {
		rdfs: 'http://www.w3.org/2000/01/rdf-schema#'
		infolis: 'http://www-test.bib-uni-mannheim.de/infolis/schema/'
		infolis_data: 'http://www-test.bib-uni-mannheim.de/infolis/data/'
	}]
)

schemaDefinitions = require '../data/infolis-schema'

Publication = factory.createModel(Mongoose, 'Publication', schemaDefinitions.Publication)
Person = factory.createModel(Mongoose, 'Person', schemaDefinitions.Person)

pub1 = new Publication(
	title: "The Art of Foo"
	type: 'article'
)
# Whings
# factory.jsonldRapper.convert pub1.jsonldABox(), 'jsonld', 'turtle', (err, converted) ->
#     console.log converted
# console.log pub1.jsonldABox()
# console.log factory.jsonldRapper
# console.log Publication.jsonldTBox()
# factory.jsonldRapper.convert Publication.jsonldTBox(), 'jsonld', 'turtle', (err, converted) ->
#     console.log converted
# test 'Valid publication', (t) ->
#     pub1.validate (err) ->
#         t.notOk err, 'no validation error'
#         t.end()

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
		factory.jsonldRapper.convert pub1.jsonldABox(), 'jsonld', 'jsonld', {profile: 'expand'}, (err, dataFromJ2R) ->
			t.deepEquals dataFromJ2R, dataFromCB, "Callback and return give the same result"
			t.end()

test 'shorten expand with objects', (t) ->
	FooBarQuux = Mongoose.model 'FooBarQuux',  factory.createSchema('FooBarQuux', {
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
	})
	# console.log FooBarQuux.jsonldTBox()
	FooBarQuux.jsonldTBox {to:'turtle'}, (err, data) ->
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
		t.ok err, 'Should have error'
		t.ok err.errors.type, 'should be on "type"'
		t.equals err.errors.type.type, 'enum', "because value isn't from the enum"
		t.end()

test 'Save nested', (t) ->
	Mongoose.connect('localhost:27018')
	author = new Person
		surname: 'Doe'
		given: 'John'
	pub = new Publication
		title: 'Foo!'
	author.save (err) ->
		pub.author.push author._id
		pub.save (err) -> 
			Publication
				.findOne _id: pub._id
				.populate('author')
				.exec (err, found) ->
					# Publication.jsonldTBox { to: 'text/turtle' }, (err, rdf) ->
					found.jsonldABox { to: 'turtle' }, (err, rdf) ->
					# found.jsonldABox { to: 'jsonld' }, (err, rdf) ->
					 # console.log found.jsonldABox()
					# console.log JSON.stringify(found.jsonldABox(), null, 2)
					# found.jsonldABox (err, rdf) ->
						console.log err
						console.log rdf
						# console.log JSON.stringify(rdf, null, 2)
						Mongoose.disconnect()
						t.end()

	# pub3 = new Publication(pub3_def)
	# console.log pub3.author
	# pub3.validate (err) -> 
	#     console.log err
	# console.log pub3



# # console.log Publication.schema.paths.type
# # Publication.jsonldTBox {profile:(err, data) ->
# #         if err 
# #             console.log(JSON.stringify(err,null,2))
# #         else
# #             console.log(JSON.stringify(data,null,2))
# console.log pub1.jsonldABox {profile: 'expand'}
