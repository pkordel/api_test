#encoding: utf-8
require 'bundler/setup'
require 'api_smith'
require 'awesome_print'
require 'debugger'
require 'rdf'
require_relative 'parser'

class SparqlClient
  include APISmith::Client

  RESULT_JSON = 'application/sparql-results+json'.freeze
  RESULT_XML  = 'application/sparql-results+xml'.freeze
  ACCEPT_JSON = {'Accept' => RESULT_JSON}.freeze
  ACCEPT_XML  = {'Accept' => RESULT_XML}.freeze

  class Parser::SparqlJson < HTTParty::Parser
    SupportedFormats.merge!({ RESULT_JSON => :json })
  end

  class ClientError < StandardError; end
  class MalformedQuery < ClientError; end
  class NotAuthorized < ClientError; end
  class ServerError < StandardError; end

  persistent

  attr_reader :username, :password

  def initialize(uri, username = nil, password = nil)
    self.class.base_uri uri
    @username = username
    @password = password
  end

  READ_METHODS  = %w(select ask construct describe)
  WRITE_METHODS = %w(insert update delete create drop clear)

  READ_METHODS.each do |m|
    define_method m do |*args|
      api_get *args
    end
  end

  WRITE_METHODS.each do |m|
    define_method m do |*args|
      api_post *args
    end
  end

  private

  def check_response_errors(response)
    case response.code
    when 400
      raise MalformedQuery.new(response.parsed_response)
    when 401
      raise NotAuthorized.new
    when 500..599
      raise ServerError.new(response.body)
    end
  end

  def headers
    { 'Accept' => [RESULT_JSON, RESULT_XML].join(', ') }
  end

  def base_query_options
    { format: 'json' }
  end

  def base_request_options
    { headers: headers }
  end

  def basic_auth
    { username: @username, password: @password }
  end

  def api_get(query, options = {})
    self.class.endpoint 'sparql'
    get '/', extra_query: { query: query }.merge(options), 
      transform: RDF::Virtuoso::Parser::JSON
  end

  def api_post(query, options = {})
    self.class.endpoint 'sparql-auth'
    post '/', extra_query: { query: query }.merge(options),
              extra_request: { basic_auth: basic_auth },
              response_container: ["results", "bindings", 0, "callret-0", "value"] 
  end
end


prefixes = <<-pref
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX bibo: <http://purl.org/ontology/bibo/>
  PREFIX dc: <http://purl.org/dc/terms/>
  PREFIX fabio: <http://purl.org/spar/fabio/>
  PREFIX rev: <http://purl.org/stuff/rev#>
  PREFIX lang: <http://lexvo.org/id/iso639-3/>
  pref

select = <<-SPARQL
  SELECT *
  WHERE { ?subject a bibo:Document }
  SPARQL

count = <<-SPARQL
  PREFIX rev: <http://purl.org/stuff/rev#>
  SELECT * WHERE { 
    ?subject a rev:Review . 
  }
  SPARQL

query = prefixes << select

ask    = "ASK WHERE { ?s ?p ?o }"
create = "CREATE GRAPH <http://example.org>"
drop   = "DROP GRAPH <http://example.org>"

insert = <<-SPARQL
  PREFIX rev: <http://purl.org/stuff/rev#>
  PREFIX test: <http://data.deichman.no/bookreviews/test#>

  INSERT INTO <http://data.deichman.no/test> { test:1 rev:title "My Title" }
  SPARQL

delete = <<-SPARQL
  PREFIX rev: <http://purl.org/stuff/rev#>
  PREFIX test: <http://data.deichman.no/bookreviews/test#>

  DELETE FROM <http://data.deichman.no/test> { test:1 rev:title "My New Title" } 
  SPARQL

update = <<-SPARQL
  PREFIX rev: <http://purl.org/stuff/rev#>
  PREFIX test: <http://data.deichman.no/bookreviews/test#>

  MODIFY GRAPH <http://data.deichman.no/test> 
  DELETE { test:1 rev:title "My Title" }
  INSERT { test:1 rev:title "My New Title" }
  SPARQL

client = SparqlClient.new('http://localhost:8890', 'reviewer', 'secret')

def create_query(client, query)
  response = client.create(query)
  puts response.inspect
end

#response = client.insert(insert)
#puts response.inspect
#response = client.select("select ?s ?o where { graph <http://data.deichman.no/test> { ?s ?p ?o } }")
#puts response.inspect
#puts ""

#response = client.update(update)
#puts response.inspect
#response = client.select("select ?s ?o where { graph <http://data.deichman.no/test> { ?s ?p ?o } }")
#puts response.inspect
#puts ""

#response = client.delete(delete)
#puts response.inspect
#response = client.select("select ?s ?o where { graph <http://data.deichman.no/test> { ?s ?p ?o } }")
#puts response.inspect

client = SparqlClient.new('http://data.deichman.no/')
solutions = client.select(count)
#response = client.ask(ask)
puts solutions.count
puts solutions.first.inspect
