// Rust Test File for Theme Validation
use std::collections::HashMap;
use std::fmt;
use std::sync::Arc;
use tokio::sync::RwLock;
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};
use anyhow::{Context, Result};
use thiserror::Error;

// Custom error types
#[derive(Error, Debug)]
pub enum UserError {
    #[error("User not found: {id}")]
    NotFound { id: String },
    #[error("Invalid email format: {email}")]
    InvalidEmail { email: String },
    #[error("API request failed: {message}")]
    ApiError { message: String },
    #[error("Database error")]
    DatabaseError(#[from] sqlx::Error),
}

// User status enumeration
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum UserStatus {
    Active,
    Inactive,
    Pending,
    Suspended,
}

impl fmt::Display for UserStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            UserStatus::Active => write!(f, "Active"),
            UserStatus::Inactive => write!(f, "Inactive"),
            UserStatus::Pending => write!(f, "Pending"),
            UserStatus::Suspended => write!(f, "Suspended"),
        }
    }
}

impl UserStatus {
    pub fn is_valid(&self) -> bool {
        matches!(self, UserStatus::Active | UserStatus::Inactive | UserStatus::Pending)
    }
}

// User data structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: String,
    pub name: String,
    pub email: String,
    pub status: UserStatus,
    pub created_at: DateTime<Utc>,
    pub metadata: HashMap<String, serde_json::Value>,
}

impl User {
    pub fn new(id: String, name: String, email: String) -> Result<Self> {
        if !Self::is_valid_email(&email) {
            return Err(UserError::InvalidEmail { email }.into());
        }

        Ok(User {
            id,
            name,
            email,
            status: UserStatus::Active,
            created_at: Utc::now(),
            metadata: HashMap::new(),
        })
    }

    pub fn is_active(&self) -> bool {
        self.status == UserStatus::Active
    }

    pub fn display_name(&self) -> &str {
        if !self.name.is_empty() {
            &self.name
        } else {
            &self.email
        }
    }

    pub fn days_active(&self) -> i64 {
        (Utc::now() - self.created_at).num_days()
    }

    fn is_valid_email(email: &str) -> bool {
        email.contains('@') && email.contains('.')
    }

    pub fn with_status(mut self, status: UserStatus) -> Self {
        self.status = status;
        self
    }

    pub fn add_metadata(&mut self, key: String, value: serde_json::Value) {
        self.metadata.insert(key, value);
    }
}

impl fmt::Display for User {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "User(id={}, name={}, email={}, status={})",
            self.id, self.name, self.email, self.status
        )
    }
}

// API Response wrapper
#[derive(Debug, Serialize, Deserialize)]
pub struct ApiResponse<T> {
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<String>,
    pub timestamp: DateTime<Utc>,
}

impl<T> ApiResponse<T> {
    pub fn success(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
            timestamp: Utc::now(),
        }
    }

    pub fn error(message: String) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(message),
            timestamp: Utc::now(),
        }
    }
}

// User manager with async operations
#[derive(Debug)]
pub struct UserManager {
    cache: Arc<RwLock<HashMap<String, User>>>,
    base_url: String,
    client: reqwest::Client,
}

impl UserManager {
    const MAX_RETRIES: u32 = 3;
    const TIMEOUT_SECS: u64 = 5;

    pub fn new(base_url: String) -> Self {
        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(Self::TIMEOUT_SECS))
            .build()
            .expect("Failed to create HTTP client");

