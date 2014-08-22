Spree::Core::Engine.add_routes do
  namespace :admin do
    resources :users do
      member do
        put :generate_api_key
        put :clear_api_key
      end
    end
  end

  namespace :api, :defaults => { :format => 'json' } do
    resources :products do
      resources :images
      resources :variants
      resources :product_properties
    end

    order_routes = lambda {
      member do
        put :cancel
        put :empty
        put :apply_coupon_code
      end

      resources :line_items
      resources :payments do
        member do
          put :authorize
          put :capture
          put :purchase
          put :void
          put :credit
        end
      end
      # TODO Remove after shipment api is no longer handled through order nesting.
      resources :shipments, :only => [:create, :update] do
        member do
          put :ready
          put :ship
          put :add
          put :remove
        end
      end

      resources :addresses, :only => [:show, :update]

      resources :return_authorizations do
        member do
          put :add
          put :cancel
          put :receive
        end
      end
    }

    resources :checkouts do
      member do
        put :next
        put :advance
        put :complete
      end
      order_routes.call
    end

    resources :variants, :only => [:index, :show] do
      resources :images
    end

    resources :option_types do
      resources :option_values
    end

    get '/orders/mine', :to => 'orders#mine', :as => 'my_orders'
    get "/orders/current", to: "orders#current", to: "orders#current", as: "current_order"

    resources :orders, &order_routes

    resources :zones
    resources :countries, :only => [:index, :show] do
      resources :states, :only => [:index, :show]
    end
    resources :shipments, :only => [:create, :update] do
      collection do
        get :mine
      end

      member do
        put :ready
        put :ship
        put :add
        put :remove
      end
    end
    resources :states,    :only => [:index, :show]

    resources :taxonomies do
      member do
        get :jstree
      end
      resources :taxons do
        member do
          get :jstree
        end
      end
    end

    resources :taxons, :only => [:index]

    resources :inventory_units, :only => [:show, :update]
    resources :users
    resources :properties
    resources :stock_locations do
      resources :stock_movements
      resources :stock_items
    end

    get '/config/money', :to => 'config#money'
    get '/config', :to => 'config#show'

    put '/classifications', :to => 'classifications#update', :as => :classifications
    get '/taxons/products', :to => 'taxons#products', :as => :taxon_products
  end
end
