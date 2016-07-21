# frozen_string_literal: true

Rails.application.routes.draw do
  root 'stickies#month'
  get '' => 'stickies#month', as: :dashboard

  resources :comments do
    collection do
      get :search
    end
  end

  resources :boards do
    member do
      post :archive
    end
    collection do
      post :add_stickies
    end
  end

  scope module: :external do
    get :about
    get '/about/use', action: 'use', as: :about_use
    get :version
  end

  resources :groups

  namespace :project_favorites do
    post :favorite
    post :colorpicker
  end

  resources :project_users do
    collection do
      get :accept
    end
  end

  resources :projects do
    collection do
      post :selection
    end
    member do
      get :bulk
      post :reassign
    end
  end

  resources :stickies do
    collection do
      get :day
      get :week
      get :month
      get :template
    end
    member do
      post :move
      post :move_to_board
      post :complete
    end
  end

  resources :tags do
    collection do
      post :add_stickies
    end
  end

  resources :templates do
    collection do
      post :add_item
      post :items
      post :selection
    end
    member do
      get :copy
    end
  end

  devise_for :users, path_names: { sign_up: 'join', sign_in: 'login' }, path: ''

  resources :users do
    member do
      post :update_settings
    end
  end

  scope module: :internal do
    get :search
  end

  get '/settings' => 'users#settings', as: :settings
  get '/stats' => 'users#stats', as: :stats
  get '/day' => 'stickies#day', as: :day
  get '/week' => 'stickies#week', as: :week
  get '/month' => 'stickies#month', as: :month
  get '/tasks' => 'stickies#tasks', as: :tasks
end
