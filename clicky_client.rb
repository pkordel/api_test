#encoding: utf-8

#
# See: http://www.engineyard.com/blog/2011/building-structured-api-clients-with-api-smith/
#

require "api_smith"

SMART_NUMBER_TRANSFORMER = lambda { |v| v =~ /^\d+$/ ? Integer(v) : v }

class TallyStat < APISmith::Smash
  property :title
  property :value,         :transformer => SMART_NUMBER_TRANSFORMER
  property :value_percent, :transformer => :to_f
  property :url
  property :clicky_url
  # Goal Information
  property :incompleted, :transformer => :to_i
  property :conversion,  :transformer => :to_f
  property :revenue
  property :cost
end


class ClickyClient
  include APISmith::Client

  class TallyStatCollection < APISmith::Smash
    property :type
    property :date
    property :dates, :transformer => lambda { |c| c.map { |v| TallyStat.call(v['items']) }.flatten }
  end

  TALLY_METHODS = %w(visitors visitors-unique actions actions-average time-average time-average-pretty bounce-rate visitors-online feedburner-statistics)

  class Error < StandardError; end

  base_uri 'http://api.getclicky.com/'
  endpoint 'api/stats/4'

  attr_reader :site_id, :site_key

  def initialize(site_id, site_key)
    @site_key = site_key
    @site_id  = site_id
    add_query_options! :site_id => site_id, :sitekey => site_key
  end

  TALLY_METHODS.each do |m|
    define_method m.tr('-', '_') do |*args|
      api_tally_call m, *args
    end
  end

  private

  def check_response_errors(response)
    if response.first.is_a?(Hash) and (error = response.first['error'])
      raise Error.new(error)
    end
  end

  def base_query_options
    {:output => 'json'}
  end

  def api_tally_call(type, options = {})
    get '/', :extra_query => {:type => type}.merge(options),
      :response_container => [0], :transform => TallyStatCollection
  end

end

# site_id=32020
# sitekey=2e05fe2778b6

c = ClickyClient.new('32020', '2e05fe2778b6')
p c.visitors
