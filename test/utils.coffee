Utils = require '../src/utils'
test     = require 'tape'

test 'lastUriSegment', (t) ->
	t.equals Utils.lastUriSegment('http://'), ''
	t.equals Utils.lastUriSegment('http://foo'), 'foo'
	t.equals Utils.lastUriSegment('http://foo/bar'), 'bar'
	t.equals Utils.lastUriSegment('http://foo/bar#quux'), 'quux'
	t.ok Utils.lastUriSegmentMatch('http://foo/bar#quux', 'foo/quux')
	t.end()

test 'lcfirst', (t) ->
	t.equals Utils.lcfirst('FooBar'), 'fooBar'
	t.end()
