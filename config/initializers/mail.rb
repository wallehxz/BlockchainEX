Mail.defaults do
  retriever_method :pop3,
    :address=> Settings.pop_host, :enable_ssl=> true, :port=> 995,
    :user_name=> Settings.pop_username,
    :password => Settings.pop_password
end