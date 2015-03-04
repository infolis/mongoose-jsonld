{ObjectId} = require('mongoose').Schema
module.exports = 
	Person:
		'@context':
			'@id': 'foaf:Person'
		schema: 
			surname:
				type: String
				'@context':
					'@context': 'foaf:'
			given:
				type: String
				'@context':
					'@id': 'foaf:givenName'
	Publication:
		'@context':
			'dc:description': 'A publication, see'
			'@type': 'bibo:Document'
		schema:
			author: 
				'@context':
					'@id': 'bibo:author'
				# Reference another collection
				type: [{ type: ObjectId, ref: 'Person' }]
			title:
				type: String
				'@context':
					'@id': 'dc:title'
			type:
				type: String
				enum: [ "article", "article-magazine", "article-newspaper", "article-journal", "bill", "book", "broadcast", "chapter", "dataset", "entry",
						"entry-dictionary", "entry-encyclopedia", "figure", "graphic", "interview", "legislation", "legal_case", "manuscript", "map", 
						"motion_picture", "musical_score", "pamphlet", "paper-conference", "patent", "post", "post-weblog", "personal_communication", "report",
						"review", "review-book", "song", "speech", "thesis", "treaty", "webpage"]
				'@context':
					'dc:description': "The values are the same as those in citeproc"
					'@id':      'dc:format'

	# Author:
	#     firstName:
	#         '@context':
	#             '@id': 'foaf:firstName'
	#             'rdf:type': 'rdfs:Property'
	#             '@type': 'xsd:string'
	#         type: String
	
