module Admin
  class UsersController < ApplicationController
    before_action :require_admin

    def index
      @pagy, @users = pagy(User.order(created_at: :desc))
      @admin_count = User.where(role: :admin).count
      @operator_count = User.where(role: :operator).count
    end

    def update_role
      @target_user = User.find(params[:id])
      new_role = params[:role]

      if %w[admin operator].exclude?(new_role)
        flash[:alert] = "Invalid role specified."
        return redirect_to admin_users_path
      end

      # Safety: Prevent last admin from demoting themselves
      if @target_user.admin? && new_role == "operator" && User.where(role: :admin).count <= 1
        flash[:alert] = "Safety Protection: Cannot demote the last remaining administrator account."
        return redirect_to admin_users_path
      end

      @target_user.update!(role: new_role)
      flash[:notice] = "User #{@target_user.name}'s role was updated to #{new_role.upcase}."
      redirect_to admin_users_path
    end
  end
end
