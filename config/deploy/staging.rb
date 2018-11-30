set :branch, 'master'
set :rails_env, 'production'
set :rvm_ruby_version, '2.3.0'
set :rvm_type, :user
set :deploy_to, '/var/www/block'
set :rvm_custom_path, '/home/deploy/.rvm'
set :rvm_roles, [:app, :web]

server 'deploy@127.0.0.1', user: 'deploy', port: 22, roles: %w[web app db], primary: true