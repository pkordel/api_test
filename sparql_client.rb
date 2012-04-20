require 'api_smith'
require 'awesome_print'
require 'json'
require 'debugger'

class SparqlClient
  include APISmith::Client

  class Triples < APISmith::Smash
    debugger
    property :subject,   from: :s
    property :predicate, from: :p
    property :object,    from: :o
  end

  class Parser::SparqlJson < HTTParty::Parser
    SupportedFormats.merge!({ 'application/sparql-results+json' => :json })
  end

  class Error < StandardError; end

  base_uri 'http://localhost:8890/'
  endpoint 'sparql'
  persistent

  attr_reader :user, :password

  def initialize(user, password)
    @user     = user
    @password = password
  end

  define_method 'select' do |*args|
    api_call *args
  end

  private

  def base_query_options
    { output: 'application/sparql-results+json' }
  end

  def api_call(query, options = {})
    #debugger
    get '/', extra_query: { query: query }.merge(options), response_container: %w[results bindings], transform: Triples
  end
end

client = SparqlClient.new('reviewer', 'secret')
query = "SELECT ?s ?p ?o WHERE { ?s ?p ?o } LIMIT 2"
response = client.select(query)
puts response.inspect
response.each do |s| 
#  ap "#{s.subject['value']} #{s.predicate['value']} #{s.object['value']}"
end
