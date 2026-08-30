Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV["GOOGLE_CLIENT_ID"].presence || "placeholder_google_client_id",
           ENV["GOOGLE_CLIENT_SECRET"].presence || "placeholder_google_client_secret",
           {
             scope: "email,profile",
             prompt: "select_account",
             image_aspect_ratio: "square",
             image_size: 150
           }

  provider :github,
           ENV["GITHUB_CLIENT_ID"].presence || "placeholder_github_client_id",
           ENV["GITHUB_CLIENT_SECRET"].presence || "placeholder_github_client_secret",
           {
             scope: "user:email"
           }
end

OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true

OmniAuth.config.on_failure = Proc.new do |env|
  OmniauthCallbacksController.action(:failure).call(env)
end
