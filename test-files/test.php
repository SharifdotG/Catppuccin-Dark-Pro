<?php
declare(strict_types=1);

namespace ThemeTest\Models;

use DateTime;
use Exception;
use InvalidArgumentException;
use JsonSerializable;

/**
 * User status enumeration
 */
enum UserStatus: string
{
    case ACTIVE = 'active';
    case INACTIVE = 'inactive';
    case PENDING = 'pending';
    case SUSPENDED = 'suspended';

    public function getDisplayName(): string
    {
        return match ($this) {
            self::ACTIVE => 'Active',
            self::INACTIVE => 'Inactive',
            self::PENDING => 'Pending',
            self::SUSPENDED => 'Suspended',
        };
    }

    public function isValid(): bool
    {
        return in_array($this, [self::ACTIVE, self::INACTIVE, self::PENDING]);
    }
}

/**
 * User data model with properties and validation
 */
class User implements JsonSerializable
{
    private string $id;
    private string $name;
    private string $email;
    private UserStatus $status;
    private DateTime $createdAt;
    private array $metadata;

    public function __construct(
        string $id,
        string $name,
        string $email,
        UserStatus $status = UserStatus::ACTIVE,
        ?DateTime $createdAt = null,
        array $metadata = []
    ) {
        $this->setId($id);
        $this->setName($name);
        $this->setEmail($email);
        $this->status = $status;
        $this->createdAt = $createdAt ?? new DateTime();
        $this->metadata = $metadata;
    }

    // Getters
    public function getId(): string
    {
        return $this->id;
    }

    public function getName(): string
    {
        return $this->name;
    }

    public function getEmail(): string
    {
        return $this->email;
    }

    public function getStatus(): UserStatus
    {
        return $this->status;
    }

    public function getCreatedAt(): DateTime
    {
        return $this->createdAt;
    }

    public function getMetadata(): array
    {
        return $this->metadata;
    }

    // Setters with validation
    public function setId(string $id): void
    {
        if (empty(trim($id))) {
            throw new InvalidArgumentException('User ID cannot be empty');
        }
        $this->id = $id;
    }

    public function setName(string $name): void
    {
        if (empty(trim($name))) {
            throw new InvalidArgumentException('Name cannot be empty');
        }
        $this->name = trim($name);
    }

    public function setEmail(string $email): void
    {
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException('Invalid email format');
        }
        $this->email = strtolower(trim($email));
    }

    public function setStatus(UserStatus $status): void
    {
        $this->status = $status;
    }

    public function setMetadata(array $metadata): void
    {
        $this->metadata = $metadata;
    }

    // Computed properties
    public function isActive(): bool
    {
        return $this->status === UserStatus::ACTIVE;
    }

    public function getDisplayName(): string
    {
        return !empty($this->name) ? $this->name : $this->email;
    }

    public function getDaysActive(): int
    {
        $now = new DateTime();
        $diff = $now->diff($this->createdAt);
        return $diff->days;
    }

    public function hasValidEmail(): bool
    {
        return filter_var($this->email, FILTER_VALIDATE_EMAIL) !== false;
    }

    // JsonSerializable implementation
    public function jsonSerialize(): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'status' => $this->status->value,
            'created_at' => $this->createdAt->format('Y-m-d H:i:s'),
            'metadata' => $this->metadata,
            'is_active' => $this->isActive(),
            'display_name' => $this->getDisplayName(),
        ];
    }

    public function toArray(): array
    {
        return $this->jsonSerialize();
    }

    public function __toString(): string
    {
        return json_encode($this->jsonSerialize());
    }
}

/**
 * API Response wrapper
 */
class ApiResponse implements JsonSerializable
{
    public function __construct(
        private bool $success,
        private mixed $data = null,
        private ?string $error = null,
        private ?DateTime $timestamp = null
    ) {
        $this->timestamp = $timestamp ?? new DateTime();
    }

    public function isSuccess(): bool
    {
        return $this->success;
    }

    public function getData(): mixed
    {
        return $this->data;
    }

    public function getError(): ?string
    {
        return $this->error;
    }

