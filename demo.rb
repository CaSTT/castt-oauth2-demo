require 'sinatra'
require 'erb'
require 'oauth2'

enable :sessions

# check for any missing env vars
if (missing_keys = %w(OAUTH2_CLIENT_ID OAUTH2_CLIENT_SECRET OAUTH2_SITE).reject { |key| ENV.key? key }).any?
  $stderr.puts 'Missing the following ENV variables: ' + missing_keys.join(', ')
  exit 1
end

# build the oauth2 client
oauth2_client = OAuth2::Client.new ENV['OAUTH2_CLIENT_ID'], ENV['OAUTH2_CLIENT_SECRET'],
                  :site => ENV['OAUTH2_SITE'],
                  :authorize_url => '/customer/oauth2/authorize',
                  :token_url => '/customer/oauth2/authorize'

# guests get a login link, authenticated customers get some api results
get '/' do
  if session[:token]
    token = OAuth2::AccessToken.new(oauth2_client, session[:token])
    @oauth2_response = token.get('/customer/oauth2/customer', :params => {:oauth_token => session[:token]}).parsed
    erb :authenticated
  else
    @oauth2_url = oauth2_client.auth_code.authorize_url(:redirect_uri => url('/authorize'))
    erb :guest
  end
end

# given params[:code], attempt to retrieve a token
get '/authorize' do
  begin
    session[:token] = oauth2_client.auth_code.get_token(params[:code], :redirect_uri => url('/authorize')).token
    redirect '/'
  rescue OAuth2::Error => @oauth2_error
    erb :error
  end
end

# clear out the session token
get '/logout' do
  session.delete :token
  redirect '/'
end
