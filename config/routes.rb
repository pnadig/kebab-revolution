KebabServerRor::Application.routes.draw do

  match 'desktop'           => 'pages#desktop'
  match 'login'             => 'pages#login'
  match 'plan'              => 'pages#plan'
  match 'register'          => 'pages#register'

  get     "users/get_profile"
  post    "users/update_profile"

  resource :sessions
  resource :passwords
  resource :feedback
  resource :tenants do
    get :bootstrap
    get :valid_host
    get :tests
  end

  root to: "pages#login"
end
