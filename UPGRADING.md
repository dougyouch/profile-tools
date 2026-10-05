# Upgrading from 0.1 to 0.2

0.2 is a rewrite of the internals. The YAML file format is unchanged, but most of the Ruby API and all of the reported numbers changed. If you only used `ProfileTools.load` with a YAML file, the main changes are in [Setup](#setup) and [Reported stats](#reported-stats).

## Requirements

| | 0.1 | 0.2 |
|---|---|---|
| Ruby | any | 3.4 or newer |
| ActiveSupport | not declared, but required at runtime | `>= 7.1`, declared |
| concurrent-ruby | required at runtime, not declared | not used |

Ruby 3.4 is the minimum because it is the first version where forwarding arguments with `...` allocates nothing. On Ruby 3.3, every call to a profiled method would add 1 or 2 objects to the counts.

## Setup

In a Rails app, delete the initializer you used to load the YAML file and attach the log subscriber, then move the file to `config/profile_tools.yml` (or point `PROFILE_TOOLS_CONFIG` at it). The gem's Railtie now loads the file after boot, attaches the log subscriber and adds a middleware that reports each request together. See [Usage with Rails](README.md#usage-with-rails).

Outside Rails, the setup is the same as before, plus `ProfileTools::Middleware` if you want one report per request.

## API changes

`ProfileTools` is now a module, not a class, so `ProfileTools.new` is gone. Methods are named the same way everywhere: `"Class#method"` for instance methods and `"Class.method"` for class methods.

| 0.1 | 0.2 |
|---|---|
| `ProfileTools.new.profile_instance_method(:User, :save)` | `ProfileTools.profile_method('User#save')` |
| `ProfileTools.new.profile_class_method(:User, :find)` | `ProfileTools.profile_method('User.find')` |
| `ProfileTools.new.remove_profiled_instance_method(:User, :save)` | `ProfileTools.stop_profiling('User#save')` |
| `ProfileTools.new.remove_profiled_class_method(:User, :find)` | `ProfileTools.stop_profiling('User.find')` |
| `ProfileTools.stop_profiling(['User#save', 'User.find'])` | `ProfileTools.stop_profiling('User#save', 'User.find')` (takes names, not an array) |
| `ProfileTools.add_method` / `ProfileTools.delete_method` | removed; use `profile_method` / `stop_profiling` |
| `ProfileTools.load(path)` / `ProfileTools.profile(hash)` | unchanged |
| `ProfileTools.stop_profiling!` | unchanged |
| `ProfileTools.instrument { }` | unchanged, and takes an optional name: `ProfileTools.instrument('import') { }` |
| | new: `ProfileTools.profiled?('User#save')` |

The default name for an `instrument` block changed from `ProfileTools::Profiler#instrument` to `ProfileTools.instrument`.

`ProfileTools.profiled_methods` still returns the names, but the array is now frozen.

## Reported stats

Per-type object counts are replaced by a single exact allocation count, plus garbage collection numbers.

| 0.1 | 0.2 |
|---|---|
| `count_objects` (hash of `T_STRING`, `T_HASH`, ... live-object deltas) | `allocations` (total objects allocated) |
| `num_collection_calls` | removed |
| | new: `gc_count` and `gc_time` (ms) |
| `duration` (ms) | unchanged |
| `calls` | unchanged |

The old counts came from `ObjectSpace.count_objects`, which counts live objects. They went wrong (sometimes negative) whenever garbage collection ran during a call, and needed hand-tuned corrections. The new count comes from `GC.stat(:total_allocated_objects)` and is exact. If you need a breakdown by type for one method, use [memory_profiler](https://github.com/SamSaffron/memory_profiler) on it once ProfileTools has pointed you at it.

### Log format

```
# 0.1
method User#save took 12.34567ms, called 2, objects: T_STRING: 40, T_HASH: 3
# 0.2
[ProfileTools] User#save: 2 calls, 12.346ms, 43 allocations, 0 GC runs (0ms)
```

Update any log searches or alerts that matched the old format.

### Collector

If you read the collector directly (for example in your own notification subscriber):

| 0.1 | 0.2 |
|---|---|
| `collector.methods` (hash of hashes) | `collector.stats` (hash of `ProfileTools::MethodStats`) |
| `collector.called_methods` returned hashes | returns `MethodStats` objects; call `to_h` for a hash |
| `collector.init_method(name)` | `ProfileTools::Collector.new(names)` |
| `collector.total_collection_calls` | removed |

The `profile.profile_tools` notification payload now also carries `:name`, the name of the request or `instrument` block.

## Behavior changes

These were bugs in 0.1 and are fixed in 0.2:

- **Blocks and keyword arguments are passed through.** The 0.1 wrapper only forwarded positional arguments, so profiling a method that takes a block or keyword arguments broke it.
- **An exception no longer turns profiling off.** In 0.1, an exception raised inside a profiled method left the thread's profiler stuck mid-run, and that thread never reported again until restart.
- **Private and protected methods stay private and protected.** 0.1 made them public.
- **Setters and operators can be profiled** (`name=`, `[]`, `<=>`). In 0.1 they raised a `SyntaxError`.
- **Profiling a method twice does nothing.** In 0.1 it caused infinite recursion.
- **Stopping a method that isn't profiled does nothing.** In 0.1 it raised `NameError`.
- **A method first seen mid-run, or a nested `instrument` call, no longer raises `NoMethodError`.**
- **Recursive methods are measured once**, at the outermost call, instead of adding up the nested calls.
- **Methods are wrapped with `Module#prepend`.** The `*_with_profiling` and `*_without_profiling` aliases are gone, so wrapping no longer conflicts with other code that aliases the same method.

## Errors

- `ProfileTools::Error` is raised for a name that isn't `Class#method` or `Class.method`, and for a YAML file that isn't a mapping of class names to methods.
- `ProfileTools::UnknownMethodError` (a subclass of `Error`) is raised for a method the class doesn't define.
- An unknown class still raises `NameError`.
