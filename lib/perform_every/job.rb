require "action_view"

module PerformEvery
  class Job < ActiveRecord::Base
    include PerformEvery::Helper

    self.table_name = "perform_every"

    attr_accessor :accuracy

    def title
      return "#{self.job_name} every #{self.value}" if self.typ == "interval"
      return "#{self.job_name} at #{self.value}" if self.typ == "timestamp"
      raise "unknown typ"
    end

    def from_reflection_store(attr)
      s = PerformEvery::Reflection.find(self)
      return nil if s.nil?
      s.send(attr.to_sym)
    end

    def perform?(now = Time.now.utc)
      return false if self.deprecated
      return false if self.perform_at.blank?
      return false if self.too_old?(now)

      now >= self.perform_at && (self.last_performed_at.blank? || self.last_performed_at < self.perform_at)
    end

    def too_old?(now = Time.now.utc)
      raise "job is not scheduled to run because perform_at is nil" if self.perform_at.blank?
      accuracy = self.from_reflection_store(:accuracy) || PerformEvery::DEFAULT_ACCURACY
      now - self.perform_at >= accuracy
    end

    def perform!(now = Time.now.utc)
      return :skip_deprecated if self.perform_at.blank? || self.deprecated

      if self.too_old?(now)
        rescue_perform_at = self.perform_at
        self.perform_at = self.perform_once? ? nil : self.perform_next_at
        self.deprecated = self.perform_once?
        self.save!

        # prepare debug log
        log = []
        log << "'#{self.title}' was skipped."
        log << "It was scheduled for #{rescue_perform_at} but now it's #{distance(now, rescue_perform_at)} too late to still run the job."
        if self.perform_multi?
          log << "The job is scheduled to perform next in #{distance(now, self.perform_at)} at #{self.perform_at}."
        else
          log << "This one-time job will not be scheduled again."
        end
        Rails.logger.error log.join(" ")

        return :skip_too_old
      end

      if !self.perform?(now)
        # prepare debug log
        log = []
        log << "'#{self.title}' was skipped."
        perform_next_str = ""
        unless self.last_performed_at.blank?
          log << "It ran #{distance(now, self.last_performed_at)} ago."
          perform_next_str = "next"
        else
          perform_next_str = self.perform_once? ? "once" : "for the first time"
        end
        unless self.perform_at.blank?
          log << "The job is scheduled to perform #{perform_next_str} in #{distance(now, self.perform_at)} at #{self.perform_at}."
        end
        Rails.logger.debug log.join(" ")

        return :skip
      end

      # call the actual job
      schedule_error = nil
      unless PerformEvery.dry_run
        schedule_error = enqueue_job(self.job_name)
      end

      # prepare debug log
      log = []
      unless schedule_error
        log << "'#{self.title}' was scheduled."
      else
        log << "'#{self.title}' failed with error: #{schedule_error}."
      end
      if self.perform_multi?
        log << "The job is scheduled to perform next in #{distance(now, self.perform_next_at)} at #{self.perform_next_at}."
      else
        log << "This one-time job will not be scheduled again."
      end

      unless schedule_error
        Rails.logger.debug log.join(" ")
      else
        Rails.logger.error log.join(" ")
      end

      # log warning if job is performed with more than 1 minute delay
      if now - self.perform_at > 1.minute
        Rails.logger.warn "'#{self.title}' was run with a delay of #{distance(now, self.perform_at)}."
      end

      self.last_performed_at = now.utc
      self.add_history(self.last_performed_at)
      self.perform_at = self.perform_once? ? nil : self.perform_next_at
      self.deprecated = self.perform_once?
      self.save!

      return schedule_error.blank? ? :perform : :error
    end

    def add_history(t = Time.now.utc)
      self.history ||= []
      self.history << t.to_s
      self.history.shift(self.history.count - MAX_HISTORY) if self.history.count > MAX_HISTORY
    end

    def perform_next_at
      if self.typ == "interval"
        self.parse_interval_value.next_time.utc
      elsif self.typ == "timestamp"
        self.parse_timestamp_value.utc
      else
        raise "unknown typ"
      end
    end

    def parse_interval_value
      raise "must be interval" if self.value.blank?
      interval = ::Fugit::Nat.parse("every " + self.value, multi: :fail)
      raise "must be interval" if interval.blank? || !interval.is_a?(::Fugit::Cron)
      return interval
    end

    def parse_timestamp_value
      raise "must be timestamp" if self.value.blank?
      timestamp = ::Fugit::At.parse(self.value)
      raise "must be timestamp" if timestamp.blank? || !timestamp.is_a?(::EtOrbi::EoTime)
      return timestamp
    end

    def ==(j)
      self.job_name == j.job_name && self.typ == j.typ && self.value == j.value
    end

    def perform_once?
      self.typ == "timestamp"
    end

    def perform_multi?
      self.typ == "interval"
    end

    def mark_deprecated!
      self.deprecated = true
      self.save!
    end
  end
end
