module OmniAuth
  class Builder
    
    def initialize(app = nil,&block)
      @use, @map, @run = [], nil, app
      instance_eval(&block) if block_given?
    end
    
    def on_failure(&block)
      OmniAuth.config.on_failure = block
    end

    def configure(&block)
      OmniAuth.configure(&block)
    end

    def provider(klass, *args, &block)
      if klass.is_a?(Class)
        middleware = klass
      else
        begin
          middleware = OmniAuth::Strategies.const_get("#{OmniAuth::Utils.camelize(klass.to_s)}")
        rescue NameError
          raise LoadError, "Could not find matching strategy for #{klass.inspect}. You may need to install an additional gem (such as omniauth-#{klass})."
        end
      end

      use middleware, *args, &block
    end

    def call(env)
      to_app.call(env)
    end
  end
end