# ProfileTools

Find the code that allocates the most objects and triggers the most garbage collection, in production, without changing that code.

List the methods you suspect in a YAML file and restart. Every request then logs, for each listed method, how many times it was called, how long it took, how many objects it allocated and how many garbage collections ran inside it. Remove the file and restart to turn it off.

[![CI](https://github.com/dougyouch/profile-tools/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/dougyouch/profile-tools/actions/workflows/ci.yml)
[![Coverage](https://raw.githubusercontent.com/dougyouch/profile-tools/badges/coverage.svg)](https://github.com/dougyouch/profile-tools/actions/workflows/ci.yml)
[![Branch Coverage](https://raw.githubusercontent.com/dougyouch/profile-tools/badges/branches.svg)](https://github.com/dougyouch/profile-tools/actions/workflows/ci.yml)

[API reference](https://rubydoc.info/gems/profile-tools) · [Upgrading from 0.1](UPGRADING.md) · [Changelog](CHANGELOG.md) · [Architecture](ARCHITECTURE.md)

```
[ProfileTools] GET /orders/42: 1 call, 0.507ms, 4874 allocations, 0 GC runs (0ms)
[ProfileTools] Order.find: 1 call, 0.025ms, 401 allocations, 0 GC runs (0ms)
[ProfileTools] Order#total: 3 calls, 0.474ms, 4473 allocations, 0 GC runs (0ms)
[ProfileTools] Order#line_items: 3 calls, 0.394ms, 4473 allocations, 0 GC runs (0ms)
```

Here `Order#total` allocates nothing itself; all 4473 objects come from `Order#line_items`, called once per `total`.

## Installation

Requires Ruby 3.4 or newer and ActiveSupport 7.1 or newer. Add this line to your application's Gemfile:

```ruby
gem 'profile-tools'
```

And then execute:

```bash
$ bundle install
```

## Usage with Rails

Nothing else to set up. With the gem installed, profiling is off until a config file exists.

1. Create `config/profile_tools.yml` listing the methods to profile. Keys are class names; values are method names. Class methods start with a dot.

   ```yaml
   Order:
     - total
     - line_items
     - .find
   Admin::ReportBuilder:
     - build
   ```

   To keep the file out of the app directory, put it anywhere and set `PROFILE_TOOLS_CONFIG=/path/to/profile_tools.yml`.

2. Restart the app server. When the file exists, the gem's Railtie:
   - wraps the listed methods once the app has booted (after eager loading)
   - adds `ProfileTools::Middleware`, so each request is reported together under a `GET /path` line
   - logs the report to `Rails.logger` at info level, tagged like the rest of the request's lines

3. Read the log, then delete the file and restart again.

A typo in the file (a class or method that doesn't exist) raises at boot, so check the app starts before leaving it.

Background jobs (Sidekiq, Active Job) don't go through the middleware; see [Background jobs](#background-jobs) to get one report per job.

## Usage without Rails

Outside Rails, nothing happens automatically: you choose the methods, where reports go, and what counts as one run. It takes three steps.

```ruby
require 'logger'
require 'profile-tools'

# 1. Send reports somewhere. Attach first: that loads ActiveSupport::LogSubscriber.
ProfileTools::LogSubscriber.attach_to :profile_tools
ActiveSupport::LogSubscriber.logger = Logger.new($stdout)

# 2. Choose the methods, after the classes are loaded
ProfileTools.load('profile_tools.yml')            # the same YAML format as in Rails, or:
ProfileTools.profile('Order' => %w[total .find])  # a hash in that shape, or:
ProfileTools.profile_method('Order#total')        # one method at a time

# 3. Decide what one report covers
ProfileTools.instrument('nightly import') { Importer.run }
```

Without an enclosing `instrument` block (or the middleware below), each outermost call to a profiled method is reported on its own.

### Rack apps (Sinatra, Roda, Hanami, plain Rack)

`ProfileTools::Middleware` makes each request one report, named `GET /path`. To keep the drop-in-file workflow, guard the setup in `config.ru` so it only runs when the file is there:

```ruby
# config.ru
require_relative 'app'

profile_config = ENV.fetch('PROFILE_TOOLS_CONFIG', 'config/profile_tools.yml')
if File.exist?(profile_config)
  require 'logger'
  require 'profile-tools'
  ProfileTools::LogSubscriber.attach_to :profile_tools
  ActiveSupport::LogSubscriber.logger = Logger.new($stdout)
  ProfileTools.load(profile_config)
  use ProfileTools::Middleware
end

run App
```

### Background jobs

Jobs don't pass through the Rack middleware, in Rails or anywhere else. Wrap each job in `instrument` to get one report per job. With Sidekiq:

```ruby
class ProfileToolsSidekiqMiddleware
  include Sidekiq::ServerMiddleware

  def call(_job_instance, job, _queue, &)
    ProfileTools.instrument(job['class'], &)
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware { |chain| chain.add ProfileToolsSidekiqMiddleware }
end
```

### Scripts and the console

```ruby
ProfileTools.profile_method('Order#total')
ProfileTools.instrument('check') { Order.find(42).total }
ProfileTools.profiler.collector.called_methods.map(&:to_h)
# => [{method: "check", calls: 1, duration: 0.51, allocations: 4874, gc_count: 0, gc_time: 0}, ...]
```

`script/console` in this repo starts IRB with logging to stdout already set up.

### Sending the numbers somewhere else

Every finished run publishes a `profile.profile_tools` ActiveSupport notification. Subscribe to it instead of (or as well as) attaching the log subscriber:

```ruby
ActiveSupport::Notifications.subscribe('profile.profile_tools') do |event|
  event.payload[:collector].called_methods.each do |stats|
    StatsD.distribution('profile_tools.allocations', stats.allocations, tags: ["method:#{stats.method}"])
  end
end
```

### Stopping

```ruby
ProfileTools.stop_profiling('Order#total', 'Order.find')
ProfileTools.stop_profiling!   # every method
```

## Reading the numbers

Each line covers one method for one request (or `instrument` block):

| Field | Meaning |
|---|---|
| calls | Times the method was called |
| ms | Total time inside the method, including everything it called |
| allocations | Objects allocated inside the method, including everything it called |
| GC runs (ms) | Garbage collections that ran inside the method, and the time they took |

The top line (the request or `instrument` block) is the total for the whole request, so you can see what share of it each method accounts for.

### How accurate it is

- **Allocations are exact.** They come from `GC.stat(:total_allocated_objects)`, a counter that only goes up, so garbage collection running mid-call doesn't distort them. The wrapper itself allocates nothing per call, so wrapping a method doesn't add to its caller's count.
- **Other threads count too.** The counter is process-wide. On a multi-threaded server (Puma with `threads 5, 5`), allocations from other requests running at the same time land in the numbers. For clean numbers, run the profiled box with one thread per process.
- **The first call can be higher.** Ruby fills method caches on the first call, which allocates. Look at steady-state requests, not the first one after boot.
- **Recursion is counted once.** A recursive call adds to `calls`, but only the outermost call is measured, so time and allocations aren't double-counted.
- **Methods with unusual names** (defined with `define_method` and a name that `def` can't write, like `:'my-method'`) fall back to a wrapper that allocates a few objects per call.

### Choosing methods to list

Start broad and narrow down. List a few high-level methods (a service object's `call`, a serializer's `as_json`), find the one with the most allocations, then list the methods it calls. To find candidates first, a sampling profiler like [stackprof](https://github.com/tmm1/stackprof) (`mode: :object`) or [vernier](https://github.com/jhawthorn/vernier) is a good start. ProfileTools then gives you exact numbers for the methods they point at, on real production traffic.

## How it works

`ProfileTools.profile_method('Order#total')` prepends a module to `Order` that defines:

```ruby
def total(...)
  ::ProfileTools.profiler.instrument("Order#total".freeze) { super(...) }
end
```

`...` passes positional, keyword and block arguments through unchanged, and the method keeps its visibility (public, protected or private). Removing the wrapper deletes that method from the module, and calls go straight to the original again. See [ARCHITECTURE.md](ARCHITECTURE.md) for more.

## Development

```bash
bundle install
bundle exec rspec          # specs, with line and branch coverage
bundle exec rubocop        # lint
bundle exec yard stats --list-undoc
script/console             # IRB with the gem loaded and logging to stdout
```

CI runs RuboCop, a YARD docs check and the specs on Ruby 3.4 and the `.ruby-version` Ruby, and requires 100% line and branch coverage. Releases are automated with release-please from [conventional commits](https://www.conventionalcommits.org/).

## License

MIT. See [LICENSE](LICENSE).
