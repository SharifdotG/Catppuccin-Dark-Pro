# Ruby Test File for Theme Validation
require 'json'
require 'net/http'
require 'uri'
require 'time'
require 'concurrent'

# Constants
API_BASE_URL = 'https://api.example.com'.freeze
MAX_RETRIES = 3
TIMEOUT_SECONDS = 5
SUPPORTED_FORMATS = %w[json xml csv].freeze

# Custom exception classes
class UserNotFoundError < StandardError
  def initialize(user_id)
    super("User not found: #{user_id}")
    @user_id = user_id
  end

  attr_reader :user_id
end

class InvalidEmailError < StandardError
  def initialize(email)
    super("Invalid email format: #{email}")
    @email = email
  end

  attr_reader :email
end

class ApiError < StandardError
  def initialize(message)
    super("API request failed: #{message}")
  end
end

# User status enumeration
module UserStatus
  ACTIVE = 'active'
  INACTIVE = 'inactive'
  PENDING = 'pending'
  SUSPENDED = 'suspended'

  ALL = [ACTIVE, INACTIVE, PENDING, SUSPENDED].freeze

  def self.valid?(status)
    ALL.include?(status)
  end

  def self.display_name(status)
    case status
    when ACTIVE then 'Active'
    when INACTIVE then 'Inactive'
    when PENDING then 'Pending'
    when SUSPENDED then 'Suspended'
    else 'Unknown'
    end
  end

  def self.from_string(value)
    ALL.find { |status| status.casecmp?(value) }
  end
end

# User data class with validation
class User
  include Comparable

  attr_reader :id, :name, :email, :created_at, :metadata
  attr_accessor :status

  def initialize(id:, name:, email:, status: UserStatus::ACTIVE, created_at: nil, metadata: {})
    @id = id.to_s.strip
    @name = name.to_s.strip
    @email = email.to_s.strip.downcase
    @status = status
    @created_at = created_at || Time.now.utc
    @metadata = metadata.dup
    @mutex = Mutex.new

    validate!
  end

  def active?
    status == UserStatus::ACTIVE
  end

  def display_name
    name.empty? ? email : name
  end

  def days_active
    (Time.now.utc - created_at) / (24 * 60 * 60)
  end

  def valid_email?
    email.match?(/\A[^@\s]+@[^@\s]+\z/)
  end

  def age_category
    days = days_active.to_i
    case days
    when 0..30 then 'New'
    when 31..365 then 'Regular'
    else 'Veteran'
    end
  end

  def new_user?
    days_active <= 30
  end

  def expired?
    days_active > 365 && status == UserStatus::INACTIVE
  end

  def add_metadata(key, value)
    @mutex.synchronize do
      @metadata[key.to_s] = value
    end
  end

  def get_metadata(key)
    @mutex.synchronize do
      @metadata[key.to_s]
    end
  end

  def set_status(new_status)
    raise ArgumentError, "Invalid status: #{new_status}" unless UserStatus.valid?(new_status)
    @status = new_status
  end

  def to_h
    {
      id: id,
      name: name,
      email: email,
      status: status,
      created_at: created_at.iso8601,
      metadata: metadata.dup,
      is_active: active?,
      display_name: display_name,
      days_active: days_active.to_i
    }
  end

  def to_json(*args)
    to_h.to_json(*args)
  end

  def self.from_json(json_str)
    data = JSON.parse(json_str, symbolize_names: true)
    from_hash(data)
  end

  def self.from_hash(data)
    new(
      id: data[:id],
      name: data[:name],
      email: data[:email],
      status: data[:status] || UserStatus::ACTIVE,
      created_at: data[:created_at] ? Time.parse(data[:created_at]) : nil,
      metadata: data[:metadata] || {}
    )
  end

  def <=>(other)
    return nil unless other.is_a?(User)
    [name, created_at] <=> [other.name, other.created_at]
  end

  def ==(other)
    other.is_a?(User) && id == other.id && email == other.email
  end

  def hash
    [id, email].hash
  end

  def to_s
    "User(id=#{id}, name=#{name}, email=#{email}, status=#{status})"
  end

  def inspect
    "#<User:#{object_id} @id=#{id.inspect} @name=#{name.inspect} @email=#{email.inspect} @status=#{status.inspect}>"
  end

  private

  def validate!
    raise ArgumentError, 'User ID cannot be empty' if id.empty?
    raise ArgumentError, 'User name cannot be empty' if name.empty?
    raise InvalidEmailError, email unless valid_email?
    raise ArgumentError, "Invalid status: #{status}" unless UserStatus.valid?(status)
  end
end

