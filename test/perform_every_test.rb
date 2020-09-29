require "test_helper"

class PerformEvery::Test < ActiveSupport::TestCase
  setup do
    Zeitwerk::Loader.eager_load_all # make sure all jobs are loaded
    PerformEvery.dry_run = true
  end

  test "truth" do
    assert_kind_of Module, PerformEvery
  end

  test "job can still be scheduled regularly" do
    assert_equal "example job without perform_every and perform_at", ExampleJob1.perform_now
    assert_equal "example job with perform_every", ExampleJob2.perform_now
    assert_equal "example job with perform_at", ExampleJob3.perform_now
    assert_equal "example job with perform_every and perform_at", ExampleJob4.perform_now
    assert_equal "example job with multiple perform_every and perform_at", ExampleJob5.perform_now
    assert_equal "example job with a default variable: default", ExampleJob6.perform_now
    assert_equal "example job with a default variable: foo", ExampleJob6.perform_now("foo")
    assert_equal "example job with a variable: foo", ExampleJob7.perform_now("foo")
  end

  test "jobs are inserted into reflection store" do
    assert_equal 12, PerformEvery::Reflection.store.count

    assert PerformEvery::Reflection.store.include?(PerformEvery::Job.new(job_name: "ExampleJob2", typ: "interval", value: "10 minutes"))
    assert PerformEvery::Reflection.store.include?(PerformEvery::Job.new(job_name: "ExampleJob3", typ: "timestamp", value: "October 1st, 2050"))
    assert PerformEvery::Reflection.store.include?(PerformEvery::Job.new(job_name: "ExampleJob4", typ: "interval", value: "10 minutes"))
    assert PerformEvery::Reflection.store.include?(PerformEvery::Job.new(job_name: "ExampleJob4", typ: "timestamp", value: "October 1st, 2050"))
    assert PerformEvery::Reflection.store.include?(PerformEvery::Job.new(job_name: "ExampleJob5", typ: "interval", value: "10 minutes"))
    assert PerformEvery::Reflection.store.include?(PerformEvery::Job.new(job_name: "ExampleJob5", typ: "timestamp", value: "October 1st, 2050"))
    assert PerformEvery::Reflection.store.include?(PerformEvery::Job.new(job_name: "ExampleJob5", typ: "interval", value: "3 days"))
    assert PerformEvery::Reflection.store.include?(PerformEvery::Job.new(job_name: "ExampleJob5", typ: "timestamp", value: "October 2st, 2050"))
    assert PerformEvery::Reflection.store.include?(PerformEvery::Job.new(job_name: "ExampleJob6", typ: "interval", value: "10 minutes"))
    assert PerformEvery::Reflection.store.include?(PerformEvery::Job.new(job_name: "ExampleJob6", typ: "timestamp", value: "October 1st, 2050"))
    assert PerformEvery::Reflection.store.include?(PerformEvery::Job.new(job_name: "ExampleJob7", typ: "interval", value: "10 minutes"))
    assert PerformEvery::Reflection.store.include?(PerformEvery::Job.new(job_name: "ExampleJob7", typ: "timestamp", value: "October 1st, 2050"))
  end

  test "persist jobs in database" do
    # create existing ExampleJob2
    now = Time.now.round # round to accommodate postgres precision
    job2 = PerformEvery::Job.create!(job_name: "ExampleJob2", typ: "interval", value: "10 minutes", last_performed_at: now)

    # persist all jobs, skip ExampleJob2
    PerformEvery::Scheduler.persist_jobs
    PerformEvery::Scheduler.persist_jobs # persist again
    assert_equal 12, PerformEvery::Job.all.count

    # confirm ExampleJob2 was skipped, because it already exists (see above)
    jobs = PerformEvery::Job.all
    assert_equal now, jobs[jobs.index(job2)].last_performed_at
  end

  test "if jobs should be performed" do
    today = Time.now.utc
    now = Time.utc(today.year, today.month, today.day, 18, 0, 0)

    # don't perform if perform_at is nil
    assert !PerformEvery::Job.create(perform_at: nil, last_performed_at: nil).perform?(now)

    # don't perform if job is marked as deprecated
    assert !PerformEvery::Job.create(perform_at: now, last_performed_at: nil, deprecated: true).perform?(now)

    # perform if a job that has never run before
    assert PerformEvery::Job.create(perform_at: now, last_performed_at: nil).perform?(now)

    # don't perform if a job just ran
    assert !PerformEvery::Job.create(perform_at: now, last_performed_at: now).perform?(now)

    # don't perform if job should run in the future
    assert !PerformEvery::Job.create(perform_at: now + 1.minute, last_performed_at: now).perform?(now)
    assert !PerformEvery::Job.create(perform_at: now + 1.hour, last_performed_at: now).perform?(now)
    assert !PerformEvery::Job.create(perform_at: now + 1.day, last_performed_at: now).perform?(now)

    # perform if a job needs to run again
    assert PerformEvery::Job.create(perform_at: now + 1.minute, last_performed_at: now).perform?(now + 1.minute)
    assert PerformEvery::Job.create(perform_at: now + PerformEvery::DEFAULT_ACCURACY, last_performed_at: now).perform?(now + PerformEvery::DEFAULT_ACCURACY)

    # skip job if we can't run it timely (meaning delta between perform_at and now is too big)
    assert !PerformEvery::Job.create(perform_at: now + PerformEvery::DEFAULT_ACCURACY, last_performed_at: now).perform?(now + PerformEvery::DEFAULT_ACCURACY + 1.hour)
    assert !PerformEvery::Job.create(perform_at: now + PerformEvery::DEFAULT_ACCURACY, last_performed_at: now).perform?(now + PerformEvery::DEFAULT_ACCURACY + 2.hour)
  end

  test "don't perform if perform_at is nil" do
    # test for typ: interval
    job = PerformEvery::Job.create(job_name: "Job", typ: "interval", value: "10 minutes")
    assert_equal :skip_deprecated, job.perform!

    # test for typ: timestamp
    job = PerformEvery::Job.create(job_name: "Job", typ: "timestamp", value: "October 1st, 2050")
    assert_equal :skip_deprecated, job.perform!
  end

  test "don't perform if job is marked as deprecated" do
    # test for typ: interval
    job = PerformEvery::Job.create(job_name: "Job", typ: "interval", value: "10 minutes", deprecated: true)
    assert_equal :skip_deprecated, job.perform!

    # test for typ: timestamp
    job = PerformEvery::Job.create(job_name: "Job", typ: "timestamp", value: "October 1st, 2050", deprecated: true)
    assert_equal :skip_deprecated, job.perform!
  end

  test "don't perform! if job is too old" do
    today = Time.now.utc
    now = Time.utc(today.year, today.month, today.day, 18, 0, 0)

    # test for typ: interval
    job = PerformEvery::Job.create(job_name: "Job", typ: "interval", value: "10 minutes", perform_at: now)
    job.stub :perform_next_at, now + 10.minutes do
      assert_equal :skip_too_old, job.perform!(now + PerformEvery::DEFAULT_ACCURACY)
      assert_equal now + 10.minutes, job.perform_at
    end

    # test for typ: timestamp
    job = PerformEvery::Job.create(job_name: "Job", typ: "timestamp", value: now.strftime("%B %e, %Y"), perform_at: now)
    job.stub :perform_next_at, now do
      assert_equal :skip_too_old, job.perform!(now + PerformEvery::DEFAULT_ACCURACY)
      assert_nil job.perform_at
    end
  end

  test "don't perform! if job already ran" do
    today = Time.now.utc
    now = Time.utc(today.year, today.month, today.day, 18, 0, 0)

    # test for typ: interval
    job = PerformEvery::Job.create(job_name: "Job", typ: "interval", value: "10 minutes", last_performed_at: now, perform_at: now + 10.minute)
    job.stub :perform_next_at, now + 10.minutes do
      assert_equal :skip, job.perform!(now)
      assert_equal now + 10.minutes, job.perform_at
    end
    #
    # test for typ: timestamp
    job = PerformEvery::Job.create(job_name: "Job", typ: "timestamp", value: now.strftime("%B %e, %Y"), last_performed_at: now, perform_at: nil)
    job.stub :perform_next_at, now do
      assert_equal :skip_deprecated, job.perform!(now)
      assert_nil job.perform_at
    end
  end

  test "perform! if job needs to run" do
    today = Time.now.utc
    now = Time.utc(today.year, today.month, today.day, 18, 0, 0)

    # test for typ: interval
    job = PerformEvery::Job.create(job_name: "Job", typ: "interval", value: "10 minutes", last_performed_at: now - 10.minutes, perform_at: now)
    job.stub :perform_next_at, now + 10.minutes do
      assert_equal :perform, job.perform!(now)
      assert_equal now, job.last_performed_at
      assert_equal now + 10.minutes, job.perform_at
      assert_equal [now], job.history
    end

    # test for typ: timestamp
    job = PerformEvery::Job.create(job_name: "Job", typ: "timestamp", value: now.strftime("%B %e, %Y"), last_performed_at: nil, perform_at: now)
    job.stub :perform_next_at, now do
      assert_equal :perform, job.perform!(now)
      assert_equal now, job.last_performed_at
      assert_nil job.perform_at
      assert_equal [now], job.history
    end
  end

  test "Job#history has max n items" do
    t1 = Time.now - 2.days
    t2 = Time.now - 1.days

    job = PerformEvery::Job.new

    job.add_history t1
    job.add_history t2

    (PerformEvery::MAX_HISTORY - 2).times do
      job.add_history
    end

    assert_equal PerformEvery::MAX_HISTORY, job.history.count
    assert_equal t1.to_s, job.history[0]
    assert_equal t2.to_s, job.history[1]

    job.add_history
    assert_equal PerformEvery::MAX_HISTORY, job.history.count
    assert_equal t2.to_s, job.history[0]

    100.times do
      job.add_history
    end
    assert_equal PerformEvery::MAX_HISTORY, job.history.count
  end

  test "Job#perform_next_at" do
    # test for typ: interval
    job = PerformEvery::Job.new(typ: "interval", value: "20 minutes")
    assert job.perform_next_at > Time.now

    job = PerformEvery::Job.new(typ: "interval", value: "")
    assert_raises do
      job.perform_next_at
    end

    job = PerformEvery::Job.new(typ: "interval", value: "bogus")
    assert_raises do
      job.perform_next_at
    end

    # test for typ: timestamp
    job = PerformEvery::Job.new(typ: "timestamp", value: "October 1st, 2050")
    assert job.perform_next_at > Time.now

    job = PerformEvery::Job.new(typ: "timestamp", value: "")
    assert_raises do
      job.perform_next_at
    end

    job = PerformEvery::Job.new(typ: "timestamp", value: "bogus")
    assert_raises do
      job.perform_next_at
    end
  end

  test "Job#parse_interval_value" do
    job = PerformEvery::Job.new(value: "20 minutes")
    assert job.parse_interval_value
  end

  test "Job#parse_timestamp_value" do
    job = PerformEvery::Job.new(value: "October 1st, 2050")
    assert job.parse_timestamp_value
  end

  test "jobs are equal" do
    jobA1 = PerformEvery::Job.new(job_name: "Job", typ: "timestamp", value: "October 1st, 2050", last_performed_at: Time.now - 10.minutes, perform_at: Time.now)
    jobA2 = PerformEvery::Job.new(job_name: "Job", typ: "timestamp", value: "October 1st, 2050")
    jobB = PerformEvery::Job.new(job_name: "Job1", typ: "timestamp", value: "October 1st, 2050")
    jobC = PerformEvery::Job.new(job_name: "Job", typ: "interval", value: "October 1st, 2050")
    jobD = PerformEvery::Job.new(job_name: "Job", typ: "timestamp", value: "October 2st, 2050")

    assert jobA1 == jobA2
    assert jobA2 != jobB
    assert jobA2 != jobC
    assert jobA2 != jobC
    assert jobA2 != jobD
  end

  test "Job@too_old?" do
    today = Time.now.utc
    now = Time.utc(today.year, today.month, today.day, 18, 0, 0)

    job = PerformEvery::Job.create(perform_at: now + 61.second, accuracy: 1.minute)
    assert !job.too_old?(now)

    job = PerformEvery::Job.create(perform_at: now + 60.second, accuracy: 1.minute)
    assert !job.too_old?(now)

    job = PerformEvery::Job.create(perform_at: now + 59.second, accuracy: 1.minute)
    assert !job.too_old?(now)

    job = PerformEvery::Job.create(perform_at: now, accuracy: 1.minute)
    assert !job.too_old?(now)

    job = PerformEvery::Job.create(perform_at: now - 59.second, accuracy: 1.minute)
    assert !job.too_old?(now)

    job = PerformEvery::Job.create(perform_at: now - 60.second, accuracy: 1.minute)
    assert job.too_old?(now)

    job = PerformEvery::Job.create(perform_at: now - 61.second, accuracy: 1.minute)
    assert job.too_old?(now)
  end

  test "enqueue_job" do
    assert_instance_of ExampleJob1, PerformEvery::Helper.enqueue_job("ExampleJob1")
    assert_instance_of ExampleJob2, PerformEvery::Helper.enqueue_job("ExampleJob2")
    assert_instance_of ExampleJob3, PerformEvery::Helper.enqueue_job("ExampleJob3")
    assert_instance_of ExampleJob4, PerformEvery::Helper.enqueue_job("ExampleJob4")
    assert_instance_of ExampleJob5, PerformEvery::Helper.enqueue_job("ExampleJob5")
    assert_instance_of ExampleJob6, PerformEvery::Helper.enqueue_job("ExampleJob6")

    assert_instance_of ArgumentError, PerformEvery::Helper.enqueue_job("ExampleJob7")
  end
end
