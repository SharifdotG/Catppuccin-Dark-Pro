// Kotlin Test File for Theme Validation
package com.example.themetest

import kotlinx.coroutines.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import java.util.concurrent.ConcurrentHashMap
import java.util.regex.Pattern

// Constants
const val API_BASE_URL = "https://api.example.com"
const val MAX_RETRIES = 3
const val TIMEOUT_SECONDS = 5L
val SUPPORTED_FORMATS = listOf("json", "xml", "csv")

// Custom exceptions
class UserNotFoundException(userId: String) : Exception("User not found: $userId")
class InvalidEmailException(email: String) : Exception("Invalid email format: $email")
class ApiException(message: String) : Exception("API request failed: $message")

// User status enumeration
enum class UserStatus(val displayName: String) {
    ACTIVE("Active"),
    INACTIVE("Inactive"),
    PENDING("Pending"),
    SUSPENDED("Suspended");

    fun isValid(): Boolean = this in listOf(ACTIVE, INACTIVE, PENDING)

    companion object {
        fun fromString(value: String): UserStatus? =
            values().find { it.name.equals(value, ignoreCase = true) }
    }
}

// User data class with validation
@Serializable
data class User(
    val id: String,
    val name: String,
    val email: String,
    val status: UserStatus = UserStatus.ACTIVE,
    val createdAt: String = LocalDateTime.now().toString(),
    val metadata: MutableMap<String, String> = mutableMapOf()
) {
    init {
        require(id.isNotBlank()) { "User ID cannot be empty" }
        require(name.isNotBlank()) { "User name cannot be empty" }
        require(isValidEmail(email)) { "Invalid email format: $email" }
    }

    val isActive: Boolean
        get() = status == UserStatus.ACTIVE

    val displayName: String
        get() = name.ifBlank { email }

    val daysActive: Long
        get() {
            val created = LocalDateTime.parse(createdAt)
            return ChronoUnit.DAYS.between(created, LocalDateTime.now())
        }

    fun hasValidEmail(): Boolean = isValidEmail(email)

    fun getAgeCategory(): String = when (daysActive) {
        in 0..30 -> "New"
        in 31..365 -> "Regular"
        else -> "Veteran"
    }

    fun addMetadata(key: String, value: String) {
        metadata[key] = value
    }

    fun getMetadata(key: String): String? = metadata[key]

    override fun toString(): String =
        "User(id=$id, name=$name, email=$email, status=$status)"

    companion object {
        private val EMAIL_PATTERN = Pattern.compile(
            "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        )

        fun isValidEmail(email: String): Boolean = EMAIL_PATTERN.matcher(email).matches()

        fun createFromMap(data: Map<String, Any>): User {
            return User(
                id = data["id"] as String,
                name = data["name"] as String,
                email = data["email"] as String,
                status = UserStatus.fromString(data["status"] as? String ?: "active")
                    ?: UserStatus.ACTIVE,
                createdAt = data["created_at"] as? String ?: LocalDateTime.now().toString(),
                metadata = (data["metadata"] as? Map<String, String>)?.toMutableMap()
                    ?: mutableMapOf()
            )
        }
    }
}

// API Response wrapper
@Serializable
data class ApiResponse<T>(
    val success: Boolean,
    val data: T? = null,
    val error: String? = null,
    val timestamp: String = LocalDateTime.now().toString()
) {
    companion object {
        fun <T> success(data: T): ApiResponse<T> = ApiResponse(
            success = true,
            data = data
        )

        fun <T> error(message: String): ApiResponse<T> = ApiResponse(
            success = false,
            error = message
        )
    }
}

// User statistics data class
data class UserStatistics(
    val total: Int,
    val active: Int,
    val inactive: Int,
    val pending: Int,
    val suspended: Int,
    val averageDaysActive: Double
) {
    override fun toString(): String =
        "UserStats(total=$total, active=$active, inactive=$inactive, " +
        "pending=$pending, suspended=$suspended, avgDays=${"%.2f".format(averageDaysActive)})"
}

// User operations interface
interface UserOperations {
    fun validate(): Boolean
    fun export(format: String): String
    suspend fun save(): Boolean
}

// User manager class with coroutines
class UserManager(
    private val baseUrl: String = API_BASE_URL,
    private val timeout: Long = TIMEOUT_SECONDS
) : UserOperations {

    private val cache = ConcurrentHashMap<String, User>()
    private val json = Json { prettyPrint = true }

    // Fetch user by ID with caching
    suspend fun fetchUser(userId: String): User? = withContext(Dispatchers.IO) {
        require(userId.isNotBlank()) { "User ID cannot be empty" }

        // Check cache first
        cache[userId]?.let { cachedUser ->
            println("User $userId found in cache")
            return@withContext cachedUser
        }

        try {
            // Simulate API call with delay
            delay(100) // Simulate network delay

            val response = simulateApiCall(userId)

            if (response.success && response.data != null) {
                cache[userId] = response.data
                println("User $userId fetched and cached successfully")
                response.data
            } else {
                println("Failed to fetch user $userId: ${response.error}")
                null
            }
        } catch (e: Exception) {
            println("Error fetching user $userId: ${e.message}")
            null
        }
    }

    // Batch fetch multiple users concurrently
    suspend fun batchFetchUsers(userIds: List<String>): Map<String, User?> = coroutineScope {
        userIds.map { userId ->
            async { userId to fetchUser(userId) }
        }.awaitAll().toMap()
    }

    // Update user information
    suspend fun updateUser(userId: String, updates: Map<String, Any>): Boolean = withContext(Dispatchers.IO) {
        try {
            // Simulate API call
            delay(200)

            val success = simulateUpdateApiCall(userId, updates)

            if (success) {
                // Invalidate cache
                cache.remove(userId)
                println("User $userId updated successfully")
            } else {
                println("Failed to update user $userId")
            }

            success
        } catch (e: Exception) {
            println("Error updating user $userId: ${e.message}")
            false
        }
    }

    // Filter users by status using functional programming
    fun filterUsersByStatus(users: List<User>, status: UserStatus): List<User> =
        users.filter { it.status == status }
            .sortedWith(compareBy({ it.name }, { it.createdAt }))

    // Get user statistics
    fun getUserStatistics(users: List<User>): UserStatistics {
        val total = users.size
        val statusCounts = users.groupingBy { it.status }.eachCount()

        val averageDaysActive = if (users.isNotEmpty()) {
            users.map { it.daysActive }.average()
        } else {
            0.0
        }

        return UserStatistics(
            total = total,
            active = statusCounts[UserStatus.ACTIVE] ?: 0,
            inactive = statusCounts[UserStatus.INACTIVE] ?: 0,
            pending = statusCounts[UserStatus.PENDING] ?: 0,
            suspended = statusCounts[UserStatus.SUSPENDED] ?: 0,
            averageDaysActive = averageDaysActive
        )
    }

    // Clear cache and return number of entries cleared
    fun clearCache(): Int {
        val count = cache.size
        cache.clear()
        println("Cache cleared: $count entries removed")
        return count
    }

    // Export users to different formats
    fun exportUsers(users: List<User>, format: String = "json"): String {
        require(format in SUPPORTED_FORMATS) { "Unsupported format: $format" }

        return when (format.lowercase()) {
            "json" -> json.encodeToString(users)
            "csv" -> exportToCsv(users)
            "xml" -> exportToXml(users)
            else -> throw IllegalArgumentException("Unsupported format: $format")
        }
    }

    private fun exportToCsv(users: List<User>): String = buildString {
        appendLine("ID,Name,Email,Status,Created At")
        users.forEach { user ->
            appendLine("${user.id},${user.name},${user.email},${user.status},${user.createdAt}")
        }
    }

    private fun exportToXml(users: List<User>): String = buildString {
        appendLine("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        appendLine("<users>")
        users.forEach { user ->
            appendLine("  <user>")
            appendLine("    <id>${user.id}</id>")
            appendLine("    <name>${user.name}</name>")
            appendLine("    <email>${user.email}</email>")
            appendLine("    <status>${user.status}</status>")
            appendLine("    <created_at>${user.createdAt}</created_at>")
            appendLine("  </user>")
        }
        appendLine("</users>")
    }

    // Simulate API calls for testing
    private fun simulateApiCall(userId: String): ApiResponse<User> {
        return when (userId) {
            "1" -> ApiResponse.success(User("1", "John Doe", "john@example.com"))
            "2" -> ApiResponse.success(User("2", "Jane Smith", "jane@example.com", UserStatus.PENDING))
            "3" -> ApiResponse.success(User("3", "Bob Johnson", "bob@example.com", UserStatus.INACTIVE))
            else -> ApiResponse.error("User not found")
        }
    }

    private fun simulateUpdateApiCall(userId: String, updates: Map<String, Any>): Boolean {
        // Simulate API success/failure
        return userId.isNotBlank() && updates.isNotEmpty()
    }

    // UserOperations interface implementation
    override fun validate(): Boolean = true

    override fun export(format: String): String = "Mock export in $format format"

    override suspend fun save(): Boolean {
        delay(100)
        return true
    }
}

// Extension functions
fun List<User>.activeUsers(): List<User> = filter { it.isActive }

fun List<User>.byStatus(status: UserStatus): List<User> = filter { it.status == status }

fun List<User>.averageAge(): Double = if (isEmpty()) 0.0 else map { it.daysActive }.average()

fun User.isNewUser(): Boolean = daysActive <= 30

fun User.toJsonString(): String = Json.encodeToString(this)

// Higher-order functions and lambdas
object UserUtils {
    fun processUsers(
        users: List<User>,
        filter: (User) -> Boolean = { true },
        transform: (User) -> String = { it.toString() }
    ): List<String> = users.filter(filter).map(transform)

    fun findUser(users: List<User>, predicate: (User) -> Boolean): User? =
        users.find(predicate)

    fun validateUsers(users: List<User>, validator: (User) -> Boolean): List<User> =
        users.filter(validator)
}

// Sealed class for user events
sealed class UserEvent {
    data class Created(val user: User) : UserEvent()
    data class Updated(val user: User, val changes: Map<String, Any>) : UserEvent()
    data class Deleted(val userId: String) : UserEvent()
    data class StatusChanged(val user: User, val oldStatus: UserStatus, val newStatus: UserStatus) : UserEvent()
}

// Event handler
class UserEventHandler {
    fun handleEvent(event: UserEvent) {
        when (event) {
            is UserEvent.Created -> println("User created: ${event.user.displayName}")
            is UserEvent.Updated -> println("User updated: ${event.user.displayName} with ${event.changes.size} changes")
            is UserEvent.Deleted -> println("User deleted: ${event.userId}")
            is UserEvent.StatusChanged -> println("User ${event.user.displayName} status changed from ${event.oldStatus} to ${event.newStatus}")
        }
    }
}

// Main function with coroutines
suspend fun main() {
    println("Kotlin User Management System")
    println("===============================")

    // Create sample users
    val users = listOf(
        User("1", "John Doe", "john@example.com"),
        User("2", "Jane Smith", "jane@example.com", UserStatus.PENDING),
        User("3", "Bob Johnson", "bob@example.com", UserStatus.INACTIVE)
    )

    val manager = UserManager()

    // Test user properties
    users.forEach { user ->
        println("$user - Days active: ${user.daysActive}, Category: ${user.getAgeCategory()}")
    }

    // Test filtering with extension functions
    val activeUsers = users.activeUsers()
    println("\nActive users: ${activeUsers.size}")

    val pendingUsers = users.byStatus(UserStatus.PENDING)
    println("Pending users: ${pendingUsers.size}")

    // Test statistics
    val stats = manager.getUserStatistics(users)
    println("\nUser Statistics: $stats")

    // Test async operations
    try {
        val userIds = users.map { it.id }
        val batchResults = manager.batchFetchUsers(userIds)
        println("\nBatch fetch completed: ${batchResults.size} results")

        batchResults.forEach { (id, user) ->
            if (user != null) {
                println("✓ Fetched user: ${user.displayName}")
            } else {
                println("✗ Failed to fetch user: $id")
            }
        }
    } catch (e: Exception) {
        println("Error in batch fetch: ${e.message}")
    }

    // Test export functionality
    try {
        val jsonExport = manager.exportUsers(users, "json")
        println("\nJSON Export:")
        println(jsonExport)

        val csvExport = manager.exportUsers(users, "csv")
        println("\nCSV Export:")
        println(csvExport)
    } catch (e: Exception) {
        println("Export error: ${e.message}")
    }

    // Test higher-order functions
    val userNames = UserUtils.processUsers(
        users = users,
        filter = { it.isActive },
        transform = { it.displayName }
    )
    println("\nActive user names: $userNames")

    val newUsers = users.filter { it.isNewUser() }
    println("New users: ${newUsers.map { it.displayName }}")

    // Test event handling
    val eventHandler = UserEventHandler()
    val events = listOf(
        UserEvent.Created(users[0]),
        UserEvent.StatusChanged(users[1], UserStatus.ACTIVE, UserStatus.PENDING),
        UserEvent.Updated(users[2], mapOf("email" to "newemail@example.com")),
        UserEvent.Deleted("4")
    )

    println("\nEvent Processing:")
    events.forEach { eventHandler.handleEvent(it) }

    // Test validation and error handling
    try {
        val invalidUser = User("", "Invalid User", "invalid-email")
        println("This should not print: $invalidUser")
    } catch (e: IllegalArgumentException) {
        println("\nExpected validation error: ${e.message}")
    }

    // Test metadata operations
    val userWithMetadata = users[0].apply {
        addMetadata("last_login", LocalDateTime.now().toString())
        addMetadata("preferences", "dark_theme")
    }

    println("\nUser metadata:")
    println("Last login: ${userWithMetadata.getMetadata("last_login")}")
    println("Preferences: ${userWithMetadata.getMetadata("preferences")}")

    // Test coroutine cancellation
    val job = GlobalScope.launch {
        try {
            repeat(5) { i ->
                println("Background task $i")
                delay(1000)
            }
        } catch (e: CancellationException) {
            println("Background task was cancelled")
        }
    }

    delay(2500)
    job.cancel()

    println("\nKotlin syntax highlighting test completed!")
}
