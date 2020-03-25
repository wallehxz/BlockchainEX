Mail.defaults do
  retriever_method :pop3,
    :address=> Settings.pop_host,
    :port=> 995,
    :enable_ssl=> true,
    :user_name=> Settings.pop_username,
    :password => Settings.pop_password
end