Fs = require 'fs'
Async = require 'async'
test = require 'tapes'
mongoose = require 'mongoose'
{Schema} = mongoose
{SchemaFactory, MongoosePlugin} = require '../src'
dump = (stuff) ->
	console.log JSON.stringify stuff, null, 2

factory = new SchemaFactory(
	baseURI: 'http://www-test.bib-uni-mannheim.de/infolis'
	apiPrefix: '/data'
	schemaPrefix: '/schema'
	expandContexts: ['prefix.cc', {
		infolis: 'http://www-test.bib-uni-mannheim.de/infolis/schema/'
		infolis_data: 'http://www-test.bib-uni-mannheim.de/infolis/data/'
	}]
)

schemaDefinitions = require '../data/infolis-schema'

PublicationSchema = factory.createSchema('Publication', schemaDefinitions.Publication)
PublicationSchema.plugin(factory.createPlugin())
Publication = mongoose.model('Publication', PublicationSchema)

pub1 = new Publication(
	title: "The Art of Foo"
	type: 'article'
)
# console.log pub1.jsonldABox()
console.log Publication.jsonldTBox()
console.log factory.jsonldRapper.convert Publication.jsonldTBox(), 'jsonld', 'turtle', (err, converted) ->
	console.log converted
# test 'Valid publication', (t) ->
#     pub1.validate (err) ->
#         t.notOk err, 'no validation error'
#         t.end()

# testABoxProfile = (t, profile, cb) ->
#     pub1.jsonldABox {profile:profile}, (err, data) ->
#         t.notOk err, "no error for #{profile}"
#         if profile is 'compact'
#             Fs.writeFileSync 'abox.jsonld', JSON.stringify(data, null, 2)
#         t.ok data, "result for #{profile}"
#         cb()

# testTBoxProfile = (t, profile, cb) ->
#     Publication.jsonldTBox {profile:profile}, (err, data) ->
#         # if err
#         #     console.log JSON.stringify(err, null, 2)
#         t.notOk err, "no error for #{profile}"
#         t.ok data, "result for #{profile}"
#         if profile is 'compact'
#             # console.log JSON.stringify(data, null, 2)
#             Fs.writeFileSync 'tbox.jsonld', JSON.stringify(data, null, 2)
#         cb()

# test 'all profiles yield a result (ABox)', (t) ->
#     Async.map ['flatten', 'compact', 'expand'], ((profile, cb) -> testABoxProfile(t, profile, cb)), (err, result) -> t.end()

# test 'all profiles yield a result (TBox)', (t) ->
#     Async.map ['flatten', 'compact', 'expand'], ((profile, cb) -> testTBoxProfile(t, profile, cb)), (err, result) -> t.end()
#     # Async.map ['compact'], testTBoxProfile, (err, result) -> t.end()

# # console.log Publication.schema.paths.type
# # Publication.jsonldTBox {profile:(err, data) ->
# #         if err 
# #             console.log(JSON.stringify(err,null,2))
# #         else
# #             console.log(JSON.stringify(data,null,2))
# # pub1.jsonldABox {profile: 'flatten'}, (err, data) ->
#     # # console.log data
