Merge = require 'merge'
JsonLD = require 'jsonld'

idSchema = {
	'@id':
		type: String
}

defaultNS = {
	'dc': {'@id': 'http://xmlns.com/foaf/0.1/'}
	'foaf': {'@id': 'http://xmlns.com/foaf/0.1/'}
}

module.exports = (opts) ->

	plugin: (schema, opts) ->
		opts or= {}

		# TODO
		opts.context or= 'http://prefix.cc/context'

		# store reference to these options for later
		schema._jsonld_opts = opts or {}

		# Every model can have an '@id' field
		schema.add(idSchema)

		# Allow export of the Linked Data description of the schema
		schema.methods.jsonldABox = (opts, cb) ->
			self = @
			opts or= {}
			opts.profile or= 'compact'
			obj = self.toObject()
			# obj['@context'] = Merge(self.schema._jsonld_opts.context, opts.context, obj['@context'])
			obj['@context'] = 'http://prefix.cc/context'
			for schemaPathName, schemaPathDef of self.schema.paths
				# skip internal fields
				continue if /^_/.test schemaPathName
				continue if not schemaPathDef.options?.jsonld
				obj['@context'][schemaPathName] = schemaPathDef.options.jsonld
			console.log obj
			JsonLD.compact obj, {}, cb

		schema.method.jsonldTBox = (opts, cb) ->
			self = @
			opts or= {}
			opts.profile or= 'compact'
			context = Merge(self.schema._jsonld_opts, opts.context)

			for schemaPath in Object.keys self.schema
				console.log schemaPath
			# jsonld.compact obj, context, cb
