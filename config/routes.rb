Rails.application.routes.draw do
  get "up" => "rails/health#show"

  namespace :admin do
    #
    # Authentication
    #
    get 'login' => 'sessions#new'
    post 'login' => 'sessions#create'
    delete 'logout' => 'sessions#destroy'

    # Settings
    #
    get 'settings' => 'settings#index'
    get 'settings/general' => 'settings#edit'
    patch 'settings' => 'settings#update'
    get 'settings/design' => 'settings#design'
    resources :users
    resources :services
    resources :service_statuses
    resources :service_groups
    resources :email_templates, :only => [:index, :edit, :update, :destroy]
    resources :api_tokens

    #
    # Issues
    #
    resources :issues do
      get 'resolved', :on => :collection
      resources :issue_updates
    end

    #
    # Maintenances
    #
    resources :maintenances do
      get 'completed', :on => :collection
      post 'toggle', :on => :member
      resources :maintenance_updates
    end

    #
    # Subscribers
    #
    resources :subscribers, :only => [:index, :destroy, :new, :create] do
      post 'verify', :on => :member
      post 'clean_unverified', :on => :collection
    end

    #
    # Misc. Admin Routes
    #
    get 'helpers/chronic'

    #
    # Admin Root
    #
    root 'dashboard#index'
  end

  #
  # Setup Wizard
  #
  get 'setup/step1'
  match 'setup/step2', via: [:get, :post]
  match 'setup/step3', via: [:get, :post]

  #
  # Public Site Paths
  #
  get 'issue/:id' => 'pages#issue'
  get 'maintenance/:id' => 'pages#maintenance'
  get 'history' => 'pages#history'
  get 'robots.txt' => 'pages#robots'
  get 'subscribe' => 'pages#subscribe'
  post 'subscribe/email' => 'pages#subscribe_by_email'
  get 'unsub/:token' => 'pages#unsubscribe'
  get 'verify/:token' => 'pages#subscriber_verification'
  root 'pages#index'

  # updown
  get 'ping' => 'updown#ping'
  post 'sidekiq' => 'updown#sidekiq'
end
