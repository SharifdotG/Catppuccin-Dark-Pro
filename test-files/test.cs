// C# Test File for Theme Validation
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Text.Json;
using Microsoft.Extensions.Logging;

namespace ThemeTest.Models
{
    /// <summary>
    /// User status enumeration
    /// </summary>
    public enum UserStatus
    {
        Active = 1,
        Inactive = 2,
        Pending = 3,
        Suspended = 4
    }

    /// <summary>
    /// User data model with properties and validation
    /// </summary>
    public record User(
        string Id,
        string Name,
        string Email,
        UserStatus Status = UserStatus.Active)
    {
        public DateTime CreatedAt { get; init; } = DateTime.UtcNow;
        public Dictionary<string, object> Metadata { get; init; } = new();

        public bool IsActive => Status == UserStatus.Active;

        public string DisplayName => !string.IsNullOrEmpty(Name) ? Name : Email;
    }

    /// <summary>
    /// Generic API response wrapper
    /// </summary>
    public class ApiResponse<T>
    {
        public bool Success { get; set; }
        public T? Data { get; set; }
        public string? Error { get; set; }
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }

    /// <summary>
    /// User management service with async operations
    /// </summary>
    public class UserManager : IDisposable
    {
        private readonly ILogger<UserManager> _logger;
        private readonly HttpClient _httpClient;
        private readonly Dictionary<string, User> _cache;
        private readonly string _baseUrl;
        private bool _disposed = false;

        // Constants
        private const int MAX_RETRIES = 3;
        private const int TIMEOUT_MS = 5000;
        private static readonly string[] SUPPORTED_FORMATS = { "json", "xml", "csv" };

        public UserManager(ILogger<UserManager> logger, HttpClient httpClient, string baseUrl = "https://api.example.com")
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
            _baseUrl = baseUrl;
            _cache = new Dictionary<string, User>();
        }

        /// <summary>
        /// Fetch user by ID with caching and error handling
        /// </summary>
        /// <param name="userId">The user ID to fetch</param>
        /// <param name="cancellationToken">Cancellation token</param>
        /// <returns>User object if found, null otherwise</returns>
        public async Task<User?> FetchUserAsync(string userId, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(userId))
                throw new ArgumentException("User ID cannot be null or empty", nameof(userId));

            // Check cache first
            if (_cache.TryGetValue(userId, out var cachedUser))
            {
                _logger.LogInformation("User {UserId} found in cache", userId);
                return cachedUser;
            }

            try
            {
                var response = await _httpClient.GetAsync($"{_baseUrl}/users/{userId}", cancellationToken);

                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning("Failed to fetch user {UserId}: {StatusCode}", userId, response.StatusCode);
                    return null;
                }

                var content = await response.Content.ReadAsStringAsync(cancellationToken);
                var apiResponse = JsonSerializer.Deserialize<ApiResponse<User>>(content);

                if (apiResponse?.Success == true && apiResponse.Data != null)
                {
                    _cache[userId] = apiResponse.Data;
                    _logger.LogInformation("User {UserId} fetched and cached successfully", userId);
                    return apiResponse.Data;
                }

