# Architecture

This document describes the internals of the `profile-tools` gem.

## Overview

ProfileTools wraps chosen methods so each call is measured, adds the measurements up per method for one run (a request, a job, an `instrument` block), and publishes the totals as an ActiveSupport notification when the run ends.

```
config/profile_tools.yml ──> ProfileTools.load ──> MethodWrapper#wrap (prepends a wrapper per method)

request ──> Middleware ──> Profiler#instrument("GET /path")   starts a run: new Collector
                              └─ app code
                                   └─ Order#total (wrapper) ──> Profiler#instrument("Order#total")
                                                                  └─ Collector#instrument: measure, add to MethodStats
        <── run ends: "profile.profile_tools" notification (payload: name, collector)
                              └─ LogSubscriber#profile: one log line per called method
```

## Components

```
ProfileTools (module: public API, list of profiled methods)
    ├── MethodName       parses "Class#method" / "Class.method", finds the class
    ├── MethodWrapper    prepends / removes the wrapper method
    ├── Profiler         per-thread run tracking, publishes the notification
    ├── Collector        measures calls, holds MethodStats per method for one run
    ├── MethodStats      totals for one method: calls, duration, allocations, GC
    ├── LogSubscriber    logs a run's MethodStats
    ├── Middleware       Rack: one run per request
    ├── Railtie          Rails: loads config/profile_tools.yml, adds Middleware and LogSubscriber
    ├── Error
    │     └── UnknownMethodError
    └── VERSION
```

`lib/profile-tools.rb` autoloads everything. The Railtie is required from an `ActiveSupport.on_load(:before_configuration)` hook, which runs when the Rails application class is defined, so it is only loaded in Rails apps and early enough for its initializers to run.

### ProfileTools (`lib/profile-tools.rb`)

The public API: `load`, `profile`, `profile_method`, `stop_profiling`, `stop_profiling!`, `profiled?`, `profiled_methods`, `profiler` and `instrument`.

`@profiled_methods` is a frozen array that is replaced, never changed in place. A run reads it once when it starts, so a method profiled or removed mid-run doesn't affect that run.

`profile_method` is idempotent and `stop_profiling` ignores names that aren't profiled, so `profile_method` is where names and methods are validated, and `MethodWrapper` trusts what it is given.

### MethodName (`lib/profile_tools/method_name.rb`)

Parses a name like `Admin::User#save` or `User.find` into the class name, the method name (a Symbol) and whether it is a class method. `#owner` returns the class to wrap: the class itself for an instance method, its singleton class for a class method. `Object.const_get` is used, so app classes are autoloaded.

### MethodWrapper (`lib/profile_tools/method_wrapper.rb`)

Wraps by prepending a `MethodWrapper::WrapperModule` to the owner. There is one per class, found again by looking for a `WrapperModule` among the modules before the class in its ancestors. Each wrapped method gets a method in that module:

```ruby
def total(...)
  ::ProfileTools.profiler.instrument("Order#total".freeze) { super(...) }
end
```

- `...` forwards positional, keyword and block arguments. Since Ruby 3.4 it allocates nothing, which is why the gem requires 3.4.
- `"...".freeze` on a literal compiles to a single frozen string, so passing the name allocates nothing either.
- The wrapper gets the original's visibility.
- Names `def` can't write (methods created with `define_method` and an arbitrary string) fall back to `define_method` with `*args, **kwargs, &block`, which does allocate.
- Unwrapping removes the method from the module; the module stays prepended and empty, and calls go straight to the original.

### Profiler (`lib/profile_tools/profiler.rb`)

One per thread, stored in `Thread.current` (which is fiber-local). The first `instrument` call when no run is active starts a run: it creates a `Collector` holding stats for every profiled method, then calls `ActiveSupport::Notifications.instrument('profile.profile_tools', name:, collector:)` around the measured block. Nested `instrument` calls go straight to the collector. `@running` is reset in an `ensure`, so an exception ends the run cleanly.

### Collector (`lib/profile_tools/collector.rb`)

`instrument(name)` reads the clock (`CLOCK_MONOTONIC`, in ms), `GC.stat(:total_allocated_objects)`, `GC.count` and `GC.stat(:time)` before and after the block (in an `ensure`, so calls that raise are recorded), and adds the differences to the method's `MethodStats`.

Exact nested counts depend on nothing being allocated between the readings except by the measured code:

- Stats objects are created for all profiled methods when the collector is created, before any measurement starts. A method seen for the first time mid-run creates its stats then, and that one object is counted by the enclosing call.
- The rest of the bookkeeping (integer and float arithmetic, hash lookups, anonymous block forwarding with `&`) doesn't allocate.

If a method is already running in this collector (recursion), the call is counted in `calls` but not measured again, so time and allocations aren't counted twice.

### MethodStats (`lib/profile_tools/method_stats.rb`)

Totals for one method within one collector: `calls`, `duration` (ms), `allocations`, `gc_count`, `gc_time` (ms). `sort_order` records when the method was first called, so `Collector#called_methods` returns methods in call order. `enter`/`leave` track the recursion depth.

### LogSubscriber (`lib/profile_tools/log_subscriber.rb`)

An `ActiveSupport::LogSubscriber` attached to the `profile_tools` namespace. It logs one info line per called method:

```
[ProfileTools] Order#total: 3 calls, 0.474ms, 4473 allocations, 0 GC runs (0ms)
```

`subscribe_log_level :profile, :info` skips the event entirely when the logger is above info.

### Middleware (`lib/profile_tools/middleware.rb`)

Runs each request inside `ProfileTools.instrument("#{REQUEST_METHOD} #{PATH_INFO}")`, so a request is one run. The Railtie inserts it right after `Rails::Rack::Logger`, so the log lines are written inside the request's tagged logging.

### Railtie (`lib/profile_tools/railtie.rb`)

Looks for `config/profile_tools.yml` (or `PROFILE_TOOLS_CONFIG`). If it exists:

- the `profile_tools.middleware` initializer adds the middleware and attaches the log subscriber (initializers run before the middleware stack is built)
- an `after_initialize` hook calls `ProfileTools.load`, after eager loading, so wrapped classes are already loaded

Because methods are wrapped once at boot, classes reloaded in development lose their wrappers. The gem is meant for a production process that is restarted to turn profiling on and off.

## Accuracy limits

- `GC.stat` counters are process-wide: other threads' allocations and GC are included.
- The first call to a method can allocate for Ruby's method caches.
- Durations and allocations include everything the method calls, profiled or not.
