require 'bundler/setup'
require 'api_smith'
require 'awesome_print'
require 'json'
require 'debugger'
require 'rdf'
require_relative 'parser'

class SparqlClient
  include APISmith::Client

  class Parser::SparqlJson < HTTParty::Parser
    SupportedFormats.merge!({ 'application/sparql-results+json' => :json })
  end

  class Error < StandardError; end

  base_uri 'http://localhost:8890/'
  endpoint 'sparql-auth'
  persistent

  attr_reader :user, :password

  def initialize(user, password)
    @user     = user
    @password = password
  end

  def basic_auth
    { username: @user, password: @password }
  end

  READ_METHODS  = %w(select ask construct describe)
  WRITE_METHODS = %w(insert delete create drop clear)

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

  def base_query_options
    { output: 'application/sparql-results+json' }
  end

  def base_request_options
    { basic_auth: basic_auth }
  end

  def api_get(query, options = {})
    get '/', extra_query: { query: query }.merge(options), transform: Virtuoso::Parser
  end

  def api_post(query, options = {})
    post '/', extra_query: { query: query }.merge(options)#, response_container: %w(results) 
  end
end

client = SparqlClient.new('reviewer', 'secret')
prefixes = <<-pref
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX bibo: <http://purl.org/ontology/bibo/>
  PREFIX dc: <http://purl.org/dc/terms/>
  PREFIX fabio: <http://purl.org/spar/fabio/>
  PREFIX rev: <http://purl.org/stuff/rev#>
  PREFIX lang: <http://lexvo.org/id/iso639-3/>
  pref

select = <<-SPARQL
  SELECT DISTINCT ?book ?title ?author ?image
  WHERE { 
    GRAPH <http://data.deichman.no/books> { 
      ?book a bibo:Document ;
            dc:language lang:nob ;
            dc:creator ?creator ;
            dc:title ?title .
      ?creator foaf:name ?author .
      OPTIONAL { ?book foaf:depiction ?image }
    } 
  } OFFSET 200 LIMIT 10
  SPARQL

ask    = "ASK WHERE { ?s ?p ?o }"
create = "CREATE GRAPH <http://example.org>"
drop   = "DROP GRAPH <http://example.org>"

query = prefixes << select
#response = client.create(create)
#response = client.drop(drop)
#puts response.parsed_response["results"]["bindings"]
response = client.select(query)
#response = client.ask(ask)

response.each do |solution|
  puts solution[:book]
  puts solution[:title]
  puts solution[:author]
  puts "\n\n"
end
