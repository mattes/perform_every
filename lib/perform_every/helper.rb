module PerformEvery
  module Helper
    include ActionView::Helpers::DateHelper

    def distance(a, b)
      distance_of_time_in_words(a, b)
    end
  end
end
