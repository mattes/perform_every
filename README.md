# perform_every

Cron jobs for Rails. Just add `perform_every "5 minutes"` to any job.

Requires Postgres and a configured Rails' ActiveJob adapter, 
like [delayed_job](https://github.com/collectiveidea/delayed_job) or
[sidekiq](https://github.com/mperham/sidekiq).


## Usage

Include `gem 'perform_every'` and then run:

```
bundle install
rails generate perform_every:active_record
rails db:migrate
```

Create a new job `app/jobs/example_job.rb`:

```ruby
class ExampleJob < ApplicationJob
  queue_as :default

  # multiple perform_every and perform_at are allowed
  perform_every "10 minutes"
  perform_at "October 1st, 2030"
  perform_at "October 1st, 2050"

  # This job runs every 10 minutes and on October 1st, 2030 and 2050.
  # No `perform` parameters are allowed, because `perform_every` will
  # just use the configured `Rails.config.active_job.queue_adapter` to
  # queue this job.
  def perform
    User.all.each do |user|
      send_cat_meme(user) #priceless
    end
  end
end
```

Finally start the worker which will enqueue jobs:

```
rails perform_every:run
```

---

### `perform_every`

```ruby
perform_every "interval", {:accuracy => 1.minute}

perform_every "day at five"
perform_every "weekday at five"
perform_every "day at 5 pm"
perform_every "tuesday at 5 pm"
perform_every "wed at 5 pm"
perform_every "day at 16:30"
perform_every "day at noon"
perform_every "day at midnight"
perform_every "tuesday"
perform_every "day at 5 pm on America/Los_Angeles"
perform_every "day at 6 pm in Asia/Tokyo"
perform_every "3 hours"
perform_every "4 months"
perform_every "5 minutes"
```
  
  * `interval` should be >= 1.minute
  * `interval` default timezone is UTC
  * `accuracy` is set to `1.minute` by default (see notes below)
  * multiple unique `perform_every` can be added

---

### `perform_at`

```ruby
perform_at "timestamp", {:accuracy => 1.minute}

perform_at "2017-12-12"
perform_at "2017-12-12 12:00:00 America/New_York"
perform_at "October 1st, 2050"
```
  
  * `timestamp` default timezone is UTC 
  * `accuracy` is set to `1.minute` by default (see notes below)
  * multiple unique `perform_at` an be added

---

## Commands

```
rails perform_every:run     # Run scheduler
rails perform_every:cleanup # Remove deprecated jobs from database
rails perform_every:reset   # Reset persisted jobs in database
```


## Notes

  * Several workers (`rails perform_every:run`) can be started. During a leader election phase
    one worker will become master. This is done via 
    [Postgres Advisory Locks](https://www.postgresql.org/docs/11/explicit-locking.html#ADVISORY-LOCKS) 
    and [with_advisory_lock gem](https://github.com/ClosureTree/with_advisory_lock).
    An `exclusive session level advisory lock` is obtained. If the worker dies, another
    worker will become master and take over.
  * Workers will only enqueue jobs to your backend queue adapter.
  * Workers will gracefully shutdown when SIGINT or SIGTERM is received.
  * Job state is persited in Postgres in table `perform_every`.
  * `perform_at` and `perform_every` statements can be added and removed between deploys,
    the workers support rolling deploys. Obsolete jobs are marked as `deprecated` in table `perform_every`.
    Run `rails perform_every:cleanup` after deploys to delete deprecated tasks.
  * Enable `Rails.config.log_level = :debug` to output verbose logging to understand scheduling logic.
  * Accuracy is set to 1 minute by default. If a job is scheduled to run at 4:00pm, the perform_every 
    worker has until 4:01pm to actually schedule the job.  
    Accuracy is important in case things go wrong. 
    Here is another example: Every day at 8am a job is supposed to send out email newsletters.
    This can only happen between 8am and 9am. `perform_every "day at 8am", {:accuracy => 1.hour}`
    ensures that if no workers are alive between 8am and 9am the newsletter job would not 
    be scheduled after 9:01am anymore.
