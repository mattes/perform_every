module PerformEvery
  module ActiveJobExtension
    extend ActiveSupport::Concern

    # pattern from:
    # https://guides.rubyonrails.org/plugins.html#add-an-acts-as-method-to-active-record
    # and https://github.com/rails/rails/blob/master/activerecord/lib/active_record/associations.rb

    class_methods do
      def perform_every(interval, opts = {})
        j = Job.new
        j.job_name = self.name
        j.typ = "interval"
        j.value = interval.strip
        j.accuracy = opts[:accuracy]

        if j.value.blank?
          raise "#{self.name}#perform_every needs interval"
        end

        PerformEvery::Reflection.insert(j)
      end

      def perform_at(timestamp, opts = {})
        j = Job.new
        j.job_name = self.name
        j.typ = "timestamp"
        j.value = timestamp.strip
        j.accuracy = opts[:accuracy]

        if j.value.blank?
          raise "#{self.name}#perform_at needs timestamp"
        end

        PerformEvery::Reflection.insert(j)
      end
    end
  end
end
