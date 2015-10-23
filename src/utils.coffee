{inspect}      = require 'util'

module.exports = class Utils

	#
	# Regex for matching internal mongoose / mongodb fields
	#
	@INTERNAL_FIELD_REGEX: /^[\$_]/

	@CONTEXT_FIELD_REGEX: /^@context$/

	#
	# @return {string} lower-case the first letter of a string
	#
	@lcfirst : (str) ->
		str.substr(0,1).toLowerCase() + str.substr(1)

	#
	# Everything after the last '/' slash
	#
	@lastUriSegment : (uri) ->
		return uri.substr(uri.lastIndexOf('/') + 1)

	@withoutContext : (def) ->
		out = {}
		for k, v of def
			if k.match(Utils.INTERNAL_FIELD_REGEX.match) or k.match(Utils.CONTEXT_FIELD_REGEX)
				continue
			out[k] = {}
			for kk, vv of v
				if k.match(Utils.INTERNAL_FIELD_REGEX.match) or k.match(Utils.CONTEXT_FIELD_REGEX)
					continue
				out[k][kk] = vv
		return out

	@isJoinMulti : (def) ->
		typeof(def) is 'object' and
		def.type and
		Array.isArray(def.type) and
		def.type[0] and
		typeof def.type[0] is 'object' and
		def.type[0].ref and
		def.type[0].type

	@isJoinSingle : (def) ->
		return typeof(def) is 'object' and
			not(Array.isArray def) and
			def.ref and
			def.type

	@dumplog: (obj) ->
		console.log @dump obj

	@dump: (obj) ->
		inspect obj, {
			depth: 8
			showHidden: false
			colors: true
		}

