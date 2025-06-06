// JavaScript Test File for Theme Validation
const API_BASE_URL = "https://api.example.com";
const RETRY_ATTEMPTS = 3;

/**
 * User management class with various JavaScript features
 */
class UserManager {
    constructor(config = {}) {
        this.apiUrl = config.apiUrl || API_BASE_URL;
        this.timeout = config.timeout || 5000;
        this.retries = config.retries || RETRY_ATTEMPTS;
        this.cache = new Map();
    }

    /**
     * Fetch user data from API
     * @param {string} userId - The user ID to fetch
     * @returns {Promise<Object>} User data
     */
    async fetchUser(userId) {
        try {
            // Check cache first
            if (this.cache.has(userId)) {
                console.log(`Cache hit for user: ${userId}`);
                return this.cache.get(userId);
            }

            const response = await fetch(`${this.apiUrl}/users/${userId}`, {
                method: "GET",
                headers: {
                    "Content-Type": "application/json",
                    Authorization: `Bearer ${this.getToken()}`,
                },
                timeout: this.timeout,
            });

            if (!response.ok) {
                throw new Error(
                    `HTTP ${response.status}: ${response.statusText}`
                );
            }

            const userData = await response.json();

            // Cache the result
            this.cache.set(userId, userData);

            return userData;
        } catch (error) {
            console.error("Failed to fetch user:", error);
            throw error;
        }
    }

    /**
     * Update user information
     * @param {string} userId - User ID
     * @param {Object} updates - Updates to apply
     */
    async updateUser(userId, updates) {
        const user = await this.fetchUser(userId);
        const updatedUser = { ...user, ...updates, updatedAt: new Date() };

        // Simulate API call
        await new Promise((resolve) => setTimeout(resolve, 1000));

        // Update cache
        this.cache.set(userId, updatedUser);

        return updatedUser;
    }

    /**
     * Get authentication token
     * @private
     */
    getToken() {
        return localStorage.getItem("authToken") || "default-token";
    }

    /**
     * Clear user cache
     */
    clearCache() {
        this.cache.clear();
        console.log("Cache cleared");
    }
}

// Object literals and arrays
const userStatuses = {
    ACTIVE: "active",
    INACTIVE: "inactive",
    PENDING: "pending",
    SUSPENDED: "suspended",
};

const defaultConfig = {
    apiUrl: API_BASE_URL,
    timeout: 5000,
    retries: RETRY_ATTEMPTS,
    features: {
        caching: true,
        logging: false,
        debugging: process.env.NODE_ENV === "development",
    },
    supportedFormats: ["json", "xml", "csv"],
    version: "2.1.0",
};

// Arrow functions and destructuring
const createUserProfile = ({ name, email, status = "active" }) => ({
    id: Math.random().toString(36).substr(2, 9),
    name,
    email,
    status,
    createdAt: new Date().toISOString(),
    isActive: status === userStatuses.ACTIVE,
});

// Async/await with error handling
const processUsers = async (userIds) => {
    const manager = new UserManager(defaultConfig);
    const results = [];

    for (const userId of userIds) {
        try {
            const user = await manager.fetchUser(userId);
            results.push({
                success: true,
                user,
                timestamp: Date.now(),
            });
        } catch (error) {
            results.push({
                success: false,
                error: error.message,
                userId,
                timestamp: Date.now(),
            });
        }
    }

    return results;
};

// Template literals and regular expressions
const validateEmail = (email) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
};

const formatUserMessage = (user, action) => {
    return `User ${user.name} (${
        user.email
    }) has been ${action} at ${new Date().toLocaleString()}`;
};

// Export for module usage
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        UserManager,
        userStatuses,
        createUserProfile,
        processUsers,
        validateEmail,
        formatUserMessage,
    };
}

// Example usage
const exampleUsers = [
    { name: "John Doe", email: "john@example.com", status: "active" },
    { name: "Jane Smith", email: "jane@example.com", status: "pending" },
    { name: "Bob Johnson", email: "bob@example.com" },
];

console.log("Created user profiles:");
exampleUsers.forEach((userData) => {
    const profile = createUserProfile(userData);
    console.log(`- ${formatUserMessage(profile, "created")}`);
});
