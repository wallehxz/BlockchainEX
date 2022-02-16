Mail.defaults do
  retriever_method :pop3,
    :address=> Setting.pop_host,
    :port=> 995,
    :enable_ssl=> true,
    :user_name=> Setting.pop_username,
    :password => Setting.pop_password
end