Rails.application.routes.draw do
  root 'welcome#index'
  devise_for :users
  devise_scope :user do
    get 'sign_in',          to:'users/sessions#new'
    get 'sign_up',          to:'users/registrations#new'
    get 'sign_out',         to:'users/sessions#destroy'
    get 'forgot_password',  to:'users/passwords#new'
    get 'reset_password',   to:'users/passwords#edit'
    put 'reset_password',   to:'users/passwords#update'
    post 'sign_in',         to:'users/sessions#create'
    post 'forgot_password', to:'users/passwords#create'
    post 'sign_up',         to:'users/registrations#create'
  end

  get '/markets/:symbol',  to: "welcome#trends", as: :market_quote
  get '/trending/config',  to: "trending#trading_config"
  get '/trending/symbols', to: "trending#symbols"
  get '/trending/history', to: "trending#history"
  get '/trending/time',    to: "trending#time"
  get '/trending/marks',   to: "trending#marks"
  get '/webhook',          to: "api/tickers#webhook"
  post '/trade',           to: 'webhooks#trade'

  namespace :api do
    resources :tickers do
      collection do
        get 'fetch'
        get 'clear_history'
      end
    end
  end
  namespace :backend do
    get 'quote', to:'dashboard#index', as: :quote
    resources :markets do
      get :sync_balance, on: :member
      get :clear_candles, on: :member
      get :sync_candles, on: :member
      resources :candles
    end
    resources :regulates do
      get :change_state, on: :member
    end
    resources :accounts do
      get :sync_balance, on: :collection
    end
    resources :orders
    resources :messages do
      get :clear_history, on: :collection
    end

    resources :indicators do
      get :clear_history, on: :collection
    end

    patch "/order_bid/:id", to: "orders#update", as: :order_bid
    patch "/order_ask/:id", to: "orders#update", as: :order_ask

    Market.exchanges.each do |exchange|
      patch "/#{exchange.pluralize}/:id", to: "markets#update", as: exchange.to_sym
    end
  end

  # https://doc.bccnsoft.com/docs/rails-guides-4.1-cn/routing.html
end
