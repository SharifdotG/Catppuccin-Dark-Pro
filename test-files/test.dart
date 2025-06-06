// Dart Test File for Theme Validation
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

// Constants
const String apiBaseUrl = 'https://api.example.com';
const int maxRetries = 3;
const int timeoutSeconds = 5;
const List<String> supportedFormats = ['json', 'xml', 'csv'];

// Custom exceptions
class UserNotFoundException implements Exception {
  final String userId;
  const UserNotFoundException(this.userId);

  @override
  String toString() => 'User not found: $userId';
}

class InvalidEmailException implements Exception {
  final String email;
  const InvalidEmailException(this.email);

  @override
  String toString() => 'Invalid email format: $email';
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'API request failed: $message';
}

// User status enumeration
enum UserStatus {
  active('Active'),
  inactive('Inactive'),
  pending('Pending'),
  suspended('Suspended');

  const UserStatus(this.displayName);

  final String displayName;

  bool get isValid => this == UserStatus.active ||
                     this == UserStatus.inactive ||
                     this == UserStatus.pending;

  static UserStatus? fromString(String value) {
    for (final status in UserStatus.values) {
      if (status.name.toLowerCase() == value.toLowerCase()) {
        return status;
      }
    }
    return null;
  }

  String toJson() => name;

  factory UserStatus.fromJson(String json) {
    return fromString(json) ?? UserStatus.active;
  }
}

// User data class with validation
class User {
  final String id;
  final String name;
  final String email;
  UserStatus status;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.status = UserStatus.active,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) : createdAt = createdAt ?? DateTime.now(),
       metadata = metadata ?? <String, dynamic>{} {
    _validate();
  }

  void _validate() {
    if (id.trim().isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('User name cannot be empty');
    }
    if (!isValidEmail(email)) {
      throw InvalidEmailException(email);
    }
  }

  bool get isActive => status == UserStatus.active;

  String get displayName => name.isNotEmpty ? name : email;

  int get daysActive => DateTime.now().difference(createdAt).inDays;

  bool get hasValidEmail => isValidEmail(email);

  String get ageCategory {
    final days = daysActive;
    if (days <= 30) return 'New';
    if (days <= 365) return 'Regular';
    return 'Veteran';
  }

  bool get isNewUser => daysActive <= 30;

  bool get isExpired => daysActive > 365 && status == UserStatus.inactive;

  void addMetadata(String key, dynamic value) {
    metadata[key] = value;
  }

  dynamic getMetadata(String key) => metadata[key];

  void setStatus(UserStatus newStatus) {
    status = newStatus;
  }

  static bool isValidEmail(String email) {
    const pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    return RegExp(pattern).hasMatch(email);
  }

  // JSON serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'status': status.toJson(),
    'created_at': createdAt.toIso8601String(),
    'metadata': metadata,
    'is_active': isActive,
    'display_name': displayName,
    'days_active': daysActive,
  };

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      status: UserStatus.fromJson(json['status'] as String? ?? 'active'),
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  factory User.fromMap(Map<String, dynamic> data) => User.fromJson(data);

  User copyWith({
    String? id,
    String? name,
    String? email,
    UserStatus? status,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? Map.from(this.metadata),
    );
  }

  @override
  String toString() => 'User(id: $id, name: $name, email: $email, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}

