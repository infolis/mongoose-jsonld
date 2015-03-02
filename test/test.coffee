mongoose = require 'mongoose'
{Schema} = mongoose
SuperAgent = require 'superagent'

MongooseJsonLD = require '../src'

dump = (stuff) ->
	console.log JSON.stringify stuff, null, 2

schemaDefinitions = require '../infolis-schema'

publicationSchema = new Schema(schemaDefinitions.Publication)
publicationSchema.plugin(MongooseJsonLD().plugin)

publicationModel = mongoose.model('Publication', publicationSchema)

pub1 = new publicationModel(
	'@id': 'foo'
	title: "The Art of Foo"
)

SuperAgent.get('http://prefix.cc/context')
	.set('Accept', 'application/ld+json')
	.end (res) ->
		dump res.status
		dump res.ok
		dump res.text
		dump res.body
		# pub1.jsonldABox {}, (err, bar) ->
			# dump err
			# console.log err.details.cause.details
			# console.log bar
