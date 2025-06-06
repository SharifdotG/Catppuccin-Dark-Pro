// Go Test File for Theme Validation
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"regexp"
	"sync"
	"time"
)

// Constants
const (
	MaxRetries     = 3
	TimeoutSeconds = 5
	BaseURL        = "https://api.example.com"
)

// Supported formats
var SupportedFormats = []string{"json", "xml", "csv"}

// Custom error types
var (
	ErrUserNotFound   = errors.New("user not found")
	ErrInvalidEmail   = errors.New("invalid email format")
	ErrAPIError       = errors.New("API request failed")
	ErrEmptyUserID    = errors.New("user ID cannot be empty")
	ErrEmptyUserName  = errors.New("user name cannot be empty")
)

// UserStatus represents the status of a user
type UserStatus int

const (
	StatusActive UserStatus = iota
	StatusInactive
	StatusPending
	StatusSuspended
)

// String implements the Stringer interface
func (s UserStatus) String() string {
	switch s {
	case StatusActive:
		return "active"
	case StatusInactive:
		return "inactive"
	case StatusPending:
		return "pending"
	case StatusSuspended:
		return "suspended"
	default:
		return "unknown"
	}
}

// MarshalJSON implements the json.Marshaler interface
func (s UserStatus) MarshalJSON() ([]byte, error) {
	return json.Marshal(s.String())
}

// UnmarshalJSON implements the json.Unmarshaler interface
func (s *UserStatus) UnmarshalJSON(data []byte) error {
	var str string
	if err := json.Unmarshal(data, &str); err != nil {
		return err
	}

	switch str {
	case "active":
		*s = StatusActive
	case "inactive":
		*s = StatusInactive
	case "pending":
		*s = StatusPending
	case "suspended":
		*s = StatusSuspended
	default:
		return fmt.Errorf("invalid user status: %s", str)
	}

	return nil
}

// IsValid checks if the status is valid
func (s UserStatus) IsValid() bool {
	return s >= StatusActive && s <= StatusSuspended
}

// User represents a user in the system
type User struct {
	ID        string                 `json:"id"`
	Name      string                 `json:"name"`
	Email     string                 `json:"email"`
	Status    UserStatus             `json:"status"`
	CreatedAt time.Time              `json:"created_at"`
	Metadata  map[string]interface{} `json:"metadata"`
	mu        sync.RWMutex           `json:"-"`
}

// NewUser creates a new user with validation
func NewUser(id, name, email string) (*User, error) {
	if id == "" {
		return nil, ErrEmptyUserID
	}
	if name == "" {
		return nil, ErrEmptyUserName
	}
	if !isValidEmail(email) {
		return nil, fmt.Errorf("%w: %s", ErrInvalidEmail, email)
	}

	return &User{
		ID:        id,
		Name:      name,
		Email:     email,
		Status:    StatusActive,
		CreatedAt: time.Now().UTC(),
		Metadata:  make(map[string]interface{}),
	}, nil
}

// IsActive checks if the user is active
func (u *User) IsActive() bool {
	u.mu.RLock()
	defer u.mu.RUnlock()
	return u.Status == StatusActive
}

// DisplayName returns the display name for the user
func (u *User) DisplayName() string {
	u.mu.RLock()
	defer u.mu.RUnlock()
	if u.Name != "" {
		return u.Name
	}
	return u.Email
}

// DaysActive returns the number of days the user has been active
func (u *User) DaysActive() int {
	u.mu.RLock()
	defer u.mu.RUnlock()
	return int(time.Since(u.CreatedAt).Hours() / 24)
}

// SetStatus sets the user status safely
func (u *User) SetStatus(status UserStatus) {
	u.mu.Lock()
	defer u.mu.Unlock()
	u.Status = status
}

// AddMetadata adds metadata to the user safely
func (u *User) AddMetadata(key string, value interface{}) {
	u.mu.Lock()
	defer u.mu.Unlock()
	u.Metadata[key] = value
}

// GetMetadata gets metadata from the user safely
func (u *User) GetMetadata(key string) (interface{}, bool) {
	u.mu.RLock()
	defer u.mu.RUnlock()
	value, exists := u.Metadata[key]
	return value, exists
}

// String implements the Stringer interface
func (u *User) String() string {
	u.mu.RLock()
	defer u.mu.RUnlock()
	return fmt.Sprintf("User(id=%s, name=%s, email=%s, status=%s)", u.ID, u.Name, u.Email, u.Status)
}

// Validate validates the user data
func (u *User) Validate() error {
	u.mu.RLock()
	defer u.mu.RUnlock()

	if u.ID == "" {
		return ErrEmptyUserID
	}
	if u.Name == "" {
		return ErrEmptyUserName
	}
	if !isValidEmail(u.Email) {
		return fmt.Errorf("%w: %s", ErrInvalidEmail, u.Email)
	}
	if !u.Status.IsValid() {
		return fmt.Errorf("invalid user status: %d", u.Status)
	}

	return nil
}

