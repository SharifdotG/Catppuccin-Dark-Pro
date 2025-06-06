-- Lua Test File for Theme Validation
-- Testing syntax highlighting for Lua code

-- Module definition
local UserManager = {}
UserManager.__index = UserManager

-- Constants and configuration
local API_BASE_URL = "https://api.example.com"
local RETRY_ATTEMPTS = 3
local TIMEOUT_SECONDS = 5.0

-- Enum-like table
local UserStatus = {
    ACTIVE = "active",
    INACTIVE = "inactive",
    PENDING = "pending",
    SUSPENDED = "suspended"
}

-- Configuration table
local config = {
    api_url = API_BASE_URL,
    timeout = TIMEOUT_SECONDS,
    retries = RETRY_ATTEMPTS,
    features = {
        caching = true,
        logging = false,
        debugging = os.getenv("LUA_ENV") == "development"
    },
    supported_formats = {"json", "xml", "csv"},
    version = "2.1.0"
}

-- User class constructor
function UserManager:new(options)
    options = options or {}
    local instance = {
        api_url = options.api_url or config.api_url,
        timeout = options.timeout or config.timeout,
        retries = options.retries or config.retries,
        cache = {},
        session_id = nil
    }
    setmetatable(instance, UserManager)
    return instance
end

-- User data model
local function create_user(data)
    return {
        id = data.id or "",
        name = data.name or "",
        email = data.email or "",
        status = data.status or UserStatus.ACTIVE,
        created_at = os.time(),
        metadata = data.metadata or {},

        -- Method to validate user data
        validate = function(self)
            if #self.name == 0 then
                return false, "Name is required"
            end

            if not string.match(self.email, "^[%w._%+-]+@[%w.-]+%.%w+$") then
                return false, "Invalid email format"
            end

            local valid_statuses = {}
            for _, status in pairs(UserStatus) do
                valid_statuses[status] = true
            end

            if not valid_statuses[self.status] then
                return false, "Invalid status"
            end

            return true, nil
        end,

        -- Method to convert to JSON-like string
        to_string = function(self)
            local parts = {}
            table.insert(parts, string.format("ID: %s", self.id))
            table.insert(parts, string.format("Name: %s", self.name))
            table.insert(parts, string.format("Email: %s", self.email))
            table.insert(parts, string.format("Status: %s", self.status))
            return "{" .. table.concat(parts, ", ") .. "}"
        end
    }
end

-- Fetch user method with error handling
function UserManager:fetch_user(user_id)
    -- Input validation
    if not user_id or type(user_id) ~= "string" or #user_id == 0 then
        return nil, "Invalid user ID"
    end

    -- Check cache first
    if self.cache[user_id] then
        print(string.format("Cache hit for user: %s", user_id))
        return self.cache[user_id], nil
    end

    -- Simulate API call with retry logic
    local attempts = 0
    while attempts < self.retries do
        attempts = attempts + 1

        -- Simulate network delay
        local delay = math.random(100, 500) / 1000
        os.execute(string.format("sleep %.3f", delay))

        -- Simulate random failures
        if math.random() < 0.3 and attempts < self.retries then
            print(string.format("API call failed, attempt %d/%d", attempts, self.retries))
        else
            -- Simulate successful response
            local user_data = {
                id = user_id,
                name = "User " .. user_id,
                email = string.format("user%s@example.com", user_id),
                status = UserStatus.ACTIVE,
                metadata = {
                    last_login = os.time(),
                    login_count = math.random(1, 100)
                }
            }

            local user = create_user(user_data)

            -- Cache the result
            self.cache[user_id] = user

            print(string.format("Fetched user: %s", user:to_string()))
            return user, nil
        end
    end

    return nil, string.format("Failed to fetch user after %d attempts", self.retries)
end

-- Batch fetch users
function UserManager:batch_fetch_users(user_ids)
    local results = {}
    local errors = {}

    for i, user_id in ipairs(user_ids) do
        local user, error = self:fetch_user(user_id)

        if user then
            table.insert(results, user)
        else
            errors[user_id] = error
        end
    end

    return results, errors
end

-- Update user method
function UserManager:update_user(user_id, updates)
    local user, error = self:fetch_user(user_id)

    if not user then
        return nil, error
    end

    -- Apply updates
    for key, value in pairs(updates) do
        if user[key] ~= nil then
            user[key] = value
        end
    end

    -- Validate updated user
    local valid, validation_error = user:validate()
    if not valid then
        return nil, validation_error
    end

    -- Update cache
    self.cache[user_id] = user

    print(string.format("Updated user: %s", user:to_string()))
    return user, nil
