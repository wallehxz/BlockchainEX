# config valid only for current version of Capistrano
#lock '3.4.1'

set :application, 'trading'
set :repo_url, 'https://github.com/wallehxz/BlockchainEX.git'
set :ssh_options, { keys: %w{~/.ssh/id_rsa}, forward_agent: true, auth_methods: %w(publickey) }
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
  config/settings.yml
}

set :linked_dirs, %w{
  log
  tmp/cache
  tmp/pids
  tmp/sockets
  tmp/log
  public/logger
  public/uploads
}

namespace :deploy do

  desc '预创建项目配置文档'
  task :touch_linked_files do
    on roles(:app) do
      info '预创建项目配置文档...'
      execute :touch, "#{deploy_to}/shared/config/database.yml"
      execute :touch, "#{deploy_to}/shared/config/secrets.yml"
      execute :touch, "#{deploy_to}/shared/config/settings.yml"
    end
  end

  desc '上传项目配置文档'
  task :upload_linked_files do
    on roles(:app) do
      info '上传项目配置文档...'
      upload! 'config/pdatabase.yml', "#{deploy_to}/shared/config/database.yml"
      upload! 'config/psecrets.yml', "#{deploy_to}/shared/config/secrets.yml"
      upload! 'config/psettings.yml', "#{deploy_to}/shared/config/settings.yml"
    end
  end

  desc '安装生产环境依赖 Gems'
  task :bundle_install do
    on roles(:app) do
      within release_path do
        info "安装生产环境依赖 Gems...#{release_path}"
        execute " bundle install --path #{deploy_to}/shared/bundle --without development test  --deployment"
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

  desc '本地编译样式文件上传至服务器'
  task :local_compile_upload do
    run_locally do
      info "清除旧版编译文件..."
      execute 'rake assets:clobber'
      info "编译本地项目样式文件..."
      execute 'rake assets:precompile RAILS_ENV=production'
      info '上传本地编译文件至服务器...'
      execute "rsync -avz public/assets zalle@block.xfgll.xyz:#{shared_path}/public"
    end
  end

end


# 跳过 precompile
Rake::Task['deploy:assets:precompile'].clear_actions
after 'bundler:install', 'deploy:local_compile_upload'
# Rake::Task['whenever:update_crontab'].clear_actions

# 在项目部署完成后再更新定时任务

# 第一次执行部署
# before 'deploy:check:linked_files', 'deploy:touch_linked_files'
# before 'deploy:check:linked_files', 'deploy:upload_linked_files'
# before 'deploy:migrate', 'deploy:db_create'

# after 'deploy:cleanup', 'deploy:update_crontab'