# API Response wrapper
class ApiResponse
  attr_reader :success, :data, :error, :timestamp

  def initialize(success:, data: nil, error: nil, timestamp: nil)
    @success = success
    @data = data
    @error = error
    @timestamp = timestamp || Time.now.utc
  end

  def self.success(data)
    new(success: true, data: data)
  end

  def self.error(message)
    new(success: false, error: message)
  end

  def success?
    @success
  end

  def error?
    !@success
  end

  def to_h
    {
      success: success,
      data: data,
      error: error,
      timestamp: timestamp.iso8601
    }
  end

  def to_json(*args)
    to_h.to_json(*args)
  end
end

# User statistics data structure
class UserStatistics
  attr_reader :total, :active, :inactive, :pending, :suspended, :average_days_active

  def initialize(users)
    @total = users.size
    @active = users.count { |u| u.status == UserStatus::ACTIVE }
    @inactive = users.count { |u| u.status == UserStatus::INACTIVE }
    @pending = users.count { |u| u.status == UserStatus::PENDING }
    @suspended = users.count { |u| u.status == UserStatus::SUSPENDED }
    @average_days_active = users.empty? ? 0.0 : users.sum(&:days_active) / users.size
  end

  def to_h
    {
      total: total,
      active: active,
      inactive: inactive,
      pending: pending,
      suspended: suspended,
      average_days_active: average_days_active
    }
  end

  def to_s
    "UserStats(total=#{total}, active=#{active}, inactive=#{inactive}, " \
    "pending=#{pending}, suspended=#{suspended}, avgDays=#{'%.2f' % average_days_active})"
  end
end

# User operations module
module UserOperations
  def validate
    true
  end

  def export(format)
    "Mock export in #{format} format"
  end

  def save
    sleep(0.1)
    true
  end
end

# User manager class with concurrent operations
class UserManager
  include UserOperations

  def initialize(base_url: API_BASE_URL, timeout: TIMEOUT_SECONDS)
    @base_url = base_url
    @timeout = timeout
    @cache = Concurrent::Hash.new
    @thread_pool = Concurrent::ThreadPoolExecutor.new(
      min_threads: 2,
      max_threads: 10,
      max_queue: 100
    )
  end

  # Fetch user by ID with caching
  def fetch_user(user_id)
    raise ArgumentError, 'User ID cannot be empty' if user_id.to_s.strip.empty?

    # Check cache first
    cached_user = @cache[user_id]
    if cached_user
      puts "User #{user_id} found in cache"
      return cached_user
    end

    begin
      user = fetch_from_api(user_id)
      if user
        @cache[user_id] = user
        puts "User #{user_id} fetched and cached successfully"
      end
      user
    rescue => e
      puts "Error fetching user #{user_id}: #{e.message}"
      nil
    end
  end

  # Batch fetch multiple users concurrently
  def batch_fetch_users(user_ids)
    futures = user_ids.map do |user_id|
      Concurrent::Future.execute(executor: @thread_pool) do
        [user_id, fetch_user(user_id)]
      end
    end

    results = {}
    futures.each do |future|
      user_id, user = future.value
      results[user_id] = user
    end

    results
  end

  # Update user information
  def update_user(user_id, updates)
    return false if user_id.to_s.strip.empty? || updates.empty?

    begin
      # Simulate API call
      sleep(0.2)

      # Invalidate cache
      @cache.delete(user_id)
      puts "User #{user_id} updated successfully"
      true
    rescue => e
      puts "Error updating user #{user_id}: #{e.message}"
      false
    end
  end

  # Filter users by status using functional programming
  def filter_users_by_status(users, status)
    users
      .select { |user| user.status == status }
      .sort_by { |user| [user.name, user.created_at] }
  end

  # Get user statistics
  def get_user_statistics(users)
    UserStatistics.new(users)
  end

  # Clear cache and return number of entries cleared
  def clear_cache
    count = @cache.size
    @cache.clear
    puts "Cache cleared: #{count} entries removed"
    count
  end

  # Export users to different formats
  def export_users(users, format = 'json')
    raise ArgumentError, "Unsupported format: #{format}" unless SUPPORTED_FORMATS.include?(format)

    case format.downcase
    when 'json'
      export_to_json(users)
    when 'csv'
      export_to_csv(users)
    when 'xml'
      export_to_xml(users)
    else
      raise ArgumentError, "Unsupported format: #{format}"
    end
  end

  def shutdown
    @thread_pool&.shutdown
    @thread_pool&.wait_for_termination(5)
  end

  private

  def fetch_from_api(user_id)
    # Simulate API call with mock data
    sleep(0.1)

    case user_id
    when '1'
      User.new(id: '1', name: 'John Doe', email: 'john@example.com')
    when '2'
      User.new(id: '2', name: 'Jane Smith', email: 'jane@example.com', status: UserStatus::PENDING)
    when '3'
      User.new(id: '3', name: 'Bob Johnson', email: 'bob@example.com', status: UserStatus::INACTIVE)
    else
      nil
    end
  end

  def export_to_json(users)
    JSON.pretty_generate(users.map(&:to_h))
  end

  def export_to_csv(users)
    lines = ["ID,Name,Email,Status,Created At"]
    users.each do |user|
      lines << "#{user.id},#{user.name},#{user.email},#{user.status},#{user.created_at.iso8601}"
    end
    lines.join("\n")
  end

  def export_to_xml(users)
    lines = ['<?xml version="1.0" encoding="UTF-8"?>', '<users>']
    users.each do |user|
      lines << '  <user>'
      lines << "    <id>#{user.id}</id>"
      lines << "    <name>#{user.name}</name>"
      lines << "    <email>#{user.email}</email>"
      lines << "    <status>#{user.status}</status>"
      lines << "    <created_at>#{user.created_at.iso8601}</created_at>"
      lines << '  </user>'
    end
    lines << '</users>'
    lines.join("\n")
  end
