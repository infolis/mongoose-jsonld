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

PublicationSchema = new Schema(schemaDefinitions.Publication.schema)
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
	testProfile = (profile, cb) ->
		pub1.jsonldABox {profile:profile}, (err, data) ->
			t.notOk err, "no error for #{profile}"
			t.ok data, "result for #{profile}"
			cb()
	Async.map ['flatten', 'compact', 'expand'], testProfile, (err, result) -> t.end()

PublicationModel.jsonldTBox (err, data) ->
		if err 
			console.log(JSON.stringify(err,null,2))
		else
			console.log(JSON.stringify(data,null,2))
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
