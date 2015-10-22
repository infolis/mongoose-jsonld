# {ObjectId} = require('mongoose').Schema
module.exports =
	Person:
		'@context':
			'@id': 'foaf:Person'
		surname:
			type: String
			'@context':
				'@id': 'foaf:surname'
		given:
			type: String
			'@context':
				'@id': 'foaf:givenName'
	Publication:
		'@context':
			'dc:description': 'A publication, see'
			'@type': 'bibo:Document'
		author:
			'@context':
				'@id': 'bibo:author'
			type: String
			ref: 'Person'
		reader:
			'@context':
				'@id': 'dc:subject'
				'@container': '@list'
			type: [{ type: String, ref: 'Person' }]
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