end

# Array extensions for user operations
class Array
  def active_users
    select(&:active?)
  end

  def by_status(status)
    select { |user| user.status == status }
  end

  def average_age
    return 0.0 if empty?
    map(&:days_active).sum / size.to_f
  end

  def new_users
    select(&:new_user?)
  end

  def group_by_status
    group_by(&:status)
  end
end

# User extensions
class User
  def to_json_string
    to_json
  end

  def older_than?(days)
    days_active > days
  end

  def with_status(new_status)
    dup.tap { |user| user.set_status(new_status) }
  end

  def with_metadata(key, value)
    dup.tap { |user| user.add_metadata(key, value) }
  end
end

# Utility functions
module UserUtils
  def self.process_users(users, filter: nil, transform: nil)
    filtered_users = filter ? users.select(&filter) : users
    transform_proc = transform || ->(user) { user.to_s }
    filtered_users.map(&transform_proc)
  end

  def self.find_user(users, &predicate)
    users.find(&predicate)
  end

  def self.validate_users(users, &validator)
    users.select(&validator)
  end

  def self.create_users_from_csv(csv_data)
    lines = csv_data.split("\n")
    return [] if lines.empty?

    users = []
    lines[1..-1]&.each_with_index do |line, index|
      parts = line.split(',')
      next unless parts.size >= 3

      begin
        user = User.new(
          id: parts[0].strip,
          name: parts[1].strip,
          email: parts[2].strip
        )
        users << user
      rescue => e
        puts "Error creating user from line #{index + 2}: #{e.message}"
      end
    end

    users
  end
end

# User events using classes
class UserEvent
  attr_reader :timestamp

  def initialize
    @timestamp = Time.now.utc
  end
end

class UserCreated < UserEvent
  attr_reader :user

  def initialize(user)
    super()
    @user = user
  end

  def to_s
    "UserCreated(#{user.display_name})"
  end
end

class UserUpdated < UserEvent
  attr_reader :user, :changes

  def initialize(user, changes)
    super()
    @user = user
    @changes = changes
  end

  def to_s
    "UserUpdated(#{user.display_name}, #{changes.size} changes)"
  end
end

class UserDeleted < UserEvent
  attr_reader :user_id

  def initialize(user_id)
    super()
    @user_id = user_id
  end

  def to_s
    "UserDeleted(#{user_id})"
  end
end

class UserStatusChanged < UserEvent
  attr_reader :user, :old_status, :new_status

  def initialize(user, old_status, new_status)
    super()
    @user = user
    @old_status = old_status
    @new_status = new_status
  end

  def to_s
    "UserStatusChanged(#{user.display_name}, #{old_status} -> #{new_status})"
  end
end

# Event handler
class UserEventHandler
  def handle_event(event)
    case event
    when UserCreated
      puts "User created: #{event.user.display_name}"
    when UserUpdated
      puts "User updated: #{event.user.display_name} with #{event.changes.size} changes"
    when UserDeleted
      puts "User deleted: #{event.user_id}"
    when UserStatusChanged
      puts "User #{event.user.display_name} status changed from #{event.old_status} to #{event.new_status}"
    else
      puts "Unknown event: #{event}"
    end
  end
end

# Proc and lambda examples
filter_active = ->(user) { user.active? }
transform_name = proc { |user| user.display_name }
validate_email = lambda { |user| user.valid_email? }

