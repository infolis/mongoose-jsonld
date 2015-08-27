{ObjectId} = require('mongoose').Schema
module.exports =
	Algorithm:
		'@context':
			'dc:description': 'An algorithm, a set of steps to calculate something from input, producing output.'
		author:
			'@context':
				'@id': 'dc:creator'
			type: [{ type: String, ref: 'Person' }]
		name:
			'@context':
				'@id': 'dc:title'
				'dc:description': 'Name of the Algorithm'
				'@type': 'xsd:string'
			type: String
		lastModified:
			'@context':
				'@id': 'dc:modified'
			type: Date
	Execution:
		'@context':
			'dc:description': 'The concrete execution of an Algorithm'
			'rdfs:subClassOf': 'schema:Action'
	Configuration:
		'@context':
			'dc:description': 'A JSON document defining the inputs and environments of an Execution'
			'rdfs:seeAlso': 'dm2e:Configuration'
	Pattern:
		'@context':
			'dc:description': 'A Regular Expression pattern'
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
			enum: [ "article", "article-magazine", "article-newspaper", "article-journal", "bill", "book", "broadcast", "chapter", "dataset", "entry",
					"entry-dictionary", "entry-encyclopedia", "figure", "graphic", "interview", "legislation", "legal_case", "manuscript", "map",
					"motion_picture", "musical_score", "pamphlet", "paper-conference", "patent", "post", "post-weblog", "personal_communication", "report",
					"review", "review-book", "song", "speech", "thesis", "treaty", "webpage"]

	# Author:
	#     firstName:
	#         '@context':
	#             '@id': 'foaf:firstName'
	#             'rdf:type': 'rdfs:Property'
	#             '@type': 'xsd:string'
	#         type: String

