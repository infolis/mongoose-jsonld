Merge = require 'merge'
Mongoose = require 'mongoose'
Validators = require './validators'
TypeMap = require './typemap'
CommonContexts = require 'jsonld-common-contexts'

module.exports = class MongooseJsonLD

	constructor: (opts) ->
		opts or= {}
		@[k] = v for k,v of opts

			# schema.statics.create =  (doc, cb) ->
			#     for __, path of @schema.paths
			#         dbRef = path.options.type
			#         if Array.isArray dbRef
			#             pathType = dbRef[0].type
			#             pathRef = dbRef[0].ref
			#             console.log pathType
			#             console.log pathRef
			#     console.log doc
			#     next()