        Self {
            cache: Arc::new(RwLock::new(HashMap::new())),
            base_url,
            client,
        }
    }

    /// Fetch user by ID with caching
    pub async fn fetch_user(&self, user_id: &str) -> Result<Option<User>> {
        if user_id.is_empty() {
            return Err(UserError::NotFound {
                id: user_id.to_string(),
            }
            .into());
        }

        // Check cache first
        {
            let cache = self.cache.read().await;
            if let Some(user) = cache.get(user_id) {
                log::info!("User {} found in cache", user_id);
                return Ok(Some(user.clone()));
            }
        }

        // Fetch from API
        let url = format!("{}/users/{}", self.base_url, user_id);
        let response = self
            .client
            .get(&url)
            .send()
            .await
            .context("Failed to send request")?;

        if !response.status().is_success() {
            log::warn!("Failed to fetch user {}: {}", user_id, response.status());
            return Ok(None);
        }

        let api_response: ApiResponse<User> = response
            .json()
            .await
            .context("Failed to parse JSON response")?;

        if api_response.success {
            if let Some(user) = api_response.data {
                // Cache the result
                let mut cache = self.cache.write().await;
                cache.insert(user_id.to_string(), user.clone());
                log::info!("User {} fetched and cached successfully", user_id);
                Ok(Some(user))
            } else {
                Ok(None)
            }
        } else {
            Err(UserError::ApiError {
                message: api_response.error.unwrap_or_else(|| "Unknown error".to_string()),
            }
            .into())
        }
    }

    /// Batch fetch multiple users concurrently
    pub async fn batch_fetch_users(&self, user_ids: &[String]) -> HashMap<String, Option<User>> {
        let futures = user_ids
            .iter()
            .map(|id| async move {
                let result = self.fetch_user(id).await.unwrap_or(None);
                (id.clone(), result)
            });

        let results = futures::future::join_all(futures).await;
        results.into_iter().collect()
    }

    /// Update user information
    pub async fn update_user(
        &self,
        user_id: &str,
        updates: HashMap<String, serde_json::Value>,
    ) -> Result<bool> {
        let url = format!("{}/users/{}", self.base_url, user_id);

        let response = self
            .client
            .put(&url)
            .json(&updates)
            .send()
            .await
            .context("Failed to send update request")?;

        if response.status().is_success() {
            // Invalidate cache
            let mut cache = self.cache.write().await;
            cache.remove(user_id);
            log::info!("User {} updated successfully", user_id);
            Ok(true)
        } else {
            log::error!("Failed to update user {}: {}", user_id, response.status());
            Ok(false)
        }
    }

    /// Filter users by status
    pub fn filter_users_by_status(users: &[User], status: UserStatus) -> Vec<&User> {
        users
            .iter()
            .filter(|user| user.status == status)
            .collect()
    }

    /// Get user statistics
    pub fn get_user_statistics(users: &[User]) -> UserStatistics {
        let total = users.len();
        let mut active = 0;
        let mut inactive = 0;
        let mut pending = 0;
        let mut suspended = 0;

        for user in users {
            match user.status {
                UserStatus::Active => active += 1,
                UserStatus::Inactive => inactive += 1,
                UserStatus::Pending => pending += 1,
                UserStatus::Suspended => suspended += 1,
            }
        }

        let average_days_active = if !users.is_empty() {
            users.iter().map(|u| u.days_active()).sum::<i64>() as f64 / users.len() as f64
        } else {
            0.0
        };

        UserStatistics {
            total,
            active,
            inactive,
            pending,
            suspended,
            average_days_active,
        }
    }

    /// Clear cache and return number of entries cleared
    pub async fn clear_cache(&self) -> usize {
        let mut cache = self.cache.write().await;
        let count = cache.len();
        cache.clear();
        log::info!("Cache cleared: {} entries removed", count);
        count
    }

    /// Export users to JSON
    pub fn export_users_json(users: &[User]) -> Result<String> {
        serde_json::to_string_pretty(users).context("Failed to serialize users to JSON")
    }

    /// Create user from JSON
    pub fn create_user_from_json(json: &str) -> Result<User> {
        serde_json::from_str(json).context("Failed to deserialize user from JSON")
    }
}

// User statistics structure
#[derive(Debug, Clone, Serialize)]
pub struct UserStatistics {
    pub total: usize,
    pub active: usize,
    pub inactive: usize,
    pub pending: usize,
    pub suspended: usize,
    pub average_days_active: f64,
}

impl fmt::Display for UserStatistics {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "UserStats(total={}, active={}, inactive={}, pending={}, suspended={}, avg_days={:.2})",
            self.total, self.active, self.inactive, self.pending, self.suspended, self.average_days_active
        )
    }
}

// Trait for user operations
pub trait UserOperations {
    fn validate(&self) -> Result<()>;
    fn get_age_category(&self) -> String;
}

