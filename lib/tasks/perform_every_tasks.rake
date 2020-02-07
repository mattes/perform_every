namespace :perform_every do

  desc "Run scheduler"
  task run: :environment do
    s = PerformEvery::Scheduler.new 
    s.run_forever
  end

  desc "Remove deprecated jobs"
  task cleanup: :environment do
    PerformEvery::Scheduler.cleanup_deprecated_jobs
  end

  desc "Reset jobs"
  task reset: :environment do
    PerformEvery::Scheduler.reset_jobs
  end

end
