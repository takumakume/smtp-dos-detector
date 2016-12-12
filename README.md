# smtp-dos-detector

Detect huge number of emails on pmiler using mruby scirpt.

### Install pmilter

- See: https://github.com/matsumotory/pmilter

### Install smtp-dos-detector

- clone this repository
- edit `pmilter.conf`

  ```yaml
   : (snip)
  [handler]
  # connection info filter hhandler/connect.rb"
  mruby_connect_handler = "handler/smtp-dos-detector/src/smtp_dos_detector.rb"
   : (snip)
  ```

### Usage smtp-dos-detector

- handler/smtp-dos-detector/src/smtp_dos_detector.rb

  ```ruby
   : (snip DosDetector class)

  #
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
  ```

- detail description config

  ```ruby
   : (snip)
  config = {
    :counter_key       => target,
    :threshold_time    => 10,
    :threshold_counter => 5,
    :expire_time       => 30,
    :behind_counter    => -10,
  }
   : (snip)
  ```

  - Target `(counter_key)` will block 10 emails `(behind_counter)` for 30 seconds `(expire_time)` if you send 5 emails `(threshold_counter)` in 10 seconds `(threshold_time)`

### pmilter + smtp-dos-detector works

- send some mails

  ```
  echo "test" | mail -s "test" user@hoge.local
  ```

- pmilter log

  ```
  # 1 mail is permit
  "smtp-dos-detector: analyze: {:time_diff=>0, :counter=>0, :counter_key=>\"127.0.0.1\"}"
  # 2 mail is permit
  "smtp-dos-detector: analyze: {:time_diff=>2, :counter=>1, :counter_key=>\"127.0.0.1\"}"
  # 3 mail is permit
  "smtp-dos-detector: analyze: {:time_diff=>4, :counter=>2, :counter_key=>\"127.0.0.1\"}"
  # 4 mail is permit
  "smtp-dos-detector: analyze: {:time_diff=>4, :counter=>3, :counter_key=>\"127.0.0.1\"}"
  # 5 mail is permit
  "smtp-dos-detector: analyze: {:time_diff=>6, :counter=>4, :counter_key=>\"127.0.0.1\"}"
  # 6 mail is reject
  "smtp-dos-detector: analyze: {:time_diff=>7, :counter=>5, :counter_key=>\"127.0.0.1\"}"
  "smtp-dos-detector: detect: {:time_diff=>7, :counter=>5, :counter_key=>\"127.0.0.1\"}"
  ```

  - 6 mail: reject log from postfix

    ```
    Dec 12 14:14:43 pmilter sendmail[5143]: uBCEEhjZ005143: to=postmaster, delay=00:00:00, xdelay=00:00:00, mailer=relay, pri=32273, relay=[127.0.0.1], dsn=5.0.0, stat=Service unavailable
    ```

  ```
  # 7 mail is reject
  "smtp-dos-detector: analyze: {:time_diff=>0, :counter=>-9, :counter_key=>\"127.0.0.1\"}"
  "smtp-dos-detector: detect: {:time_diff=>0, :counter=>-9, :counter_key=>\"127.0.0.1\"}"
    :
  # 15 mail is reject
  "smtp-dos-detector: analyze: {:time_diff=>8, :counter=>-1, :counter_key=>\"127.0.0.1\"}"
  "smtp-dos-detector: detect: {:time_diff=>8, :counter=>-1, :counter_key=>\"127.0.0.1\"}"
  # 16 mail is permit
  "smtp-dos-detector: analyze: {:time_diff=>9, :counter=>0, :counter_key=>\"127.0.0.1\"}"
  # 17 mail is permit
  "smtp-dos-detector: analyze: {:time_diff=>10, :counter=>1, :counter_key=>\"127.0.0.1\"}"
    :
    :
  ```
