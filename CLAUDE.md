# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

sidekiq-sorbet is a Ruby gem that adds typed arguments to Sidekiq workers using Sorbet's T::Struct. Workers define an `Args` class inheriting from T::Struct, and the gem provides `run_async`/`run_sync` methods with automatic type validation and serialization via sorbet-schema.

## Commands

```bash
# Install dependencies
bundle install

# Run tests (default Sidekiq version)
bundle exec rspec

# Run single test file
bundle exec rspec spec/sidekiq/sorbet/coercion_spec.rb

# Run specific test
bundle exec rspec spec/sidekiq/sorbet/coercion_spec.rb:42

# Run linter
bundle exec rubocop

# Run linter with auto-fix
bundle exec rubocop -A

# Run both tests and linter (default rake task)
bundle exec rake

# Type check with Sorbet
bundle exec srb tc

# Generate Tapioca RBI files
bundle exec tapioca dsl

# Test against specific Sidekiq version (7 or 8)
bundle exec appraisal sidekiq-7 rake
bundle exec appraisal sidekiq-8 rake
```

## Architecture

### Core Module (`lib/sidekiq/sorbet.rb`)
Entry point that auto-includes `Sidekiq::Job` when included in a worker class. Loads ClassMethods and InstanceMethods modules.

### ClassMethods (`lib/sidekiq/sorbet/class_methods.rb`)
Provides `run_async`, `run_at`, `run_in`, `run_sync` class methods. Handles Args T::Struct detection, validation, and serialization using sorbet-schema's `Typed::HashSerializer`.

### InstanceMethods (`lib/sidekiq/sorbet/instance_methods.rb`)
Overrides Sidekiq's `perform` method to deserialize args and define accessor methods. Workers implement `run` (not `perform`). Args fields are accessible directly (e.g., `user_id` instead of `args.user_id`).

### Tapioca DSL Compiler (`lib/tapioca/dsl/compilers/sidekiq_sorbet.rb`)
Generates RBI type signatures for `run_async`/`run_sync` methods and argument accessors. Run `bundle exec tapioca dsl` to regenerate.

### RSpec Matchers (`lib/sidekiq/sorbet/rspec.rb`)
Provides `have_arg`, `have_args`, `accept_args`, `reject_args` matchers for testing worker argument definitions. Auto-included when RSpec is detected.

## Test Structure

Test workers are defined in `spec/support/workers/` and organized by type:
- `basic_workers.rb` - Standard worker patterns
- `complex_workers.rb` - Nested structs, arrays, hashes
- `edge_case_workers.rb` - Boundary conditions
- `error_workers.rb` - Error handling scenarios
- `backward_compat_workers.rb` - Legacy compatibility

## Dependencies

- **sidekiq** >= 7.0 (tested against 7 and 8)
- **sorbet-runtime** >= 0.6
- **sorbet-schema** >= 0.9 (handles serialization/deserialization)
- **Ruby** >= 3.2.0

---

## Rules for Creating Workers

When creating a new Sidekiq::Sorbet worker, follow this pattern:

### Basic Structure

```ruby
class MyWorker
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :required_field, Integer
    const :optional_field, String, default: "default_value"
  end

  def run
    # Business logic here
    # Access args directly: required_field, optional_field
  end
end
```

### Key Rules

1. **Always include `Sidekiq::Sorbet`** - This auto-includes `Sidekiq::Job` and wires up the typed args system.

2. **Define `Args` as a nested `T::Struct`** - Must be named exactly `Args` and inherit from `T::Struct`.

3. **Use `const` for immutable fields** - All Args fields should use `const`, not `prop`.

4. **Implement `run`, not `perform`** - The gem overrides `perform` internally; your logic goes in `run`.

5. **Access args directly** - Use `field_name` not `args.field_name` (though both work).

6. **Args class is optional** - Workers without arguments can omit the `Args` class entirely.

### Supported Types

```ruby
class Args < T::Struct
  # Primitives
  const :id, Integer
  const :name, String
  const :active, T::Boolean
  const :score, Float

  # Collections
  const :ids, T::Array[Integer]
  const :metadata, T::Hash[String, T.untyped]

  # Nilable
  const :optional_id, T.nilable(Integer)

  # With defaults
  const :retries, Integer, default: 3
  const :tags, T::Array[String], default: []
end
```

