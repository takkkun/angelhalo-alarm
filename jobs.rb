require 'logger'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/numeric/time'

class Job
  def initialize(environment, options = {})
    options = options.dup
    @environment = environment
    @logger = options.delete(:logger) || Logger.new(File.open(File::NULL, 'w'))
    @options = options
  end

  attr_reader :environment
  alias env environment

  attr_reader :logger, :options

  class Environment < Hash
  end
end

module AngelHalo
  class Schedule
    include Enumerable

    class ParseError < StandardError; end

    def self.parse(text)
      date_line, *group_lines = text.lines.map(&:rstrip)

      date_line_match = date_line.match(/\A【グランブルーファンタジー】【時限クエ】(\d+)\/(\d+)\([^\)]+\)\z/)
      raise ParseError, 'date line (header) is missing' unless date_line_match

      month, day = date_line_match.captures.map(&:to_i)
      hours = {}

      group_lines.each_slice(5).take(4).each do |lines|
        group_line, *time_lines = lines.take(4)

        group_line_match = group_line.match(/\Aグループ(\w+)&amp;(\w+)\z/)
        raise ParseError, 'group line is missing' unless group_line_match

        groups = group_line_match.captures.map(&:upcase)

        bonus_time_line = time_lines.find { |l| l.end_with?('★') }
        raise ParseError, 'bonus time line is missing' unless bonus_time_line

        hour = bonus_time_line.to_i

        groups.each do |group|
          hours[group.upcase] = hour
        end
      end

      new(month, day, hours)
    end

    def initialize(month, day, hours)
      @month = month
      @day   = day
      @hours = hours
    end

    attr_reader :month, :day, :hours

    def each(&block)
      @hours.each(&block)
    end
  end
end

module Jobs
  class Fetch < Job
    def work
      params = {}
      params[:since_id] = env[:since_id] if env[:since_id]
      tweets = options[:client].user_timeline(options[:target], params)

      if tweets.empty?
        logger.info('Fetch no tweets')
      else
        oldest_tweet_id = tweets.last.id
        newest_tweet_id = tweets.first.id

        if oldest_tweet_id == newest_tweet_id
          logger.info("Fetch tweet: #{oldest_tweet_id}")
        else
          logger.info("Fetch tweets: #{oldest_tweet_id}..#{newest_tweet_id}")
        end
      end

      schedules = tweets.map { |tweet|
                    begin
                      AngelHalo::Schedule.parse(tweet.text)
                    rescue AngelHalo::Schedule::ParseError => ex
                      logger.info("Failed to parse the tweet as Angel Halo's schedule: #{ex.message}")
                      nil
                    end
                  }.compact

      schedules.each do |schedule|
        schedule.each do |(group, hour)|
          logger.info("Set schedule for #{group} group with #{schedule.month}/#{schedule.day} #{hour}")
        end
      end

      env[:schedules] = [*env[:schedules], *schedules]
      env[:since_id] = tweets.first.id unless tweets.empty?
    end
  end

  class Announce < Job
    def work
      now = Time.now.utc.getlocal('+09:00')

      schedule = (env[:schedules] || []).find do |schedule|
        schedule.month == now.month && schedule.day == now.day
      end

      return unless schedule
      return unless now.hour == 0

      key = :"schedule:#{schedule.month}:#{schedule.day}:announced"
      return if env[key]

      time_table = schedule.hours.reduce({}) do |time_table, (group, hour)|
        time_table.merge(hour => [*time_table[hour], group])
      end

      time_lines = time_table.keys.sort.map do |hour|
        groups = time_table[hour]
        groups_string = groups.map { |group| "#{group}グループ" }.join(', ')
        options[:part] % {hour: hour, groups: groups_string}
      end

      date = Time.new(now.year, schedule.month, schedule.day, 0, 0, 0, '+09:00')

      options[:client].update(options[:text] % {
        month: date.month,
        day:   date.day,
        week:  '日月火水木金土'[date.wday],
        body:  time_lines.join("\n")
      })

      env[key] = true
    end
  end

  class Alarm < Job
    def initialize(environment, options = {})
      super

      @users = options[:users].reduce({}) do |users, user|
        user = user.symbolize_keys
        name = user[:name]
        group = user[:group].upcase
        users.merge(group => [*users[group], name])
      end
    end

    def work
      now = Time.now.utc.getlocal('+09:00')

      schedule = (env[:schedules] || []).find do |schedule|
        schedule.month == now.month && schedule.day == now.day
      end

      return unless schedule

      @users.each do |(group, names)|
        key = :"schedule:#{schedule.month}:#{schedule.day}:#{group}:notified"
        next if env[key]

        scheduled_time = Time.new(now.year, schedule.month, schedule.day, schedule.hours[group], 0, 0, '+09:00')
        alarm_term = (scheduled_time - 1.minute)..(scheduled_time + 1.hour)
        next unless alarm_term.cover?(now)

        options[:client].update(options[:text] % {
          recipients: names.map { |name| "@#{name}" }.join(' '),
          group:      group,
          hour:       schedule.hours[group]
        })

        env[key] = true
      end
    end
  end
end
