# frozen_string_literal: true

require 'rails_helper'

describe SessionController do
  include ControllerHelpers

  context 'GET show_update_password' do
    it 'does not authorize previously authorized source ip' do
      source_ip = '102.20.2.1'
      expect_any_instance_of(Authentication::SourceIpChecker)
        .to receive(:ip_authorized?)
        .and_return(true)
      expect_any_instance_of(ActionController::TestRequest)
        .to receive(:remote_ip)
        .exactly(3).times
        .and_return(source_ip)
      session[:authorized_ip] = source_ip
      session[:user_id] = users(:bob).id
      session[:private_key] = 'fookey'

      expect_any_instance_of(Authentication::SourceIpChecker).to receive(:previously_authorized?)
      expect_any_instance_of(Authentication::SourceIpChecker).to receive(:ip_authorized?).never

      get :show_update_password

      expect(response).to have_http_status(200)
    end

    it 'redirects if ldap user tries to access update password site' do
      users(:bob).update!(auth: 'ldap')
      login_as(:bob)
      get :show_update_password

      expect(response).to redirect_to teams_path
    end
  end

  context 'GET new' do
    it 'should redirect to wizard if new setup' do
      User.delete_all

      get :new

      expect(response).to redirect_to wizard_path
    end

    it 'should show 401 if ip address is unauthorized' do
      expect_any_instance_of(Authentication::SourceIpChecker)
        .to receive(:ip_authorized?)
        .and_return(false)

      get :new

      expect(response).to have_http_status(401)
    end

    it 'saves ip in session if ip allowed' do
      random_ip = "#{rand(1..253)}.#{rand(254)}.#{rand(254)}.#{rand(254)}"
      expect_any_instance_of(Authentication::SourceIpChecker)
        .to receive(:ip_authorized?)
        .and_return(true)
      expect_any_instance_of(ActionController::TestRequest)
        .to receive(:remote_ip)
        .exactly(3).times
        .and_return(random_ip)

      get :new

      expect(response).to have_http_status(200)
      expect(session[:authorized_ip]).to eq random_ip
    end

  end

  context 'DELETE destroy' do
    it 'logs in and logs out' do
      login_as(:bob)

      delete :destroy

      expect(response).to redirect_to session_new_path
    end

    it 'logs in, logs out and save jumpto if set' do
      login_as(:admin)

      delete :destroy, params: { jumpto: admin_users_path }

      expect(response).to redirect_to session_new_path
      expect(admin_users_path).to eq session[:jumpto]
    end
  end

  context 'POST create' do
    it 'cannot login with wrong password' do
      post :create, params: { password: 'wrong_password', username: 'bob' }

      expect(flash[:error]).to match(/Authentication failed/)
    end

    it 'redirects to recryptrequests page if private key cannot be decrypted' do
      users(:bob).update!(private_key: 'invalid private_key')

      post :create, params: { password: 'password', username: 'bob' }

      expect(response).to redirect_to recryptrequests_new_ldap_password_path
    end

    it 'cannot login with unknown username' do
      post :create, params: { password: 'password', username: 'baduser' }

      expect(flash[:error]).to match(/Authentication failed/)
    end

    it 'cannot login without username' do
      post :create, params: { password: 'password' }

      expect(flash[:error]).to match(/Authentication failed/)
    end

    it 'updates last login at if user logs in' do
      time = Time.zone.now
      expect_any_instance_of(ActiveSupport::TimeZone).to receive(:now).and_return(time)

      post :create, params: { password: 'password', username: 'bob' }

      users(:bob).reload
      expect(users(:bob).last_login_at.to_s).to eq time.to_s
    end

    it 'shows last login datetime and ip without country' do
      expect(GeoIp).to receive(:activated?).and_return(false).at_least(:once)

      user = users(:bob)
      user.update!(last_login_at: '2017-01-01 16:00:00 + 0000', last_login_from: '192.168.210.10')

      post :create, params: { password: 'password', username: 'bob' }
      expect(flash[:notice]).to eq 'The last login was on January 01, ' \
                                   '2017 16:00 from 192.168.210.10'
    end

    it 'does not show last login date if not available' do
      users(:bob).update!(last_login_at: nil)
      post :create, params: { password: 'password', username: 'bob' }
      expect(flash[:notice]).to be_nil
    end

    it 'does not show previous login ip if not available' do
      user = users(:bob)
      user.update!(last_login_at: '2017-01-01 16:00:00 + 0000', last_login_from: nil)

      post :create, params: { password: 'password', username: 'bob' }
      expect(flash[:notice]).to eq 'The last login was on January 01, 2017 16:00'
    end

    it 'shows previous login ip and country' do
      geo_ip = double
      expect(geo_ip).to receive(:country_code).at_least(:once).and_return('JP')
      expect(GeoIp).to receive(:activated?).at_least(:once).and_return(true)
      expect_any_instance_of(Flash::LastLoginMessage)
        .to receive(:geo_ip)
        .at_least(:once).and_return(geo_ip)

      user = users(:bob)
      user.update!(last_login_at: '2001-09-11 19:00:00 + 0000', last_login_from: '153.123.34.34')

      post :create, params: { password: 'password', username: 'bob' }
      expect(flash[:notice]).to eq 'The last login was on September 11, ' \
                                   '2001 19:00 from 153.123.34.34 (JP)'
    end
  end

  context 'GET sso' do
    it 'logs in User with Keycloak' do
      enable_keycloak
      expect(Keycloak::Client).to receive(:get_token_by_code)
        .and_return('asd')
        .at_least(:once)
      expect(Keycloak::Client).to receive(:get_attribute)
        .with('pk_secret_base')
        .and_return('')
        .at_least(:once)
      expect(Keycloak::Client).to receive(:get_attribute)
        .with('preferred_username')
        .and_return('ben')
        .at_least(:once)
      expect(Keycloak::Client).to receive(:get_attribute)
        .with('given_name')
        .and_return('Ben')
        .at_least(:once)
      expect(Keycloak::Client).to receive(:get_attribute)
        .with('family_name')
        .and_return('Meier')
        .at_least(:once)
      expect(Keycloak::Client).to receive(:get_attribute)
        .with('sub')
        .and_return('1234')
        .at_least(:once)
      expect(Keycloak::Client).to receive(:user_signed_in?)
        .and_return(true)
        .at_least(:once)

      get :sso, params: { code: 'asd' }
      expect(response).to redirect_to search_path
      user = User.find_by(username: 'ben')
      expect(user.username).to eq('ben')
      expect(session['username']).to eq('ben')
      expect(session['private_key']).to_not be_nil
    end

    it 'redirects to keycloak if not logged in' do
      enable_keycloak
      expect(Keycloak::Client)
        .to receive(:get_token_by_code)
        .and_return('asd')
      expect(Keycloak::Client)
        .to receive(:user_signed_in?)
        .and_return(false)
      expect(Keycloak::Client)
        .to receive(:url_login_redirect)
        .with('http://www.example.com' + session_sso_path, 'code')
        .and_return(session_sso_path)
        .at_least(:once)
      get :sso, params: { code: 'asd' }
      expect(response).to redirect_to session_sso_path
    end

    it 'redirects to normal login if keycloak disabled' do
      get :sso, params: { code: 'asd' }
      expect(response).to redirect_to teams_path
    end
  end

  context 'POST update_password' do
    it 'updates password' do
      login_as(:bob)
      post :update_password, params: { old_password: 'password', new_password1: 'test',
                                       new_password2: 'test' }

      expect(flash[:notice]).to match(/new password/)
      expect(users(:bob).authenticate_db('test')).to eq true
    end

    it 'updates password, error if oldpassword not match' do
      login_as(:bob)
      post :update_password, params: { old_password: 'wrong_password', new_password1: 'test',
                                       new_password2: 'test' }

      expect(flash[:error]).to match(/Invalid user \/ password/)
      expect(users(:bob).authenticate_db('test')).to be false
    end

    it 'updates password, error if new passwords not match' do
      login_as(:bob)
      post :update_password, params: { old_password: 'password', new_password1: 'test',
                                       new_password2: 'wrong_password' }

      expect(flash[:error]).to match(/New passwords not equal/)
      expect(users(:bob).authenticate_db('test')).to eq false
    end

    it 'redirects if ldap user tries to update password' do
      users(:bob).update!(auth: 'ldap')
      login_as(:bob)
      post :update_password, params: { old_password: 'password', new_password1: 'test',
                                       new_password2: 'test' }
      expect(response).to redirect_to teams_path
    end

    it 'redirects if keycloak user tries to update password' do
      users(:bob).update!(auth: 'keycloak')
      login_as(:bob)
      post :update_password, params: { old_password: 'password', new_password1: 'test',
                                       new_password2: 'test' }
      expect(response).to redirect_to teams_path
    end
  end
end