// ApiResponse represents a generic API response
type ApiResponse[T any] struct {
	Success   bool      `json:"success"`
	Data      *T        `json:"data,omitempty"`
	Error     *string   `json:"error,omitempty"`
	Timestamp time.Time `json:"timestamp"`
}

// NewSuccessResponse creates a successful API response
func NewSuccessResponse[T any](data T) *ApiResponse[T] {
	return &ApiResponse[T]{
		Success:   true,
		Data:      &data,
		Timestamp: time.Now().UTC(),
	}
}

// NewErrorResponse creates an error API response
func NewErrorResponse[T any](errMsg string) *ApiResponse[T] {
	return &ApiResponse[T]{
		Success:   false,
		Error:     &errMsg,
		Timestamp: time.Now().UTC(),
	}
}

// UserManager manages user operations
type UserManager struct {
	cache      sync.Map
	baseURL    string
	client     *http.Client
	timeout    time.Duration
	maxRetries int
}

// NewUserManager creates a new user manager
func NewUserManager(baseURL string) *UserManager {
	return &UserManager{
		baseURL: baseURL,
		client: &http.Client{
			Timeout: TimeoutSeconds * time.Second,
		},
		timeout:    TimeoutSeconds * time.Second,
		maxRetries: MaxRetries,
	}
}

