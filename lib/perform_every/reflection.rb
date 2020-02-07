module PerformEvery

  module Reflection
    mattr_reader :store, default: []

    # insert into store, ignoring duplicates
    def self.insert(job)
      return false if @@store.include?(job)
      @@store << job
      true
    end

    def self.find(job)
      i = @@store.index(job)
      return nil if i.nil?
      @@store[i] 
    end
  end

end