    public function getTimestamp(): DateTime
    {
        return $this->timestamp;
    }

    public function jsonSerialize(): array
    {
        return [
            'success' => $this->success,
            'data' => $this->data,
            'error' => $this->error,
            'timestamp' => $this->timestamp->format('Y-m-d H:i:s'),
        ];
    }
}

/**
 * User management service with CRUD operations
 */
class UserManager
{
    private const MAX_RETRIES = 3;
    private const TIMEOUT_SECONDS = 5;
    private const SUPPORTED_FORMATS = ['json', 'xml', 'csv'];

    private array $cache = [];
    private string $baseUrl;
    private int $timeout;

    public function __construct(string $baseUrl = 'https://api.example.com', int $timeout = self::TIMEOUT_SECONDS)
    {
        $this->baseUrl = rtrim($baseUrl, '/');
        $this->timeout = $timeout;
    }

    /**
     * Fetch user by ID with caching
     */
    public function fetchUser(string $userId): ?User
    {
        if (empty(trim($userId))) {
            throw new InvalidArgumentException('User ID cannot be empty');
        }

        // Check cache first
        if (isset($this->cache[$userId])) {
            error_log("User {$userId} found in cache");
            return $this->cache[$userId];
        }

        try {
            $url = "{$this->baseUrl}/users/{$userId}";
            $context = stream_context_create([
                'http' => [
                    'timeout' => $this->timeout,
                    'method' => 'GET',
                    'header' => [
                        'Content-Type: application/json',
                        'User-Agent: PHP-UserManager/1.0',
                    ],
                ],
            ]);

            $response = file_get_contents($url, false, $context);

            if ($response === false) {
                error_log("Failed to fetch user {$userId}");
                return null;
            }

            $data = json_decode($response, true);
            if (json_last_error() !== JSON_ERROR_NONE) {
                throw new Exception('Invalid JSON response');
            }

            if ($data['success'] && isset($data['data'])) {
                $user = $this->createUserFromArray($data['data']);
                $this->cache[$userId] = $user;
                return $user;
            }

            return null;
        } catch (Exception $e) {
            error_log("Error fetching user {$userId}: " . $e->getMessage());
            return null;
        }
    }

    /**
     * Batch fetch multiple users
     */
    public function batchFetchUsers(array $userIds): array
    {
        $results = [];
        $promises = [];

        foreach ($userIds as $userId) {
            if (isset($this->cache[$userId])) {
                $results[$userId] = $this->cache[$userId];
            } else {
                $promises[$userId] = $this->fetchUser($userId);
            }
        }

        // In a real implementation, this would use async/await or parallel processing
        foreach ($promises as $userId => $promise) {
            $results[$userId] = $promise;
        }

        return $results;
    }

    /**
     * Create user from array data
     */
    private function createUserFromArray(array $data): User
    {
        return new User(
            id: $data['id'],
            name: $data['name'],
            email: $data['email'],
            status: UserStatus::from($data['status'] ?? 'active'),
            createdAt: isset($data['created_at']) ? new DateTime($data['created_at']) : null,
            metadata: $data['metadata'] ?? []
        );
    }

