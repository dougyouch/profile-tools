
ObjectSpace.count_objects

module ProfileTools
  def self.instrument_count_objects
    start_counts = ObjectSpace.count_objects
    start_counts[:T_HASH] += 1
    yield
    end_counts = ObjectSpace.count_objects
    diff = {}
    end_counts.each do |name, count|
      diff_count = count - start_counts[name]
      diff[name] = diff_count if diff_count != 0
    end
    diff
  end
end