### Nested Structs

Define nested structs inside the worker class:

```ruby
class NotificationWorker
  include Sidekiq::Sorbet

  class Recipient < T::Struct
    const :name, String
    const :email, String
  end

  class Args < T::Struct
    const :recipient, Recipient
    const :message, String
  end

  def run
    send_email(recipient.email, recipient.name, message)
  end
end
```

### Enqueuing Jobs

```ruby
# Immediate async execution
MyWorker.run_async(required_field: 123)

# Delayed execution
MyWorker.run_in(3600, required_field: 123)        # seconds
MyWorker.run_in(1.hour, required_field: 123)      # with ActiveSupport

# Scheduled execution
MyWorker.run_at(Time.now + 3600, required_field: 123)
MyWorker.run_at(1.hour.from_now, required_field: 123)

# Synchronous (for testing/debugging)
MyWorker.run_sync(required_field: 123)
```

---

## Rules for Testing Workers

### Setup

Add to `spec_helper.rb` or `rails_helper.rb`:

```ruby
require "sidekiq/sorbet/rspec"
```

### Testing Argument Definitions

Use the provided matchers to validate Args structure:

```ruby
RSpec.describe MyWorker do
  # Test argument exists with correct type
  it { is_expected.to have_arg(:user_id, Integer) }
  it { is_expected.to have_arg(:notify, T::Boolean) }

  # Test default values
  it { is_expected.to have_arg(:retries, Integer).with_default(3) }

  # Test multiple arguments at once
  it { is_expected.to have_args(user_id: Integer, name: String) }

  # Test argument validation
  it { is_expected.to accept_args(user_id: 123) }
  it { is_expected.to accept_args(user_id: 123, notify: false) }

  # Test invalid arguments are rejected
  it { is_expected.to reject_args(user_id: "not_an_integer") }
  it { is_expected.to reject_args(user_id: nil) }

  # Test specific error types
  it do
    is_expected.to reject_args(bad: "arg")
      .with_error(Sidekiq::Sorbet::InvalidArgsError)
  end
end
```

### Testing Worker Behavior

Use `run_sync` for synchronous execution in tests:

```ruby
RSpec.describe ProcessUserWorker do
  describe "#run" do
    let(:user) { create(:user) }

    it "processes the user" do
      ProcessUserWorker.run_sync(user_id: user.id)
      expect(user.reload).to be_processed
    end

    it "sends email when send_email is true" do
      expect {
        ProcessUserWorker.run_sync(user_id: user.id, send_email: true)
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "skips email when send_email is false" do
      expect {
        ProcessUserWorker.run_sync(user_id: user.id, send_email: false)
      }.not_to change { ActionMailer::Base.deliveries.count }
    end
  end
end
```

### Testing Async Enqueuing

Use Sidekiq's testing mode to verify jobs are enqueued:

```ruby
RSpec.describe MyWorker do
  include Sidekiq::Testing

  before { Sidekiq::Testing.fake! }

  it "enqueues a job" do
    expect {
      MyWorker.run_async(user_id: 123)
    }.to change(MyWorker.jobs, :size).by(1)
  end

  it "enqueues with correct arguments" do
    MyWorker.run_async(user_id: 123, notify: true)
    job = MyWorker.jobs.last
    expect(job["args"].first).to eq({ "user_id" => 123, "notify" => true })
  end
end
```

### Matcher Reference

| Matcher | Purpose | Example |
|---------|---------|---------|
| `have_arg(name, type)` | Single arg exists with type | `have_arg(:id, Integer)` |
| `.with_default(val)` | Chain: check default value | `have_arg(:x, Integer).with_default(0)` |
| `have_args(hash)` | Multiple args with types | `have_args(id: Integer, name: String)` |
| `.and_arg(name, type)` | Chain: add more args | `have_args(:id, Integer).and_arg(:name, String)` |
| `accept_args(hash)` | Args pass validation | `accept_args(id: 123)` |
| `reject_args(hash)` | Args fail validation | `reject_args(id: "bad")` |
| `.with_error(class, pattern)` | Chain: specific error | `reject_args(x: nil).with_error(InvalidArgsError)` |
