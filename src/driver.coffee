# To do
# - Meteor.settings.neo4j_url

throwIfError = (response) ->
  if response.data.errors.length isnt 0
    for error in response.data.errors
      throw new Meteor.Error(error.code, error.message)

getValues = R.map(R.prop('row'))

transpose = (xy) ->
  # get the index, pull the nth item, pass that function to map
  R.mapIndexed(R.pipe(R.nthArg(1), R.nth, R.map(R.__, xy)), R.head(xy))

isArray = (x) ->
  Object.prototype.toString.apply(x) is '[object Array]'

isPlainObject = (x) ->
  Object.prototype.toString.apply(x) is '[object Object]'

isString = (x) ->
  Object.prototype.toString.apply(x) is '[object String]'

rows2fields = (rows, keys) ->
  rows.map (row) ->
    unless isArray(row)
      row = [row]
    if row.length isnt keys.length
      console.warn "Wrong number of fields specified for the row", row, keys
    obj = {}
    for i in [0...row.length]
      obj[keys[i]] = row[i]
    return obj

stringify = (value) ->
  # turn an object into a string that plays well with
  # Cipher queries.
  if isArray(value)
    "[#{value.map(stringify).join(',')}]"
  else if isPlainObject(value)
    pairs = []
    for k,v of value
      pairs.push "#{k}:#{stringify(v)}"
    "{" + pairs.join(', ') + "}"
  else if isString(value)
    "'#{value.replace(/'/g, "\\'")}'"
  else if value is undefined
    null
  else
    "#{value}"

regexify = (string) ->
  "'(?i).*#{string.replace(/'/g, "\\'").replace(/\//g, '\/')}.*'"

class Neo4jDB
  constructor: (url) ->
    @url = url or process.env.NEO4J_URL or process.env.GRAPHENEDB_URL or 'http://localhost:7474'

    @options = {}
    list = @url.match(/^(.*\/\/)(.*)@(.*$)/)
    if list
      @url = list[1] + list[3]
      @options.auth = list[2]

    try
      console.info 'Connecting to Neo4j on ' + @url
      response = HTTP.call('GET', @url, @options)
      if response.statusCode is 200
        console.info 'Meteor is successfully connected to Neo4j on ' + @url
      else
        console.warn 'Could not connect to Neo4j on ' + @url, response.toString()
    catch error
      console.warn 'HTTP Error trying to connect to Neo4j', error.toString()

  @stringify: stringify
  stringify: stringify
  @regexify: regexify
  regexify: regexify
  @transpose: transpose
  transpose: transpose
  @rows2fields: rows2fields
  rows2fields: rows2fields

  latency: ->
    R.mean [0...10].map => 
      start = Date.now()
      HTTP.call('GET', @url, @options)
      Date.now() - start

  reset: ->
    console.log "Resetting Neo4j..."
    @query "MATCH (n) OPTIONAL MATCH (n)-[r]-() DELETE n,r"
    # clear the database
    console.log "...done."

  isEmpty: ->
    [n] = Neo4j.query("MATCH (n) MATCH (n)-[r]-() RETURN count(n)+count(r)")
    return (n is 0)

  # types of queries:
  # - nothing returned
  # - one value returned, like count(n), `queryOne` returns a value or undefined
  # - an array of values returned, like n, `query` returns a collection
  # - a property is returned, like n._id, `query` returns an array of values
  # - multiple properties are returned, like n._id, n.username, `query` returns an array of 2 arrays of those values
  # - multiple different things are returned, like n._id, r._id, `query` returns an array of 2 arrays of those values
  query: (statement, parameters={}) ->
    # response = HTTP.post("http://localhost:7474/db/data/transaction/commit", {data: {statements: [{statement, parameters}]}})
    response = HTTP.post(@url+"/db/data/transaction/commit", R.merge(@options, {data: {statements: [{statement, parameters}]}}))
    throwIfError(response)
    if response.data.results.length is 1
      # one statement should return one result
      result = response.data.results[0]
      if result.columns.length is 0
        # if theres nothing in the return statement, return nothing
        return
      else if result.columns.length is 1
        # if theres only one column returned, then just return an array of values
        getResults = R.compose(R.flatten, getValues)
        return getResults(result.data)
      else
        if result.data.length is 0
          return [0...result.columns.length].map(->[])
        else
          # if there are multiple columns, return a collection for each one
          return getValues(result.data)

  # zip(keys, columns) -> [{key:val}, ...]
  # turns a matrix of columns into rows with key values.
  zip: R.useWith(R.map, R.zipObj, transpose)
