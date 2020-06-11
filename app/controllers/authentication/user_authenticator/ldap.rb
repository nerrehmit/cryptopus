# frozen_string_literal: true

class Authentication::UserAuthenticator::Ldap < Authentication::UserAuthenticator

  def authenticate!
    return false if username == 'root'
    return false unless preconditions?
    return false if brute_force_detector.locked?

    authenticated = ldap_connection.authenticate!(username, password)

    authenticated
  end

  def authenticate_by_headers!
    return false if username == 'root'
    return false unless preconditions?
    return false if brute_force_detector.locked?


    if user.is_a?(User::Human)
      ldap_connection.authenticate!(username, password)
    else
      user.authenticate_db(password)
    end
  end

  def update_user_info(remote_ip)
    params = { last_login_from: remote_ip }
    params.merge(ldap_params) unless username == 'root'
    super(params)
  end

  def login_path
    session_new_path
  end

  private

  def find_or_create_user
    return unless params_present? && valid_username?

    user = User.find_by(username: username.strip)
    return create_user if user.nil? && ldap_connection.authenticate!(username, password)

    user
  end

  def ldap_params
    { givenname: ldap_connection.ldap_info(user.provider_uid, 'givenname'),
      surname: ldap_connection.ldap_info(user.provider_uid, 'sn') }
  end

  def create_user
    provider_uid = ldap_connection.uidnumber_by_username(username)
    User::Human.create(
      username: username,
      givenname: ldap_connection.ldap_info(provider_uid, 'givenname'),
      surname: ldap_connection.ldap_info(provider_uid, 'sn'),
      provider_uid: provider_uid,
      auth: 'ldap'
    ) { |u| u.create_keypair(password) }
  end

  def ldap_connection
    @ldap_connection ||= LdapConnection.new
  end
end
