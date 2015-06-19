require 'settingslogic'

class Settings < Settingslogic
  source 'config/settings.yml'
  namespace ENV['ALARM_ENV'] || 'development'
end
