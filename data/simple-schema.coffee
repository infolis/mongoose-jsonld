# {ObjectId} = require('mongoose').Schema
module.exports =
	Person:
		'@context':
			'@id': 'foaf:Person'
		surname:
			'@context':
				'@id': 'foaf:surname'
			type: String
		given:
			'@context':
				'@id': 'foaf:givenName'
			type: String
	Publication:
		'@context':
			'dc:description': 'A publication, see'
			'@type': 'bibo:Document'
		author:
			'@context':
				'@id': 'bibo:author'
			refOne: 'Person'
		reader:
			'@context':
				'@id': 'dc:subject'
				'@container': '@list'
			refMany: 'Person'
		title:
			type: String
			'@context':
				'@id': 'dc:title'
		type:
			'@context':
				'dc:description': "The values are the same as those in citeproc"
				'@id':      'dc:format'
			type: String
			enum: ["article", "book"]
