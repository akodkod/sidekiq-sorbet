# Sidekiq::Sorbet

Add typed arguments to your Sidekiq Workers with automatic argument access.

## Quick Example

```ruby
# Worker Class
class AnalyzeAttachmentWorker
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :attachment_id, Integer
    const :regenerate, T::Boolean, default: false
  end

  def run
    # Direct access to typed arguments
    attachment = Attachment.find(attachment_id)
    return if attachment.analyzed? && !regenerate

    attachment.analyze!
  end
end

# Call Worker
AnalyzeAttachmentWorker.run_async(attachment_id: 1)                     # arguments are typed and validated
AnalyzeAttachmentWorker.run_sync(attachment_id: 1, regenerate: true)    # execute synchronously
```

## Features

- ✅ **Direct argument access** - Access arguments directly as `attachment_id` instead of `args.attachment_id`
- ✅ **Type safety** - Arguments are validated at enqueue time using Sorbet's T::Struct
- ✅ **Optional Args** - Workers can omit the Args class if they don't need arguments
- ✅ **Backward compatible** - The `args` accessor still works: `args.attachment_id`
- ✅ **Clean API** - Use `run_async`/`run_sync` instead of `perform_async`/`perform`
- ✅ **Fail-fast validation** - Errors caught before jobs are enqueued
- ✅ **Comprehensive errors** - Clear error messages for debugging

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add sidekiq-sorbet
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install sidekiq-sorbet
```

## Usage

### Basic Worker with Arguments

```ruby
class ProcessUserWorker
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :user_id, Integer
    const :send_email, T::Boolean, default: true
  end

  def run
    user = User.find(user_id)
    user.process!
    UserMailer.processed(user).deliver_later if send_email
  end
end

# Enqueue the job
ProcessUserWorker.run_async(user_id: 123)
ProcessUserWorker.run_async(user_id: 456, send_email: false)
```

### Worker Without Arguments

Args class is optional! Workers without arguments work perfectly:

```ruby
class CleanupWorker
  include Sidekiq::Sorbet

  def run
    # Perform cleanup tasks
    clean_temp_files
    vacuum_database
  end
end

# No arguments needed
CleanupWorker.run_async
```

### Complex Types

```ruby
class ReportWorker
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :user_ids, T::Array[Integer]
    const :filters, T::Hash[String, T.untyped], default: {}
    const :format, String
  end

  def run
    users = User.where(id: user_ids)
    report = ReportGenerator.new(users, filters)
    report.export(format)
  end
end

ReportWorker.run_async(
  user_ids: [1, 2, 3],
  filters: { "active" => true },
  format: "pdf",
)
```

### Nested T::Structs

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
    # Access nested struct fields
    email = NotificationMailer.compose(
      to: recipient.email,
      name: recipient.name,
      body: message,
    )
    email.deliver
  end
end

NotificationWorker.run_async(
  recipient: NotificationWorker::Recipient.new(
    name: "John Doe",
    email: "john@example.com",
  ),
  message: "Hello!",
)
```

### Backward Compatibility

The `args` accessor still works if you prefer the old style:

```ruby
class LegacyWorker
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :value, Integer
  end

  def run
    # Both styles work
    direct = value           # Direct access (recommended)
    via_args = args.value    # Via args accessor (still works)
  end
end
```

### Synchronous Execution

Use `run_sync` for testing or immediate execution:

```ruby
# In tests
result = ProcessUserWorker.run_sync(user_id: 123)

# In console for debugging
AnalyzeAttachmentWorker.run_sync(attachment_id: 456)
```

## Tapioca DSL Compiler

This gem includes a Tapioca DSL compiler that generates proper type signatures for your workers. This enables Sorbet to understand the dynamically generated methods like `run_async`, `run_sync`, and argument accessors.

### Generating RBI Files

Run the Tapioca DSL compiler to generate type definitions:

```bash
bundle exec tapioca dsl SidekiqSorbet
```

Or generate RBI files for all DSL compilers:

```bash
bundle exec tapioca dsl
```

### Generated Signatures

For a worker like this:

```ruby
class MyWorker
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :user_id, Integer
    const :notify, T::Boolean, default: false
  end

  def run
    # ...
  end
end
```

The compiler generates:

```rbi
class MyWorker
  sig { returns(Integer) }
  def user_id; end

  sig { returns(T::Boolean) }
  def notify; end

  sig { params(user_id: Integer, notify: T::Boolean).returns(String) }
  def self.run_async(user_id:, notify: T.unsafe(nil)); end

  sig { params(user_id: Integer, notify: T::Boolean).returns(T.untyped) }
  def self.run_sync(user_id:, notify: T.unsafe(nil)); end
end
```

Workers without an `Args` class will still have `run_async` and `run_sync` generated with no parameters.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/sidekiq-sorbet. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/sidekiq-sorbet/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Sidekiq::Sorbet project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/sidekiq-sorbet/blob/main/CODE_OF_CONDUCT.md).
