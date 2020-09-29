module PerformEvery
  module Helper
    extend self
    include ActionView::Helpers::DateHelper

    def distance(a, b)
      distance_of_time_in_words(a, b)
    end

    def enqueue_job(job_name)
      begin
        return Object.const_get(job_name).send(:perform_later)
      rescue => e
        return e
      end
    end
  end
end
