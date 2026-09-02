OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true

OmniAuth.config.on_failure = Proc.new do |env|
  Users::OmniauthCallbacksController.action(:failure).call(env)
end
