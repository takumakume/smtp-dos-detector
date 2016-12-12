global_mutex = Mutex.new :global => true

class DosDetector
  attr_accessor :now

  def initialize config
    @cache = Cache.new :namespace => "smtp_dos_detector"
    @config = config
    @now = Time.now.to_i
    @counter_key = config[:counter_key].to_s
    config[:magic_str] ||= "...."
    @counter_key_time = "#{@counter_key}_#{config[:magic_str]}_time"
    @data = self._analyze

    self._detect @data
  end

  def analyze
    @data
  end

  def _analyze
    return nil if @counter_key.nil?

    # counter time when initialized counter
    prev = @cache[@counter_key_time].to_i
    diff = @now - prev

    # time initialized
    diff = 0 if prev.zero?
    {:time_diff => diff, :counter => @cache[@counter_key].to_i, :counter_key => @counter_key}
  end

  def init_cache data
    @cache[@counter_key] = 1.to_s if data[:counter] == 0
    @cache[@counter_key_time] = @now.to_s if data[:time_diff] == 0
  end

  def update_cache counter, date
    @cache[@counter_key] = (counter + 1).to_s
    @cache[@counter_key_time] = date.to_s
  end

  def detect? data=nil
    # run anlyze when data is nothing
    data = self.analyze if data.nil?
    return false if data.nil?

    thr = @config[:threshold_counter]
    thr_time = @config[:threshold_time]
    expire = @config[:expire_time]
    behind = @config[:behind_counter]
    cnt = data[:counter]
    diff = data[:time_diff]

    # When the number of e-mails over a certain time exceeds the threshold
    if cnt >= thr
      # And continuously If you are sending an email
      # (The time difference between the previous and current send times exceeds the threshold)
      0 <= diff && diff < thr_time ? true : false
    elsif cnt < 0
      # Is the counter expired?
      diff > expire ? false : true
    else
      false
    end
  end

  def _detect data=nil
    # run anlyze when data is nothing
    data = self.analyze if data.nil?
    return false if data.nil?

    self.init_cache data

    thr = @config[:threshold_counter]
    thr_time = @config[:threshold_time]
    expire = @config[:expire_time]
    behind = @config[:behind_counter]
    cnt = data[:counter]
    diff = data[:time_diff]

    if cnt >= thr
      if 0 <= diff && diff < thr_time
        self.update_cache behind, @now
      else
        self.update_cache 0, @now
      end
    elsif cnt < 0 && diff > expire
      self.update_cache 0, @now
    else
      self.update_cache cnt, (@now - diff)
    end
  end
end

target = Pmilter::Session.new.client_ipaddr

config = {
  :counter_key       => target,
  :threshold_time    => 10,
  :threshold_counter => 5,
  :expire_time       => 30,
  :behind_counter    => -10,
}

timeout = global_mutex.try_lock_loop(50000) do
  dos = DosDetector.new config
  data = dos.analyze
  p "smtp-dos-detector: analyze: #{data}"
  begin
    if dos.detect?
      p "smtp-dos-detector: detect: #{data}"
      Pmilter.status = Pmilter::SMFIS_REJECT
    end
  rescue => e
    raise "smtp-dos-detector: fail: #{e}"
  ensure
    global_mutex.unlock
  end
end
p "smtp-dos-detector: get timeout mutex lock, #{data}" if timeout