// API Response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final DateTime timestamp;

  const ApiResponse({
    required this.success,
    this.data,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? const ApiResponse._now();

  const ApiResponse._now() : timestamp = null;

  factory ApiResponse.success(T data) => ApiResponse(
        success: true,
        data: data,
        timestamp: DateTime.now(),
      );

  factory ApiResponse.error(String message) => ApiResponse(
        success: false,
        error: message,
        timestamp: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'success': success,
        'data': data,
        'error': error,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
    return ApiResponse(
      success: json['success'] as bool,
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      error: json['error'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

// User statistics data class
class UserStatistics {
  final int total;
  final int active;
  final int inactive;
  final int pending;
  final int suspended;
  final double averageDaysActive;

  const UserStatistics({
    required this.total,
    required this.active,
    required this.inactive,
    required this.pending,
    required this.suspended,
    required this.averageDaysActive,
  });

  Map<String, dynamic> toJson() => {
        'total': total,
        'active': active,
        'inactive': inactive,
        'pending': pending,
        'suspended': suspended,
        'average_days_active': averageDaysActive,
      };

  @override
  String toString() =>
      'UserStats(total: $total, active: $active, inactive: $inactive, '
      'pending: $pending, suspended: $suspended, avgDays: ${averageDaysActive.toStringAsFixed(2)})';
}

// User operations mixin
mixin UserOperations {
  bool validate();
  String export(String format);
  Future<bool> save();
}

// User manager class with async operations
class UserManager with UserOperations {
  final String baseUrl;
  final int timeout;
  final Map<String, User> _cache = <String, User>{};
  final HttpClient _httpClient = HttpClient();

  UserManager({
    this.baseUrl = apiBaseUrl,
    this.timeout = timeoutSeconds,
  }) {
    _httpClient.connectionTimeout = Duration(seconds: timeout);
  }

  // Fetch user by ID with caching
  Future<User?> fetchUser(String userId) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('User ID cannot be empty');
    }

    // Check cache first
    if (_cache.containsKey(userId)) {
      print('User $userId found in cache');
      return _cache[userId];
    }

    try {
      final user = await _fetchFromApi(userId);
      if (user != null) {
        _cache[userId] = user;
        print('User $userId fetched and cached successfully');
      }
      return user;
    } catch (e) {
      print('Error fetching user $userId: $e');
      return null;
    }
  }

  Future<User?> _fetchFromApi(String userId) async {
    // Simulate API call
    await Future.delayed(Duration(milliseconds: 100));

    // Mock data for testing
    switch (userId) {
      case '1':
        return User(id: '1', name: 'John Doe', email: 'john@example.com');
      case '2':
        return User(id: '2', name: 'Jane Smith', email: 'jane@example.com', status: UserStatus.pending);
      case '3':
        return User(id: '3', name: 'Bob Johnson', email: 'bob@example.com', status: UserStatus.inactive);
      default:
        return null;
    }
  }

  // Batch fetch multiple users concurrently
  Future<Map<String, User?>> batchFetchUsers(List<String> userIds) async {
    final futures = userIds.map((id) async {
      final user = await fetchUser(id);
      return MapEntry(id, user);
    });

    final results = await Future.wait(futures);
    return Map.fromEntries(results);
  }

  // Update user information
  Future<bool> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await Future.delayed(Duration(milliseconds: 200)); // Simulate API call

      // Invalidate cache
      _cache.remove(userId);
      print('User $userId updated successfully');
      return true;
    } catch (e) {
      print('Error updating user $userId: $e');
      return false;
    }
  }

  // Filter users by status using functional programming
  List<User> filterUsersByStatus(List<User> users, UserStatus status) {
    return users
        .where((user) => user.status == status)
        .toList()
      ..sort((a, b) {
        final nameComparison = a.name.compareTo(b.name);
        return nameComparison != 0 ? nameComparison : a.createdAt.compareTo(b.createdAt);
      });
  }

  // Get user statistics
  UserStatistics getUserStatistics(List<User> users) {
    if (users.isEmpty) {
      return const UserStatistics(
        total: 0,
        active: 0,
        inactive: 0,
        pending: 0,
        suspended: 0,
        averageDaysActive: 0.0,
      );
    }

    final statusCounts = <UserStatus, int>{};
    var totalDays = 0;

    for (final user in users) {
      statusCounts[user.status] = (statusCounts[user.status] ?? 0) + 1;
      totalDays += user.daysActive;
    }

    return UserStatistics(
      total: users.length,
      active: statusCounts[UserStatus.active] ?? 0,
      inactive: statusCounts[UserStatus.inactive] ?? 0,
      pending: statusCounts[UserStatus.pending] ?? 0,
      suspended: statusCounts[UserStatus.suspended] ?? 0,
      averageDaysActive: totalDays / users.length,
    );
  }

  // Clear cache and return number of entries cleared
  int clearCache() {
    final count = _cache.length;
    _cache.clear();
    print('Cache cleared: $count entries removed');
    return count;
  }

  // Export users to different formats
  String exportUsers(List<User> users, [String format = 'json']) {
    if (!supportedFormats.contains(format)) {
      throw ArgumentError('Unsupported format: $format');
    }

    switch (format.toLowerCase()) {
      case 'json':
        return _exportToJson(users);
      case 'csv':
        return _exportToCsv(users);
      case 'xml':
        return _exportToXml(users);
      default:
        throw ArgumentError('Unsupported format: $format');
    }
  }

  String _exportToJson(List<User> users) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(users.map((u) => u.toJson()).toList());
  }

  String _exportToCsv(List<User> users) {
    final buffer = StringBuffer();
    buffer.writeln('ID,Name,Email,Status,Created At');

    for (final user in users) {
      buffer.writeln('${user.id},${user.name},${user.email},${user.status.name},${user.createdAt.toIso8601String()}');
    }

    return buffer.toString();
  }

  String _exportToXml(List<User> users) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<users>');

    for (final user in users) {
      buffer.writeln('  <user>');
      buffer.writeln('    <id>${user.id}</id>');
      buffer.writeln('    <name>${user.name}</name>');
      buffer.writeln('    <email>${user.email}</email>');
      buffer.writeln('    <status>${user.status.name}</status>');
      buffer.writeln('    <created_at>${user.createdAt.toIso8601String()}</created_at>');
      buffer.writeln('  </user>');
    }

    buffer.writeln('</users>');
    return buffer.toString();
  }

  void dispose() {
    _httpClient.close();
  }

  // UserOperations mixin implementation
  @override
  bool validate() => true;

  @override
  String export(String format) => 'Mock export in $format format';

  @override
  Future<bool> save() async {
    await Future.delayed(Duration(milliseconds: 100));
    return true;
  }
}

