class Users::RegistrationsController < Devise::RegistrationsController
  layout "auth"

  before_action :configure_permitted_parameters

  def new
    if user_signed_in?
      redirect_to dashboard_path and return
    end
    super
  end

  def create
    clean_params = sign_up_params.dup
    if clean_params[:email].blank? && clean_params[:email_address].present?
      clean_params[:email] = clean_params[:email_address]
    end
    if clean_params[:email_address].blank? && clean_params[:email].present?
      clean_params[:email_address] = clean_params[:email]
    end

    build_resource(clean_params)
    resource.role = :operator # Security: Default role is always operator

    resource.save
    yield resource if block_given?
    if resource.persisted?
      session[:user_id] = resource.id
      if resource.active_for_authentication?
        set_flash_message! :notice, :signed_up
        sign_up(resource_name, resource)
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      set_minimum_password_length
      flash.now[:alert] = resource.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :username, :email, :email_address])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :username, :email, :email_address, :avatar_url])
  end

  def after_sign_up_path_for(resource)
    dashboard_path
  end
end
