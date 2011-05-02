# TODO:
#   ensure settings are only loading once
#   README
#   google charts
#   gitignore
#   embeded as rack app
#   http_simple auth

require 'rubygems'
require 'yaml'
require 'sinatra'
require 'aws/ses'
require 'erb'
require './ses_change_initializer'
require 'net/http'

before do
  @app_name = "server works's Account"
  @ses ||= SesChangeInitializer.ses_account
end

get '/' do
  erb :index
end

get '/delivery_attempts' do
  erb :delivery_attempts
end

get '/bounces' do
  erb :bounces
end

get '/rejects' do
  erb :rejects
end

get '/complaints' do
  erb :complaints
end

get '/gchart/:tracked_static_name' do
  data_points       = @ses.statistics.result.sort_by{|x| x["Timestamp"]}
  dates             = data_points.map{|x|x["Timestamp"]}
  dates             = dates.map do |date_string|
    datetime = DateTime.parse(date_string)
    "#{datetime.month}/#{datetime.day}"
  end

  non_unique_dates = []
  dates.each_with_index do |date, i|
    non_unique_dates.include?(date) ? dates[i] = " " : non_unique_dates << date
  end

  tracked_statistic = data_points.map{|x|x[params[:tracked_static_name]]}.map(&:to_i)

  y_axis_labels = [0]
  5.times{|i| y_axis_labels[i] = (tracked_statistic.max / 5) * i }
  y_axis_labels[y_axis_labels.count] = tracked_statistic.max

  api_uri = URI.parse('http://chart.apis.google.com/chart')
  api_params =  {
    'chxl' => "0:|#{dates.join('|')}|1:|#{y_axis_labels.join('|')}",
    'chxr' => "0,1,3",
    'chxt' => "x,y",
    'chs'  => "1000x300",
    'cht'  => "lc",
    'chd'  => "t:#{tracked_statistic.join(',')}",
    'chg'  => "25,50",
    'chds'  => "0,#{tracked_statistic.max}",
    'chls' => "0.75,-1,-1|2,4,1",
    'chm'  => "o,FF9900,1,-2,8|b,3399CC44,0,1,0",
    'chtt'   => params[:tracked_static_name]
  }

  response = Net::HTTP.post_form(api_uri, api_params)
  "#{response.body}"
end

post '/verified_email_addresses' do
  begin
    @ses.addresses.verify(params[:email_address])
    @verification_message = "Amazon is sending an activation message to #{params[:email_address]}"
  rescue Exception => e
    @verification_message = e.to_s
  end
  erb :index
end
