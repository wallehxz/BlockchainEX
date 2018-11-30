class Settings < Fume::Settable::Base
  #ruby_provider Rails.root.join('config/settings.local.rb') if Rails.env.test?
  ruby_provider Rails.root.join('config/settings.rb')

  def self.method_missing(name, *args, &block)
    settings.send(name, *args, &block)
  end
end