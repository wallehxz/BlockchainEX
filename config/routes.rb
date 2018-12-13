Rails.application.routes.draw do
  root 'welcome#index'

  devise_for :users
  devise_scope :user do
    get 'sign_in',          to:'users/sessions#new'
    post 'sign_in',         to:'users/sessions#create'
    get 'sign_up',          to:'users/registrations#new'
    post 'sign_up',         to:'users/registrations#create'
    get 'sign_out',         to:'users/sessions#destroy'
    get 'forgot_password',  to:'users/passwords#new'
    post 'forgot_password', to:'users/passwords#create'
    get 'reset_password',   to:'users/passwords#edit'
    put 'reset_password',   to:'users/passwords#update'
  end

  get '/markets/:symbol',  to: "welcome#trends", as: :market_quote
  get '/trending/config',  to: "trending#trading_config"
  get '/trending/symbols', to: "trending#symbols"
  get '/trending/history', to: "trending#history"
  get '/trending/time',    to: "trending#time"

  namespace :backend do
    get 'quote', to:'dashboard#index', as: :quote
    get 'daemon', to: 'dashboard#daemon', as: :daemon
    get 'daemon_operate', to: 'dashboard#daemon_operate'
    resources :markets do
      get :sync_balance, on: :member
      resources :candles
    end
    resources :regulates do
      get :change_state, on: :member
    end
    resources :accounts
    resources :orders

    Market.exchanges.each do |exchange|
      patch "/#{exchange.pluralize}/:id", to: "markets#update", as: exchange.to_sym
    end
  end

  # https://doc.bccnsoft.com/docs/rails-guides-4.1-cn/routing.html
end
