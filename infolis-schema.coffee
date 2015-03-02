module.exports = 
	Publication:
		foo: String
		title:
			jsonld:
				'@id': 'dc:title'
				'rdf:type': 'rdfs:Property'
				'@type': 'xsd:string'
			type: String
		# taip:
		#     jsonld:
		#         '@type': '@id'
		#         'rdf:type': 'rdfs:Property'
		#     type: String
		#     enum: ["article", "article-magazine", "article-newspaper", "article-journal", "bill", "book", "broadcast", "chapter", "dataset", "entry", "entry-dictionary", "entry-encyclopedia", "figure", "graphic", "interview", "legislation", "legal_case", "manuscript", "map", "motion_picture", "musical_score", "pamphlet", "paper-conference", "patent", "post", "post-weblog", "personal_communication", "report", "review", "review-book", "song", "speech", "thesis", "treaty", "webpage"]

	# Author:
	#     firstName:
	#         jsonld:
	#             '@id': 'foaf:firstName'
	#             'rdf:type': 'rdfs:Property'
	#             '@type': 'xsd:string'
	#         type: String
	