                return null;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error fetching user {UserId}", userId);
                throw;
            }
        }

        /// <summary>
        /// Batch fetch multiple users concurrently
        /// </summary>
        public async Task<Dictionary<string, User?>> BatchFetchUsersAsync(IEnumerable<string> userIds, CancellationToken cancellationToken = default)
        {
            var tasks = userIds.Select(async id => new { Id = id, User = await FetchUserAsync(id, cancellationToken) });
            var results = await Task.WhenAll(tasks);

            return results.ToDictionary(r => r.Id, r => r.User);
        }

        /// <summary>
        /// Update user with validation
        /// </summary>
        public async Task<bool> UpdateUserAsync(string userId, Dictionary<string, object> updates, CancellationToken cancellationToken = default)
        {
            var user = await FetchUserAsync(userId, cancellationToken);
            if (user == null)
                return false;

            try
            {
                var json = JsonSerializer.Serialize(updates);
                var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

                var response = await _httpClient.PutAsync($"{_baseUrl}/users/{userId}", content, cancellationToken);
                return response.IsSuccessStatusCode;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating user {UserId}", userId);
                return false;
            }
        }

        /// <summary>
        /// Filter users by status using LINQ
        /// </summary>
        public IEnumerable<User> FilterUsersByStatus(IEnumerable<User> users, UserStatus status)
        {
            return users.Where(user => user.Status == status)
                       .OrderBy(user => user.Name)
                       .ThenBy(user => user.CreatedAt);
        }

        /// <summary>
        /// Get user statistics
        /// </summary>
        public UserStatistics GetUserStatistics(IEnumerable<User> users)
        {
            var userList = users.ToList();

            return new UserStatistics
            {
                TotalUsers = userList.Count,
                ActiveUsers = userList.Count(u => u.Status == UserStatus.Active),
                InactiveUsers = userList.Count(u => u.Status == UserStatus.Inactive),
                PendingUsers = userList.Count(u => u.Status == UserStatus.Pending),
                SuspendedUsers = userList.Count(u => u.Status == UserStatus.Suspended),
                AverageUsersPerDay = CalculateAverageUsersPerDay(userList)
            };
        }

        private double CalculateAverageUsersPerDay(List<User> users)
        {
            if (!users.Any()) return 0;

            var oldestUser = users.Min(u => u.CreatedAt);
            var daysSinceOldest = (DateTime.UtcNow - oldestUser).TotalDays;

            return daysSinceOldest > 0 ? users.Count / daysSinceOldest : users.Count;
        }

        // IDisposable implementation
        protected virtual void Dispose(bool disposing)
        {
            if (!_disposed)
            {
                if (disposing)
                {
                    _httpClient?.Dispose();
                    _cache?.Clear();
                }
                _disposed = true;
            }
        }

        public void Dispose()
        {
            Dispose(disposing: true);
            GC.SuppressFinalize(this);
        }
    }

    /// <summary>
    /// User statistics data structure
    /// </summary>
    public struct UserStatistics
    {
        public int TotalUsers { get; init; }
        public int ActiveUsers { get; init; }
        public int InactiveUsers { get; init; }
        public int PendingUsers { get; init; }
        public int SuspendedUsers { get; init; }
        public double AverageUsersPerDay { get; init; }
    }

    /// <summary>
    /// Extension methods for User
    /// </summary>
    public static class UserExtensions
    {
        public static string ToJson(this User user) => JsonSerializer.Serialize(user);

        public static bool HasValidEmail(this User user) =>
            !string.IsNullOrEmpty(user.Email) && user.Email.Contains('@');

        public static int DaysActive(this User user) =>
            (DateTime.UtcNow - user.CreatedAt).Days;
    }
}

// Program entry point
namespace ThemeTest
{
    public class Program
    {
        public static async Task Main(string[] args)
        {
            // Dependency injection setup
            using var loggerFactory = LoggerFactory.Create(builder => builder.AddConsole());
            var logger = loggerFactory.CreateLogger<UserManager>();

            using var httpClient = new HttpClient();
            using var userManager = new UserManager(logger, httpClient);

            try
            {
                // Create sample users
                var users = new List<User>
                {
                    new("1", "John Doe", "john@example.com", UserStatus.Active),
                    new("2", "Jane Smith", "jane@example.com", UserStatus.Pending),
                    new("3", "Bob Johnson", "bob@example.com", UserStatus.Inactive)
                };

                // Demonstrate filtering and statistics
                var activeUsers = userManager.FilterUsersByStatus(users, UserStatus.Active);
                var stats = userManager.GetUserStatistics(users);

                Console.WriteLine($"Total Users: {stats.TotalUsers}");
                Console.WriteLine($"Active Users: {stats.ActiveUsers}");
                Console.WriteLine($"Average Users per Day: {stats.AverageUsersPerDay:F2}");

                // Demonstrate extension methods
                foreach (var user in users)
                {
                    Console.WriteLine($"{user.DisplayName}: {user.DaysActive()} days active, Valid Email: {user.HasValidEmail()}");
                }

                // Async operations
                var userIds = users.Select(u => u.Id);
                var batchResults = await userManager.BatchFetchUsersAsync(userIds);

                Console.WriteLine($"Batch fetch completed: {batchResults.Count} results");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error: {ex.Message}");
            }
        }
    }
}