// FetchUser fetches a user by ID with caching
func (um *UserManager) FetchUser(ctx context.Context, userID string) (*User, error) {
	if userID == "" {
		return nil, ErrEmptyUserID
	}

	// Check cache first
	if cached, ok := um.cache.Load(userID); ok {
		log.Printf("User %s found in cache", userID)
		return cached.(*User), nil
	}

	// Fetch from API
	url := fmt.Sprintf("%s/users/%s", um.baseURL, userID)
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "Go-UserManager/1.0")

	resp, err := um.client.Do(req)
	if err != nil {
		log.Printf("Failed to fetch user %s: %v", userID, err)
		return nil, fmt.Errorf("%w: %v", ErrAPIError, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Printf("Failed to fetch user %s: status %d", userID, resp.StatusCode)
		return nil, fmt.Errorf("%w: status %d", ErrAPIError, resp.StatusCode)
	}

	var apiResp ApiResponse[User]
	if err := json.NewDecoder(resp.Body).Decode(&apiResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	if !apiResp.Success {
		errMsg := "unknown error"
		if apiResp.Error != nil {
			errMsg = *apiResp.Error
		}
		return nil, fmt.Errorf("%w: %s", ErrAPIError, errMsg)
	}

	if apiResp.Data == nil {
		return nil, ErrUserNotFound
	}

	// Cache the result
	um.cache.Store(userID, apiResp.Data)
	log.Printf("User %s fetched and cached successfully", userID)

	return apiResp.Data, nil
}

// BatchFetchUsers fetches multiple users concurrently
func (um *UserManager) BatchFetchUsers(ctx context.Context, userIDs []string) map[string]*User {
	results := make(map[string]*User)
	var mu sync.Mutex
	var wg sync.WaitGroup

	// Create a semaphore to limit concurrent requests
	semaphore := make(chan struct{}, 10)

	for _, userID := range userIDs {
		wg.Add(1)
		go func(id string) {
			defer wg.Done()
			semaphore <- struct{}{} // Acquire
			defer func() { <-semaphore }() // Release

			user, err := um.FetchUser(ctx, id)

			mu.Lock()
			if err != nil {
				log.Printf("Error fetching user %s: %v", id, err)
				results[id] = nil
			} else {
				results[id] = user
			}
			mu.Unlock()
		}(userID)
	}

	wg.Wait()
	return results
}

// UpdateUser updates a user's information
func (um *UserManager) UpdateUser(ctx context.Context, userID string, updates map[string]interface{}) error {
	url := fmt.Sprintf("%s/users/%s", um.baseURL, userID)

	data, err := json.Marshal(updates)
	if err != nil {
		return fmt.Errorf("failed to marshal updates: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "PUT", url,
		bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := um.client.Do(req)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrAPIError, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%w: status %d", ErrAPIError, resp.StatusCode)
	}

	// Invalidate cache
	um.cache.Delete(userID)
	log.Printf("User %s updated successfully", userID)

	return nil
}

// FilterUsersByStatus filters users by status
func (um *UserManager) FilterUsersByStatus(users []*User, status UserStatus) []*User {
	var filtered []*User
	for _, user := range users {
		if user.Status == status {
			filtered = append(filtered, user)
		}
	}
	return filtered
}

// UserStatistics represents user statistics
type UserStatistics struct {
	Total              int     `json:"total"`
	Active             int     `json:"active"`
	Inactive           int     `json:"inactive"`
	Pending            int     `json:"pending"`
	Suspended          int     `json:"suspended"`
	AverageDaysActive  float64 `json:"average_days_active"`
}

// GetUserStatistics calculates user statistics
func (um *UserManager) GetUserStatistics(users []*User) UserStatistics {
	stats := UserStatistics{
		Total: len(users),
	}

	if len(users) == 0 {
		return stats
	}

	totalDays := 0
	for _, user := range users {
		switch user.Status {
		case StatusActive:
			stats.Active++
		case StatusInactive:
			stats.Inactive++
		case StatusPending:
			stats.Pending++
		case StatusSuspended:
			stats.Suspended++
		}
		totalDays += user.DaysActive()
	}

	stats.AverageDaysActive = float64(totalDays) / float64(len(users))
	return stats
}

// ClearCache clears the user cache and returns the number of entries cleared
func (um *UserManager) ClearCache() int {
	count := 0
	um.cache.Range(func(key, value interface{}) bool {
		um.cache.Delete(key)
		count++
		return true
	})
	log.Printf("Cache cleared: %d entries removed", count)
	return count
}

// ExportUsersJSON exports users to JSON format
func (um *UserManager) ExportUsersJSON(users []*User) (string, error) {
	data, err := json.MarshalIndent(users, "", "  ")
	if err != nil {
		return "", fmt.Errorf("failed to marshal users: %w", err)
	}
	return string(data), nil
}

// Helper functions

// isValidEmail validates email format using regex
func isValidEmail(email string) bool {
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	return emailRegex.MatchString(email)
}

// UserOperations interface defines user operations
type UserOperations interface {
	Validate() error
	GetAgeCategory() string
	IsExpired() bool
}

// GetAgeCategory returns the age category of the user
func (u *User) GetAgeCategory() string {
	days := u.DaysActive()
	switch {
	case days <= 30:
		return "New"
	case days <= 365:
		return "Regular"
	default:
		return "Veteran"
	}
}

// IsExpired checks if the user account is expired (example logic)
func (u *User) IsExpired() bool {
	return u.DaysActive() > 365 && u.Status == StatusInactive
}

// Example usage and main function
func main() {
	// Create sample users
	users := []*User{}

	user1, err := NewUser("1", "John Doe", "john@example.com")
	if err != nil {
		log.Fatalf("Failed to create user: %v", err)
	}
	users = append(users, user1)

	user2, err := NewUser("2", "Jane Smith", "jane@example.com")
	if err != nil {
		log.Fatalf("Failed to create user: %v", err)
	}
	user2.SetStatus(StatusPending)
	users = append(users, user2)

	user3, err := NewUser("3", "Bob Johnson", "bob@example.com")
	if err != nil {
		log.Fatalf("Failed to create user: %v", err)
	}
	user3.SetStatus(StatusInactive)
	users = append(users, user3)

	manager := NewUserManager(BaseURL)

	// Test filtering
	activeUsers := manager.FilterUsersByStatus(users, StatusActive)
	fmt.Printf("Active users: %d\n", len(activeUsers))

	// Test statistics
	stats := manager.GetUserStatistics(users)
	fmt.Printf("User Statistics: Total=%d, Active=%d, Average Days=%.2f\n",
		stats.Total, stats.Active, stats.AverageDaysActive)

	// Test validation
	for _, user := range users {
		if err := user.Validate(); err != nil {
			fmt.Printf("✗ User %s is invalid: %v\n", user.DisplayName(), err)
		} else {
			fmt.Printf("✓ User %s is valid\n", user.DisplayName())
		}
	}

	// Test export
	jsonData, err := manager.ExportUsersJSON(users)
	if err != nil {
		log.Printf("Failed to export users: %v", err)
	} else {
		fmt.Printf("JSON Export:\n%s\n", jsonData)
	}

	// Test concurrent operations with context
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	userIDs := []string{"1", "2", "3", "nonexistent"}
	batchResults := manager.BatchFetchUsers(ctx, userIDs)
	fmt.Printf("Batch fetch completed: %d results\n", len(batchResults))

	// Test pattern matching with switch
	for _, user := range users {
		var message string
		switch user.Status {
		case StatusActive:
			message = fmt.Sprintf("%s is currently active", user.DisplayName())
		case StatusPending:
			message = fmt.Sprintf("%s is awaiting approval", user.DisplayName())
		case StatusInactive:
			message = fmt.Sprintf("%s is not active", user.DisplayName())
		case StatusSuspended:
			message = fmt.Sprintf("%s has been suspended", user.DisplayName())
		default:
			message = fmt.Sprintf("%s has unknown status", user.DisplayName())
		}
		fmt.Println(message)
	}

	// Demonstrate error handling
	_, err = NewUser("", "Invalid User", "invalid@example.com")
	if err != nil {
		fmt.Printf("Expected error: %v\n", err)
	}

	// Test metadata operations
	user1.AddMetadata("last_login", time.Now())
	user1.AddMetadata("preferences", map[string]interface{}{
		"theme": "dark",
		"language": "en",
	})

	if lastLogin, exists := user1.GetMetadata("last_login"); exists {
		fmt.Printf("User %s last login: %v\n", user1.DisplayName(), lastLogin)
	}
}