end

-- Clear cache method
function UserManager:clear_cache()
    local count = 0
    for _ in pairs(self.cache) do
        count = count + 1
    end

    self.cache = {}
    print(string.format("Cleared cache (%d entries)", count))
    return count
end

-- Utility functions
local function format_timestamp(timestamp)
    return os.date("%Y-%m-%d %H:%M:%S", timestamp)
end

local function generate_random_id(length)
    length = length or 8
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local result = {}

    for i = 1, length do
        local random_index = math.random(1, #chars)
        table.insert(result, string.sub(chars, random_index, random_index))
    end

    return table.concat(result)
end

-- Filter users by status
local function filter_users_by_status(users, status)
    local filtered = {}

    for _, user in ipairs(users) do
        if user.status == status then
            table.insert(filtered, user)
        end
    end

    return filtered
end

-- Higher-order function example
local function map(list, func)
    local result = {}
    for i, item in ipairs(list) do
        result[i] = func(item)
    end
    return result
end

-- Coroutine example
local function async_operation()
    return coroutine.create(function()
        for i = 1, 5 do
            print(string.format("Async step %d", i))
            coroutine.yield(i)
        end
        return "Async operation completed"
    end)
end

-- Error handling with pcall
local function safe_divide(a, b)
    local success, result = pcall(function()
        if b == 0 then
            error("Division by zero")
        end
        return a / b
    end)

    if success then
        return result, nil
    else
        return nil, result
    end
end

-- Metatable example
local Vector = {}
Vector.__index = Vector

function Vector:new(x, y)
    return setmetatable({x = x or 0, y = y or 0}, Vector)
end

function Vector:__add(other)
    return Vector:new(self.x + other.x, self.y + other.y)
end

function Vector:__tostring()
    return string.format("Vector(%.2f, %.2f)", self.x, self.y)
end

function Vector:magnitude()
    return math.sqrt(self.x^2 + self.y^2)
end

-- Example usage and testing
local function main()
    print("=== Lua Syntax Highlighting Test ===")
    print()

    -- Create user manager
    local manager = UserManager:new({
        timeout = 3.0,
        retries = 2
    })

    -- Test user operations
    print("Testing user operations:")

    local user_ids = {"1", "2", "3", "invalid_id"}
    local users, fetch_errors = manager:batch_fetch_users(user_ids)

    print(string.format("Fetched %d users", #users))

    if next(fetch_errors) then
        print("Errors encountered:")
        for user_id, error in pairs(fetch_errors) do
            print(string.format("  %s: %s", user_id, error))
        end
    end

    -- Update a user
    if #users > 0 then
        local updated_user, update_error = manager:update_user(users[1].id, {
            status = UserStatus.PENDING,
            name = "Updated User Name"
        })

        if updated_user then
            print("User updated successfully")
        else
            print("Update failed: " .. update_error)
        end
    end

    -- Test utility functions
    print()
    print("Testing utility functions:")

    local active_users = filter_users_by_status(users, UserStatus.ACTIVE)
    print(string.format("Active users: %d", #active_users))

    local user_names = map(users, function(user) return user.name end)
    print("User names: " .. table.concat(user_names, ", "))

    -- Test safe division
    local result, error = safe_divide(10, 2)
    if result then
        print(string.format("10 / 2 = %.2f", result))
    end

    result, error = safe_divide(10, 0)
    if error then
        print("Division error: " .. error)
    end

    -- Test vectors
    print()
    print("Testing vector operations:")

    local v1 = Vector:new(3, 4)
    local v2 = Vector:new(1, 2)
    local v3 = v1 + v2

    print(string.format("%s + %s = %s", tostring(v1), tostring(v2), tostring(v3)))
    print(string.format("Magnitude of %s: %.2f", tostring(v1), v1:magnitude()))

    -- Test coroutine
    print()
    print("Testing coroutine:")

    local co = async_operation()
    while coroutine.status(co) ~= "dead" do
        local success, value = coroutine.resume(co)
        if success and value then
            print("Coroutine yielded: " .. tostring(value))
        end
    end

    -- Cleanup
    local cleared_count = manager:clear_cache()
    print(string.format("Cleanup completed, cleared %d cache entries", cleared_count))
end

-- Export module (if running in a module system)
if _G.module then
    return {
        UserManager = UserManager,
        UserStatus = UserStatus,
        create_user = create_user,
        Vector = Vector,
        main = main
    }
end

-- Run main if this file is executed directly
if arg and arg[0] == "test.lua" then
    main()
end
