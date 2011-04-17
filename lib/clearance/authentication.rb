module Clearance
  module Authentication
    extend ActiveSupport::Concern

    included do
      helper_method :current_user, :signed_in?, :signed_out?
      hide_action   :current_user, :current_user=,
                    :signed_in?,   :signed_out?,
                    :sign_in,      :sign_out,
                    :authenticate, :deny_access
    end

    # User in the current cookie
    #
    # @return [User, nil]
    def current_user
      @_current_user ||= user_from_cookie
    end

    # Set the current user
    #
    # @param [User]
    def current_user=(user)
      @_current_user = user
    end

    # Is the current user signed in?
    #
    # @return [true, false]
    def signed_in?
      ! current_user.nil?
    end

    # Is the current user signed out?
    #
    # @return [true, false]
    def signed_out?
      current_user.nil?
    end

    # Deny the user access if they are signed out.
    #
    # @example
    #   before_filter :authenticate
    def authenticate
      deny_access unless signed_in?
    end

    # Sign user in to cookie.
    #
    # @param [User]
    #
    # @example
    #   sign_in(@user)
    def sign_in(user)
      if user
        cookies[:remember_token] = {
          :value   => user.remember_token,
          :expires => Clearance.configuration.cookie_expiration.call
        }
        self.current_user = user
      end
    end

    # Sign user out of cookie.
    #
    # @example
    #   sign_out
    def sign_out
      current_user.reset_remember_token! if current_user
      cookies.delete(:remember_token)
      self.current_user = nil
    end

    # Store the current location and redirect to sign in.
    # Display a failure flash message if included.
    #
    # @param [String] optional flash message to display to denied user
    def deny_access(flash_message = nil)
      store_location
      flash[:failure] = flash_message if flash_message
      redirect_to(sign_in_url)
    end

    # CSRF protection in Rails >= 3.0.4
    # http://weblog.rubyonrails.org/2011/2/8/csrf-protection-bypass-in-ruby-on-rails
    def handle_unverified_request
      super
      sign_out
    end

    protected

    def user_from_cookie
      if token = cookies[:remember_token]
        ::User.find_by_remember_token(token)
      end
    end

    def sign_user_in(user)
      warn "[DEPRECATION] sign_user_in: unnecessary. use sign_in(user) instead."
      sign_in(user)
    end

    def store_location
      if request.get?
        session[:return_to] = request.fullpath
      end
    end

    def redirect_back_or(default)
      redirect_to(return_to || default)
      clear_return_to
    end

    def return_to
      session[:return_to] || params[:return_to]
    end

    def clear_return_to
      session[:return_to] = nil
    end

    def redirect_to_root
      redirect_to('/')
    end
  end
end
