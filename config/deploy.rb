# config valid only for current version of Capistrano
#lock '3.4.1'

set :application, 'ExTrade'
set :repo_url, 'https://github.com/kooogle/Exchange_Trade.git'
set :ssh_options, { keys: %w{~/.ssh/id_rsa}, forward_agent: true, auth_methods: %w(publickey) }
set :scm, :git
# set :format, :pretty
set :log_level, :debug
set :keep_assets, 2
set :keep_releases, 3

SSHKit.config.command_map[:rake] = 'bundle exec rake'
SSHKit.config.command_map[:rails] = 'bundle exec rails'

#Puma Server
set :puma_init_active_record, true

set :linked_files, %w{
  config/database.yml
  config/secrets.yml
  config/settings.rb
}

set :linked_dirs, %w{
  log
  tmp/cache
  tmp/pids
  tmp/sockets
  tmp/logs
  public/logger
  public/uploads
}

namespace :deploy do

  desc '管理数据库配置文件'
  task :setup_config do
    on roles(:web) do |host|
      execute :mkdir, "-p #{deploy_to}/shared/config"
      upload! 'config/database.yml.sample', "#{deploy_to}/shared/config/database.yml"
      upload! 'config/secrets.yml.sample', "#{deploy_to}/shared/config/secrets.yml"
    end
  end

  desc '重启服务'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  desc '将配置数据写入数据库'
  task :seed do
    on roles(fetch(:migration_role)) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'db:seed'
        end
      end
    end
  end

  desc "创建项目数据库"
  task :db_create do
    on roles(fetch(:migration_role)) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'db:create'
        end
      end
    end
  end
end

namespace :daemons do
  desc "开启进程"
  task :start do
    on roles(:web) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'daemons:start'
          info "开启后台进程..."
        end
      end
    end
  end

  desc "停止进程"
  task :stop do
    on roles(:web) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'daemons:stop'
          info "停止后台进程..."
        end
      end
    end
  end
end

# after 'deploy:finished', 'daemons:stop'
# after 'daemons:stop','daemons:start'
# before 'deploy:migrate', 'deploy:db_create'
