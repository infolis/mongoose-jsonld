Mongoose       = require 'mongoose'

module.exports = {
	'String': String
	'Number': Number
	'Boolean': Boolean
	'ObjectId': Mongoose.Schema.ObjectId
	'Date': Date
	'Mixed': Mongoose.Schema.Types.Mixed
	'Object': {}
	'Array': []
	'ArrayOfStrings': [String]
}
