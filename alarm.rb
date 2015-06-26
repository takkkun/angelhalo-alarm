require 'clockwork'
require 'twitter'
require 'logger'
require_relative 'settings'
require_relative 'jobs'

Clockwork.handler do |job|
  job.work
end

env    = Job::Environment.new
logger = Logger.new($stdout)
client = Twitter::REST::Client.new(Settings.twitter.client)

fetch = Jobs::Fetch.new(env, {
  logger: logger,
  client: client,
  target: 'granbluefantasy'
})

announce = Jobs::Announce.new(env, {
  logger: logger,
  client: client,
  text:   Settings.announce.text,
  part:   Settings.announce.part
})

alarm = Jobs::Alarm.new(env, {
  logger: logger,
  client: client,
  text:   Settings.alarm.text,
  users:  Settings.alarm.users
})

Clockwork.every(1.hour,   fetch)
Clockwork.every(5.minute, announce)
Clockwork.every(1.minute, alarm)
