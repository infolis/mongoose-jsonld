Fs = require 'fs'
Async = require 'async'
test = require 'tapes'
mongoose = require 'mongoose'
{Schema} = mongoose
SuperAgent = require 'superagent'

MongoseJSONLDModule = require '../src'
mongooseJSONLD = MongoseJSONLDModule(
	apiBase: 'http://www-test.bib-uni-mannheim.de/infolis/api'
	expandContext: 'basic'
)

dump = (stuff) ->
	console.log JSON.stringify stuff, null, 2

schemaDefinitions = require '../infolis-schema'

PublicationSchema = new Schema(schemaDefinitions.Publication.schema, {'@context': schemaDefinitions.Publication.jsonld})
PublicationSchema.plugin(mongooseJSONLD.createPlugin)
PublicationModel = mongoose.model('Publication', PublicationSchema)

pub1 = new PublicationModel(
	title: "The Art of Foo"
	type: 'article'
)
test 'Valid publication', (t) ->
	pub1.validate (err) ->
		t.notOk err, 'no validation error'
		t.end()

test 'all profiles yield a result', (t) ->
	testABoxProfile = (profile, cb) ->
		pub1.jsonldABox {profile:profile}, (err, data) ->
			t.notOk err, "no error for #{profile}"
			if profile is 'compact'
				Fs.writeFileSync 'abox.jsonld', JSON.stringify(data, null, 2)
			t.ok data, "result for #{profile}"
			cb()
	testTBoxProfile = (profile, cb) ->
		PublicationModel.jsonldTBox {profile:profile}, (err, data) ->
			if err
				console.log JSON.stringify(err, null, 2)
			t.notOk err, "no error for #{profile}"
			t.ok data, "result for #{profile}"
			if profile is 'compact'
				console.log JSON.stringify(data, null, 2)
				Fs.writeFileSync 'tbox.jsonld', JSON.stringify(data, null, 2)
			cb()
	# Async.map ['flatten', 'compact', 'expand'], testABoxProfile, (err, result) -> t.end()
	Async.map ['flatten', 'compact', 'expand'], testTBoxProfile, (err, result) -> t.end()
	# Async.map ['compact'], testTBoxProfile, (err, result) -> t.end()

# console.log PublicationModel.schema.paths.type
# PublicationModel.jsonldTBox {profile:(err, data) ->
#         if err 
#             console.log(JSON.stringify(err,null,2))
#         else
#             console.log(JSON.stringify(data,null,2))
# pub1.jsonldABox {profile: 'flatten'}, (err, data) ->
	# # console.log data

# pub1.jsonldABox {}, (err, data) -> 
# SuperAgent.get('http://prefix.cc/context')
#     .set('Accept', 'application/ld+json')
#     .end (res) ->
#         dump res.status
#         dump res.ok
#         dump res.text
#         dump res.body
#         # pub1.jsonldABox {}, (err, bar) ->
#             # dump err
#             # console.log err.details.cause.details
#             # console.log bar
