# Python Test File for Theme Validation
from typing import List, Dict, Optional, Union, Any
from dataclasses import dataclass, field
from enum import Enum
import asyncio
import json
import logging
from datetime import datetime, timedelta
import re

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Enums and constants
class UserStatus(Enum):
    """User status enumeration"""
    ACTIVE = "active"
    INACTIVE = "inactive"
    PENDING = "pending"
    SUSPENDED = "suspended"

API_BASE_URL: str = "https://api.example.com"
RETRY_ATTEMPTS: int = 3
TIMEOUT_SECONDS: float = 5.0

# Dataclasses
@dataclass
class User:
    """User data model"""
    id: str
    name: str
    email: str
    status: UserStatus = UserStatus.ACTIVE
    created_at: datetime = field(default_factory=datetime.now)
    metadata: Dict[str, Any] = field(default_factory=dict)

    def __post_init__(self):
        """Validate user data after initialization"""
        if not self.is_valid_email(self.email):
            raise ValueError(f"Invalid email format: {self.email}")

    @staticmethod
    def is_valid_email(email: str) -> bool:
        """Validate email format using regex"""
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return re.match(pattern, email) is not None

    @property
    def is_active(self) -> bool:
        """Check if user is active"""
        return self.status == UserStatus.ACTIVE

    def to_dict(self) -> Dict[str, Any]:
        """Convert user to dictionary"""
        return {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'status': self.status.value,
            'created_at': self.created_at.isoformat(),
            'metadata': self.metadata
        }

@dataclass
class ApiResponse:
    """Generic API response wrapper"""
    success: bool
    data: Optional[Any] = None
    error: Optional[str] = None
    timestamp: datetime = field(default_factory=datetime.now)

# Main class with async methods
class UserManager:
    """Asynchronous user management class"""

    def __init__(self, base_url: str = API_BASE_URL, timeout: float = TIMEOUT_SECONDS):
        self.base_url = base_url
        self.timeout = timeout
        self._cache: Dict[str, User] = {}
        self._session = None  # Would be aiohttp session in real implementation

    async def fetch_user(self, user_id: str) -> Optional[User]:
        """
        Fetch user by ID with caching

        Args:
            user_id: The user ID to fetch

        Returns:
            User object if found, None otherwise

        Raises:
            ValueError: If user_id is invalid
            ConnectionError: If API is unreachable
        """
        if not user_id or not isinstance(user_id, str):
            raise ValueError("User ID must be a non-empty string")

        # Check cache first
        if user_id in self._cache:
            logger.info(f"Cache hit for user: {user_id}")
            return self._cache[user_id]

        try:
            # Simulate API call
            await asyncio.sleep(0.1)  # Simulate network delay

            # Mock user data
            user_data = {
                'id': user_id,
                'name': f'User {user_id}',
                'email': f'user{user_id}@example.com',
                'status': UserStatus.ACTIVE.value,
                'metadata': {'last_login': datetime.now().isoformat()}
            }

            user = User(
                id=user_data['id'],
                name=user_data['name'],
                email=user_data['email'],
                status=UserStatus(user_data['status']),
                metadata=user_data['metadata']
            )

            # Cache the result
            self._cache[user_id] = user
            logger.info(f"Fetched and cached user: {user_id}")

            return user

        except Exception as e:
            logger.error(f"Failed to fetch user {user_id}: {str(e)}")
            raise ConnectionError(f"API error: {str(e)}")

    async def batch_fetch_users(self, user_ids: List[str]) -> Dict[str, Optional[User]]:
        """
        Fetch multiple users concurrently

        Args:
            user_ids: List of user IDs to fetch

        Returns:
            Dictionary mapping user IDs to User objects
        """
        tasks = [self.fetch_user(user_id) for user_id in user_ids]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        return {
            user_id: result if not isinstance(result, Exception) else None
            for user_id, result in zip(user_ids, results)
        }

    async def update_user(self, user_id: str, updates: Dict[str, Any]) -> bool:
        """
        Update user information

        Args:
            user_id: User ID to update
            updates: Dictionary of fields to update

        Returns:
            True if successful, False otherwise
        """
        try:
            user = await self.fetch_user(user_id)
            if not user:
                return False

            # Apply updates
            for field, value in updates.items():
                if hasattr(user, field):
                    setattr(user, field, value)

            # Update cache
            self._cache[user_id] = user
            logger.info(f"Updated user {user_id}: {updates}")

            return True

        except Exception as e:
            logger.error(f"Failed to update user {user_id}: {str(e)}")
            return False

    def clear_cache(self) -> int:
        """Clear user cache and return number of items cleared"""
        count = len(self._cache)
        self._cache.clear()
        logger.info(f"Cleared {count} items from cache")
        return count

# Utility functions
def create_user_from_dict(data: Dict[str, Any]) -> User:
    """Create User object from dictionary"""
    return User(
        id=data['id'],
        name=data['name'],
        email=data['email'],
        status=UserStatus(data.get('status', UserStatus.ACTIVE.value)),
        metadata=data.get('metadata', {})
    )

def filter_users_by_status(users: List[User], status: UserStatus) -> List[User]:
    """Filter users by status"""
    return [user for user in users if user.status == status]

def serialize_users(users: List[User]) -> str:
    """Serialize users to JSON string"""
    user_dicts = [user.to_dict() for user in users]
    return json.dumps(user_dicts, indent=2, default=str)

# Decorators and context managers
def log_execution_time(func):
    """Decorator to log function execution time"""
    async def wrapper(*args, **kwargs):
        start_time = datetime.now()
        try:
            result = await func(*args, **kwargs)
            execution_time = datetime.now() - start_time
            logger.info(f"{func.__name__} executed in {execution_time.total_seconds():.2f}s")
            return result
        except Exception as e:
            execution_time = datetime.now() - start_time
            logger.error(f"{func.__name__} failed after {execution_time.total_seconds():.2f}s: {str(e)}")
            raise
    return wrapper

class DatabaseConnection:
    """Context manager for database connections"""

    def __init__(self, connection_string: str):
        self.connection_string = connection_string
        self.connection = None

    async def __aenter__(self):
        logger.info(f"Connecting to database: {self.connection_string}")
        # Simulate connection
        await asyncio.sleep(0.1)
        self.connection = "mock_connection"
        return self.connection

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        logger.info("Closing database connection")
        self.connection = None

# Main execution example
async def main():
    """Main function demonstrating the user management system"""
    manager = UserManager()

    try:
        # Test single user fetch
        user = await manager.fetch_user("123")
        if user:
            print(f"Fetched user: {user.name} ({user.email})")

        # Test batch fetch
        user_ids = ["123", "456", "789"]
        users = await manager.batch_fetch_users(user_ids)
        active_users = [u for u in users.values() if u and u.is_active]

        print(f"Fetched {len(active_users)} active users")

        # Test update
        update_success = await manager.update_user("123", {"name": "Updated User"})
        print(f"Update successful: {update_success}")

        # Clear cache
        cleared_count = manager.clear_cache()
        print(f"Cleared {cleared_count} items from cache")

    except Exception as e:
        logger.error(f"Main execution failed: {str(e)}")

# Run the example
if __name__ == "__main__":
    asyncio.run(main())