# Block examples
def with_user_timing(&block)
  start_time = Time.now
  result = yield
  end_time = Time.now
  puts "Operation took #{(end_time - start_time) * 1000}ms"
  result
end

# Main execution
def main
  puts 'Ruby User Management System'
  puts '==========================='

  begin
    # Create sample users
    users = [
      User.new(id: '1', name: 'John Doe', email: 'john@example.com'),
      User.new(id: '2', name: 'Jane Smith', email: 'jane@example.com', status: UserStatus::PENDING),
      User.new(id: '3', name: 'Bob Johnson', email: 'bob@example.com', status: UserStatus::INACTIVE)
    ]

    manager = UserManager.new

    # Test user properties
    users.each do |user|
      puts "#{user} - Days active: #{user.days_active.to_i}, Category: #{user.age_category}"
    end

    # Test array extensions
    active_users = users.active_users
    puts "\nActive users: #{active_users.size}"

    pending_users = users.by_status(UserStatus::PENDING)
    puts "Pending users: #{pending_users.size}"

    grouped_users = users.group_by_status
    puts "Users grouped by status: #{grouped_users.keys}"

    # Test statistics
    stats = manager.get_user_statistics(users)
    puts "\nUser Statistics: #{stats}"

    # Test async operations
    user_ids = users.map(&:id)
    with_user_timing do
      batch_results = manager.batch_fetch_users(user_ids)
      puts "\nBatch fetch completed: #{batch_results.size} results"

      batch_results.each do |id, user|
        if user
          puts "✓ Fetched user: #{user.display_name}"
        else
          puts "✗ Failed to fetch user: #{id}"
        end
      end
    end

    # Test export functionality
    json_export = manager.export_users(users, 'json')
    puts "\nJSON Export:"
    puts json_export

    csv_export = manager.export_users(users, 'csv')
    puts "\nCSV Export:"
    puts csv_export

    # Test utility functions with blocks
    user_names = UserUtils.process_users(
      users,
      filter: filter_active,
      transform: transform_name
    )
    puts "\nActive user names: #{user_names}"

    new_users = users.new_users
    puts "New users: #{new_users.map(&:display_name)}"

    # Test event handling
    event_handler = UserEventHandler.new
    events = [
      UserCreated.new(users[0]),
      UserStatusChanged.new(users[1], UserStatus::ACTIVE, UserStatus::PENDING),
      UserUpdated.new(users[2], { 'email' => 'newemail@example.com' }),
      UserDeleted.new('4')
    ]

    puts "\nEvent Processing:"
    events.each { |event| event_handler.handle_event(event) }

    # Test validation and error handling
    begin
      invalid_user = User.new(id: '', name: 'Invalid User', email: 'invalid-email')
      puts "This should not print: #{invalid_user}"
    rescue => e
      puts "\nExpected validation error: #{e.message}"
    end

    # Test metadata operations
    user_with_metadata = users[0]
    user_with_metadata.add_metadata('last_login', Time.now.iso8601)
    user_with_metadata.add_metadata('preferences', 'dark_theme')

    puts "\nUser metadata:"
    puts "Last login: #{user_with_metadata.get_metadata('last_login')}"
    puts "Preferences: #{user_with_metadata.get_metadata('preferences')}"

    # Test enumerable methods
    puts "\nUsers with valid emails:"
    users.select(&:valid_email?).each { |u| puts "- #{u.display_name}" }

    puts "\nUsers sorted by name:"
    users.sort.each { |u| puts "- #{u.display_name}" }

    # Test regex and string operations
    email_pattern = /\A[^@\s]+@[^@\s]+\z/
    users.each do |user|
      match_result = user.email.match(email_pattern)
      puts "Email #{user.email} #{match_result ? 'matches' : 'does not match'} pattern"
    end

    # Test case/when statements
    users.each do |user|
      message = case user.status
                when UserStatus::ACTIVE
                  "#{user.display_name} is currently active"
                when UserStatus::PENDING
                  "#{user.display_name} is awaiting approval"
                when UserStatus::INACTIVE
                  "#{user.display_name} is not active"
                when UserStatus::SUSPENDED
                  "#{user.display_name} has been suspended"
                else
                  "#{user.display_name} has unknown status"
                end
      puts message
    end

  rescue => e
    puts "Error: #{e.message}"
    puts e.backtrace if $DEBUG
  ensure
    manager&.shutdown
  end

  puts "\nRuby syntax highlighting test completed!"
end

# Run the main function if this file is executed directly
main if __FILE__ == $PROGRAM_NAME
