require "perform_every/helper"
require "perform_every/job"
require "perform_every/reflection"
require "perform_every/scheduler"
require "perform_every/railtie"

require "fugit"

ActiveSupport.on_load(:active_job) do
  require "perform_every/activejob"
  ActiveJob::Base.send(:include, ::PerformEvery::ActiveJobExtension)
end

module PerformEvery
  DEFAULT_ACCURACY = 1.minute # must be >= 1 minute

  ADVISORY_LOCK_NAME = "perform_every_scheduler"
  SLEEP_INTERVAL = 30 # seconds (should be dividable by 2)
  MAX_HISTORY = 10

  mattr_accessor :dry_run, default: false
end