    /**
     * Update user information
     */
    public function updateUser(string $userId, array $updates): bool
    {
        try {
            $user = $this->fetchUser($userId);
            if (!$user) {
                return false;
            }

            $url = "{$this->baseUrl}/users/{$userId}";
            $data = json_encode($updates);

            $context = stream_context_create([
                'http' => [
                    'method' => 'PUT',
                    'header' => [
                        'Content-Type: application/json',
                        'Content-Length: ' . strlen($data),
                    ],
                    'content' => $data,
                    'timeout' => $this->timeout,
                ],
            ]);

            $response = file_get_contents($url, false, $context);

            if ($response !== false) {
                // Update cache
                unset($this->cache[$userId]);
                return true;
            }

            return false;
        } catch (Exception $e) {
            error_log("Error updating user {$userId}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Filter users by status
     */
    public function filterUsersByStatus(array $users, UserStatus $status): array
    {
        return array_filter($users, fn(User $user) => $user->getStatus() === $status);
    }

    /**
     * Get user statistics
     */
    public function getUserStatistics(array $users): array
    {
        $stats = [
            'total' => count($users),
            'active' => 0,
            'inactive' => 0,
            'pending' => 0,
            'suspended' => 0,
        ];

        foreach ($users as $user) {
            match ($user->getStatus()) {
                UserStatus::ACTIVE => $stats['active']++,
                UserStatus::INACTIVE => $stats['inactive']++,
                UserStatus::PENDING => $stats['pending']++,
                UserStatus::SUSPENDED => $stats['suspended']++,
            };
        }

        $stats['average_days_active'] = $this->calculateAverageDaysActive($users);

        return $stats;
    }

    private function calculateAverageDaysActive(array $users): float
    {
        if (empty($users)) {
            return 0.0;
        }

        $totalDays = array_sum(array_map(fn(User $user) => $user->getDaysActive(), $users));

        return $totalDays / count($users);
    }

    /**
     * Clear cache
     */
    public function clearCache(): int
    {
        $count = count($this->cache);
        $this->cache = [];
        return $count;
    }

    /**
     * Export users to different formats
     */
    public function exportUsers(array $users, string $format = 'json'): string
    {
        if (!in_array($format, self::SUPPORTED_FORMATS)) {
            throw new InvalidArgumentException("Unsupported format: {$format}");
        }

        return match ($format) {
            'json' => json_encode(array_map(fn(User $user) => $user->toArray(), $users), JSON_PRETTY_PRINT),
            'csv' => $this->exportToCsv($users),
            'xml' => $this->exportToXml($users),
            default => throw new InvalidArgumentException("Unsupported format: {$format}"),
        };
    }

    private function exportToCsv(array $users): string
    {
        $output = "ID,Name,Email,Status,Created At\n";

        foreach ($users as $user) {
            $output .= sprintf(
                "%s,%s,%s,%s,%s\n",
                $user->getId(),
                $user->getName(),
                $user->getEmail(),
                $user->getStatus()->value,
                $user->getCreatedAt()->format('Y-m-d H:i:s')
            );
        }

        return $output;
    }

    private function exportToXml(array $users): string
    {
        $xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<users>\n";

        foreach ($users as $user) {
            $xml .= "  <user>\n";
            $xml .= "    <id>{$user->getId()}</id>\n";
            $xml .= "    <name>" . htmlspecialchars($user->getName()) . "</name>\n";
            $xml .= "    <email>{$user->getEmail()}</email>\n";
            $xml .= "    <status>{$user->getStatus()->value}</status>\n";
            $xml .= "    <created_at>{$user->getCreatedAt()->format('Y-m-d H:i:s')}</created_at>\n";
            $xml .= "  </user>\n";
        }

        $xml .= "</users>\n";

        return $xml;
    }
}

// Example usage and testing
if (php_sapi_name() === 'cli') {
    try {
        // Create sample users
        $users = [
            new User('1', 'John Doe', 'john@example.com', UserStatus::ACTIVE),
            new User('2', 'Jane Smith', 'jane@example.com', UserStatus::PENDING),
            new User('3', 'Bob Johnson', 'bob@example.com', UserStatus::INACTIVE),
        ];

        $manager = new UserManager();

        // Test filtering
        $activeUsers = $manager->filterUsersByStatus($users, UserStatus::ACTIVE);
        echo "Active users: " . count($activeUsers) . "\n";

        // Test statistics
        $stats = $manager->getUserStatistics($users);
        echo "User Statistics:\n";
        echo "Total: {$stats['total']}\n";
        echo "Active: {$stats['active']}\n";
        echo "Average days active: {$stats['average_days_active']}\n";

        // Test export
        echo "\nJSON Export:\n";
        echo $manager->exportUsers($users, 'json');

        echo "\nCSV Export:\n";
        echo $manager->exportUsers($users, 'csv');

    } catch (Exception $e) {
        echo "Error: " . $e->getMessage() . "\n";
    }
}
