// TypeScript/JavaScript Test File
import { useState, useEffect, useCallback } from "react";
import type { User, ApiResponse, Config } from "./types";

interface UserProfileProps {
    userId: string;
    onUpdate?: (user: User) => void;
}

// Constants and enums
const API_BASE_URL = "https://api.example.com";
const RETRY_ATTEMPTS = 3;

enum UserStatus {
    ACTIVE = "active",
    INACTIVE = "inactive",
    PENDING = "pending",
}

// Main component
const UserProfile: React.FC<UserProfileProps> = ({ userId, onUpdate }) => {
    const [user, setUser] = useState<User | null>(null);
    const [loading, setLoading] = useState<boolean>(true);
    const [error, setError] = useState<string | null>(null);

    // Async function with error handling
    const fetchUser = useCallback(async (id: string): Promise<User | null> => {
        try {
            const response = await fetch(`${API_BASE_URL}/users/${id}`);

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data: ApiResponse<User> = await response.json();
            return data.result;
        } catch (err) {
            console.error("Failed to fetch user:", err);
            setError(err instanceof Error ? err.message : "Unknown error");
            return null;
        }
    }, []);

    // Effect hook with cleanup
    useEffect(() => {
        let isMounted = true;

        const loadUser = async () => {
            setLoading(true);
            setError(null);

            const userData = await fetchUser(userId);

            if (isMounted) {
                setUser(userData);
                setLoading(false);

                if (userData && onUpdate) {
                    onUpdate(userData);
                }
            }
        };

        loadUser();

        return () => {
            isMounted = false;
        };
    }, [userId, fetchUser, onUpdate]);

    // Conditional rendering
    if (loading) return <div className="spinner">Loading...</div>;
    if (error) return <div className="error">Error: {error}</div>;
    if (!user) return <div className="empty">User not found</div>;

    return (
        <div className="user-profile">
            <h2>{user.name}</h2>
            <p className="email">{user.email}</p>
            <span className={`status status--${user.status.toLowerCase()}`}>
                {user.status}
            </span>
            {user.bio && <p className="bio">{user.bio}</p>}
        </div>
    );
};

// Export with default
export default UserProfile;

// Named exports
export { type UserProfileProps, UserStatus };

// Complex object with various data types
const config: Config = {
    apiUrl: API_BASE_URL,
    timeout: 5000,
    retries: RETRY_ATTEMPTS,
    features: {
        darkMode: true,
        notifications: false,
        analytics: null,
    },
    supportedLanguages: ["en", "es", "fr", "de"],
    version: "1.2.3",
};
