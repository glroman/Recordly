require 'sinatra'
require 'sinatra/flash'
require 'slim'
require 'sequel'
require 'sqlite3'
require 'bcrypt'

require_relative 'lib/authentication'
require_relative 'lib/user'

set :bind, '0.0.0.0'

DB_FILE = 'database.sqlite3'
DB      = Sequel.sqlite(DB_FILE)

unless DB.tables.include?(:USER)
  raise 'Error: No USER table found in %s' % [DB_FILE]
end

LOGIN_EXPIRES   = 60 * 10           # Seconds of inactivity
use Rack::Session::Pool, expire_after: LOGIN_EXPIRES
helpers Authentication

configure :development do
  require 'better_errors'

  Slim::Engine.set_options pretty: true, sort_attrs: false

  # Set application root for abbreviated filenames
  use BetterErrors::Middleware
  BetterErrors.application_root = File.expand_path('..', __FILE__)
end

#############

helpers do
  def redirect_to_original_request
    user                = session[:user]
    original_request    = session[:original_request]
    flash[:notice]      = 'Welcome back %s' % [user.name]
    session[:original_request] = nil
    redirect original_request
  end
end

#############

@title      = 'Title Here!'     # Page (tab) Title
@header     = 'Page Header!'    # Page (h1) Header

@user       = nil
@login_at   = nil

#############

get '/' do
  authenticate!

  @title    = 'Recordly'
  @header   = 'Main'
  slim :index
end

get '/login' do
  @title    = 'Rec: Login'
  @header   = 'Login'
  slim :login
end

post '/login' do
  #puts 'Form data: (%s/%s)' % [params[:user], params[:pwd]]

  user_name = params[:user].strip
  user_pwd  = params[:pwd ].strip

  if user_rec = User.authenticate(user_name, user_pwd)
    logger.info 'Login succeeded: %s' % [user_name]
    session[:user]  = user_rec
    redirect_to_original_request
    return
  end

  logger.info 'Login failed: %s' % [user_name]
  flash[:notice] = 'Wrong user name or password; try again'
  redirect '/login'
end

get '/logout' do
  session[:user]    = login
  flash[:notice]    = 'You are now logged out'
  redirect '/login'
end

#############

get '/new_user' do
  @title    = 'Rec: Register'
  @header   = 'Register'
  slim :new_user
end

post '/new_user' do
  user_name = params[:user].strip
  user_pwd  = params[:pwd1].strip
  user_pwd2 = params[:pwd2].strip

  # TODO: relocate validations to lib/user
  # TODO: replace hardcoded validation constants
  if user_name.size < 3
    flash[:notice] = 'Logins must be at least three characters long'
    redirect '/new_user'
  end

  if user_pwd.size < 8
    flash[:notice] = 'Passwords must be at least eight characters long'
    redirect '/new_user'
  end

  if user_pwd != user_pwd2
    flash[:notice] = 'Passwords do not match; try again'
    redirect '/new_user'
  end

  if User.exists(user_name)
    flash[:notice] = 'Username already taken; try again'
    redirect '/new_user'
  end

  if !user = User.create(user_name, user_pwd)
    flash[:notice] = 'Error creating account!'
    redirect_to_original_request
  end

  logger.info 'New login: %s' % [user_name]
  session[:user]    = user
  flash[:notice]    = 'New account created'
  redirect '/login'
end

#############

get '/album_details' do
  authenticate!

  @title    = 'Rec: CDs'
  @header   = 'Your CD Collection'
  slim :album_details
end

get '/debug' do
  @title    = 'Rec: DEBUG'
  @header   = 'DEBUG'
  slim :debug
end