impl UserOperations for User {
    fn validate(&self) -> Result<()> {
        if self.id.is_empty() {
            return Err(anyhow::anyhow!("User ID cannot be empty"));
        }
        if self.name.is_empty() {
            return Err(anyhow::anyhow!("User name cannot be empty"));
        }
        if !Self::is_valid_email(&self.email) {
            return Err(UserError::InvalidEmail {
                email: self.email.clone(),
            }
            .into());
        }
        Ok(())
    }

    fn get_age_category(&self) -> String {
        let days = self.days_active();
        match days {
            0..=30 => "New".to_string(),
            31..=365 => "Regular".to_string(),
            _ => "Veteran".to_string(),
        }
    }
}

// Macro for creating users
macro_rules! create_user {
    ($id:expr, $name:expr, $email:expr) => {
        User::new($id.to_string(), $name.to_string(), $email.to_string())
    };
    ($id:expr, $name:expr, $email:expr, $status:expr) => {
        User::new($id.to_string(), $name.to_string(), $email.to_string())
            .map(|u| u.with_status($status))
    };
}

// Example usage and tests
#[tokio::main]
async fn main() -> Result<()> {
    env_logger::init();

    // Create sample users
    let users = vec![
        create_user!("1", "John Doe", "john@example.com")?,
        create_user!("2", "Jane Smith", "jane@example.com", UserStatus::Pending)?,
        create_user!("3", "Bob Johnson", "bob@example.com", UserStatus::Inactive)?,
    ];

    let manager = UserManager::new("https://api.example.com".to_string());

    // Test filtering
    let active_users = UserManager::filter_users_by_status(&users, UserStatus::Active);
    println!("Active users: {}", active_users.len());

    // Test statistics
    let stats = UserManager::get_user_statistics(&users);
    println!("User Statistics: {}", stats);

    // Test validation
    for user in &users {
        match user.validate() {
            Ok(()) => println!("✓ User {} is valid", user.display_name()),
            Err(e) => println!("✗ User {} is invalid: {}", user.display_name(), e),
        }
    }

    // Test export
    let json = UserManager::export_users_json(&users)?;
    println!("JSON Export:\n{}", json);

    // Test async operations (would work with real API)
    /*
    let user_ids = users.iter().map(|u| u.id.clone()).collect::<Vec<_>>();
    let batch_results = manager.batch_fetch_users(&user_ids).await;
    println!("Batch fetch completed: {} results", batch_results.len());
    */

    // Test pattern matching
    for user in &users {
        let message = match user.status {
            UserStatus::Active => format!("{} is currently active", user.display_name()),
            UserStatus::Pending => format!("{} is awaiting approval", user.display_name()),
            UserStatus::Inactive => format!("{} is not active", user.display_name()),
            UserStatus::Suspended => format!("{} has been suspended", user.display_name()),
        };
        println!("{}", message);
    }

    Ok(())
}

// Unit tests
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_user_creation() {
        let user = User::new(
            "1".to_string(),
            "Test User".to_string(),
            "test@example.com".to_string(),
        )
        .unwrap();

        assert_eq!(user.id, "1");
        assert_eq!(user.name, "Test User");
        assert_eq!(user.email, "test@example.com");
        assert_eq!(user.status, UserStatus::Active);
        assert!(user.is_active());
    }

    #[test]
    fn test_invalid_email() {
        let result = User::new(
            "1".to_string(),
            "Test User".to_string(),
            "invalid-email".to_string(),
        );

        assert!(result.is_err());
    }

    #[test]
    fn test_user_statistics() {
        let users = vec![
            create_user!("1", "User 1", "user1@example.com").unwrap(),
            create_user!("2", "User 2", "user2@example.com", UserStatus::Pending).unwrap(),
            create_user!("3", "User 3", "user3@example.com", UserStatus::Inactive).unwrap(),
        ];

        let stats = UserManager::get_user_statistics(&users);
        assert_eq!(stats.total, 3);
        assert_eq!(stats.active, 1);
        assert_eq!(stats.pending, 1);
        assert_eq!(stats.inactive, 1);
    }

    #[tokio::test]
    async fn test_cache_operations() {
        let manager = UserManager::new("https://test.com".to_string());

        // Test empty cache
        let count = manager.clear_cache().await;
        assert_eq!(count, 0);
    }
}
