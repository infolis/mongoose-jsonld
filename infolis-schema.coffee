{ObjectId} = require('mongoose').Schema
module.exports = 
	Person:
		# 'jsonld' should be '@context'!
		# jsonld:
		#     '@id': 'foaf:Person'
		schema: 
			surname:
				type: String
				jsonld:
					'@context': 'foaf:'
			given:
				type: String
				jsonld:
					'@id': 'foaf:givenName'
	Publication:
		schema:
			author: 
				jsondld:
					'@id': 'bibo:author'
				# Reference another collection
				type: [{ type: ObjectId, ref: 'Person' }]
			title:
				type: String
				jsonld:
					'@id':      'dc:title'
			type:
				type: String
				enum: [ "article", "article-magazine", "article-newspaper", "article-journal",
						"bill", "book", "broadcast", "chapter", "dataset", "entry", "entry-dictionary",
						"entry-encyclopedia", "figure", "graphic", "interview", "legislation",
						"legal_case", "manuscript", "map", "motion_picture", "musical_score", "pamphlet",
						"paper-conference", "patent", "post", "post-weblog", "personal_communication",
						"report", "review", "review-book", "song", "speech", "thesis", "treaty", "webpage"]
				'jsonld':
					'dc:description': "The values are the same as those in citeproc"
					'@id':      'dc:format'

	# Author:
	#     firstName:
	#         jsonld:
	#             '@id': 'foaf:firstName'
	#             'rdf:type': 'rdfs:Property'
	#             '@type': 'xsd:string'
	#         type: String
	