// Extension methods
extension UserListExtensions on List<User> {
  List<User> get activeUsers => where((user) => user.isActive).toList();

  List<User> byStatus(UserStatus status) => where((user) => user.status == status).toList();

  double get averageAge => isEmpty ? 0.0 : map((user) => user.daysActive).reduce((a, b) => a + b) / length;

  List<User> get newUsers => where((user) => user.isNewUser).toList();

  Map<UserStatus, List<User>> groupByStatus() {
    final groups = <UserStatus, List<User>>{};
    for (final user in this) {
      groups.putIfAbsent(user.status, () => <User>[]).add(user);
    }
    return groups;
  }
}

extension UserExtensions on User {
  String toJsonString() => jsonEncode(toJson());

  bool isOlderThan(int days) => daysActive > days;

  User withStatus(UserStatus newStatus) => copyWith(status: newStatus);

  User withMetadata(String key, dynamic value) {
    final newUser = copyWith();
    newUser.addMetadata(key, value);
    return newUser;
  }
}

// Utility functions
class UserUtils {
  static List<String> processUsers(
    List<User> users, {
    bool Function(User)? filter,
    String Function(User)? transform,
  }) {
    final filteredUsers = filter != null ? users.where(filter).toList() : users;
    final transformFunction = transform ?? (user) => user.toString();
    return filteredUsers.map(transformFunction).toList();
  }

  static User? findUser(List<User> users, bool Function(User) predicate) {
    try {
      return users.firstWhere(predicate);
    } catch (e) {
      return null;
    }
  }

  static List<User> validateUsers(List<User> users, bool Function(User) validator) {
    return users.where(validator).toList();
  }

  static Future<List<User>> createUsersFromCsv(String csvData) async {
    final lines = csvData.split('\n');
    if (lines.isEmpty) return [];

    final users = <User>[];
    for (var i = 1; i < lines.length; i++) { // Skip header
      final parts = lines[i].split(',');
      if (parts.length >= 3) {
        try {
          final user = User(
            id: parts[0].trim(),
            name: parts[1].trim(),
            email: parts[2].trim(),
          );
          users.add(user);
        } catch (e) {
          print('Error creating user from line $i: $e');
        }
      }
    }
    return users;
  }
}

// Sealed class for user events
abstract class UserEvent {
  const UserEvent();
}

class UserCreated extends UserEvent {
  final User user;
  const UserCreated(this.user);

  @override
  String toString() => 'UserCreated(${user.displayName})';
}

class UserUpdated extends UserEvent {
  final User user;
  final Map<String, dynamic> changes;
  const UserUpdated(this.user, this.changes);

  @override
  String toString() => 'UserUpdated(${user.displayName}, ${changes.length} changes)';
}

class UserDeleted extends UserEvent {
  final String userId;
  const UserDeleted(this.userId);

  @override
  String toString() => 'UserDeleted($userId)';
}

class UserStatusChanged extends UserEvent {
  final User user;
  final UserStatus oldStatus;
  final UserStatus newStatus;
  const UserStatusChanged(this.user, this.oldStatus, this.newStatus);

  @override
  String toString() => 'UserStatusChanged(${user.displayName}, $oldStatus -> $newStatus)';
}

