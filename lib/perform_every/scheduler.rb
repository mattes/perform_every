require "with_advisory_lock"

module PerformEvery
  class Scheduler
    def run_forever
      Zeitwerk::Loader.eager_load_all # make sure all jobs are loaded

      # trap SIGINT and SIGTERM signals for clean shutdown
      kill = false
      Signal.trap("INT") { |s| kill = true }
      Signal.trap("TERM") { |s| kill = true }

      # try to continuously acquire advisory lock so that only one worker
      # at a time will schedule jobs. wait 5 seconds for lock, then try again after 30 seconds.
      loop do
        Rails.logger.info "Leader election: waiting to become master ..."
        ActiveRecord::Base.with_advisory_lock(ADVISORY_LOCK_NAME, timeout_seconds: 5) do
          Rails.logger.info "Leader election: I'm the master!"

          # persist new jobs in the database
          local_jobs_count = Scheduler.persist_jobs
          Rails.logger.info "Found #{local_jobs_count} job/s in local files"

          metrics = {}

          at_exit do
            Rails.logger.info "#{metrics}" unless metrics.blank?
            Rails.logger.info "Bye"
          end

          # start endless loop
          loop do
            Rails.logger.info "Running scheduler ..."

            # handle all jobs and schedule job if it's about time
            jobs = Job.where(:deprecated => false)
            jobs.each do |job|

              # check if job is still present in local job files
              if Reflection.store.include?(job)
                op = job.perform!
                metrics[op] ||= 0
                metrics[op] += 1
              else
                job.mark_deprecated!
              end

              return if kill
            end

            metrics[:total_jobs] = jobs.count
            Rails.logger.info "#{metrics}"
            metrics = {}

            if local_jobs_count > jobs.count + Job.where(:deprecated => true).count
              Rails.logger.warn "Unpersisted jobs found. Will retry to persist."
              Scheduler.persist_jobs
            end

            # go sleeping for SLEEP_INTERVAL and keep watching for kill commands
            (SLEEP_INTERVAL / 2).times do
              return if kill
              sleep 2 # seconds
            end
          end
        end

        # sleep for 30 seconds, keep watching for kill commands
        15.times do
          return if kill
          sleep 2
        end
      end # /loop around with_advisory_lock
    end

    private

    # insert new jobs to database
    def self.persist_jobs
      return 0 if Reflection.store.blank?
      Job.insert_all(Reflection.store.map { |j|
        {
          job_name: j.job_name,
          typ: j.typ,
          value: j.value,
          perform_at: j.perform_next_at,
        }
      })
      Reflection.store.count
    end

    def self.cleanup_deprecated_jobs
      Job.where(:deprecated => true).delete_all
    end

    def self.reset_jobs
      Job.connection.truncate(Job.table_name)
    end
  end
end