// Event handler
class UserEventHandler {
  void handleEvent(UserEvent event) {
    switch (event.runtimeType) {
      case UserCreated:
        final created = event as UserCreated;
        print('User created: ${created.user.displayName}');
        break;
      case UserUpdated:
        final updated = event as UserUpdated;
        print('User updated: ${updated.user.displayName} with ${updated.changes.length} changes');
        break;
      case UserDeleted:
        final deleted = event as UserDeleted;
        print('User deleted: ${deleted.userId}');
        break;
      case UserStatusChanged:
        final statusChanged = event as UserStatusChanged;
        print('User ${statusChanged.user.displayName} status changed from ${statusChanged.oldStatus} to ${statusChanged.newStatus}');
        break;
      default:
        print('Unknown event: $event');
    }
  }
}

// Main function
Future<void> main() async {
  print('Dart User Management System');
  print('===========================');

  // Create sample users
  final users = [
    User(id: '1', name: 'John Doe', email: 'john@example.com'),
    User(id: '2', name: 'Jane Smith', email: 'jane@example.com', status: UserStatus.pending),
    User(id: '3', name: 'Bob Johnson', email: 'bob@example.com', status: UserStatus.inactive),
  ];

  final manager = UserManager();

  try {
    // Test user properties
    for (final user in users) {
      print('$user - Days active: ${user.daysActive}, Category: ${user.ageCategory}');
    }

    // Test extension methods
    final activeUsers = users.activeUsers;
    print('\nActive users: ${activeUsers.length}');

    final pendingUsers = users.byStatus(UserStatus.pending);
    print('Pending users: ${pendingUsers.length}');

    final groupedUsers = users.groupByStatus();
    print('Users grouped by status: ${groupedUsers.keys.toList()}');

    // Test statistics
    final stats = manager.getUserStatistics(users);
    print('\nUser Statistics: $stats');

    // Test async operations
    final userIds = users.map((u) => u.id).toList();
    final batchResults = await manager.batchFetchUsers(userIds);
    print('\nBatch fetch completed: ${batchResults.length} results');

    batchResults.forEach((id, user) {
      if (user != null) {
        print('✓ Fetched user: ${user.displayName}');
      } else {
        print('✗ Failed to fetch user: $id');
      }
    });

    // Test export functionality
    final jsonExport = manager.exportUsers(users, 'json');
    print('\nJSON Export:');
    print(jsonExport);

    final csvExport = manager.exportUsers(users, 'csv');
    print('\nCSV Export:');
    print(csvExport);

    // Test utility functions
    final userNames = UserUtils.processUsers(
      users,
      filter: (user) => user.isActive,
      transform: (user) => user.displayName,
    );
    print('\nActive user names: $userNames');

    final newUsers = users.newUsers;
    print('New users: ${newUsers.map((u) => u.displayName).toList()}');

    // Test event handling
    final eventHandler = UserEventHandler();
    final events = [
      UserCreated(users[0]),
      UserStatusChanged(users[1], UserStatus.active, UserStatus.pending),
      UserUpdated(users[2], {'email': 'newemail@example.com'}),
      UserDeleted('4'),
    ];

    print('\nEvent Processing:');
    for (final event in events) {
      eventHandler.handleEvent(event);
    }

    // Test validation and error handling
    try {
      final invalidUser = User(id: '', name: 'Invalid User', email: 'invalid-email');
      print('This should not print: $invalidUser');
    } catch (e) {
      print('\nExpected validation error: $e');
    }

    // Test metadata operations
    final userWithMetadata = users[0];
    userWithMetadata.addMetadata('last_login', DateTime.now().toIso8601String());
    userWithMetadata.addMetadata('preferences', 'dark_theme');

    print('\nUser metadata:');
    print('Last login: ${userWithMetadata.getMetadata('last_login')}');
    print('Preferences: ${userWithMetadata.getMetadata('preferences')}');

    // Test stream operations
    final userStream = Stream.fromIterable(users);
    final activeUserStream = userStream.where((user) => user.isActive);

    print('\nStreaming active users:');
    await for (final user in activeUserStream) {
      print('- ${user.displayName}');
    }

  } catch (e, stackTrace) {
    print('Error: $e');
    print('Stack trace: $stackTrace');
  } finally {
    manager.dispose();
  }

  print('\nDart syntax highlighting test completed!');
}
