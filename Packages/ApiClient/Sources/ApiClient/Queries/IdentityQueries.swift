import Foundation

public enum IdentityQueries {
    public static let currentUser = """
        query currentUser {
            currentUser {
                id
                name
                photoUrl
                createdAt
                lastLogin
                platform
                experiences {
                    DIBBA_AI {
                        plan
                        planStartsAt
                        planExpiresAt
                    }
                }
            }
        }
        """

    public static let createCurrentUser = """
        mutation createCurrentUser($changes: UserCreate!) {
            createCurrentUser(changes: $changes) {
                id
                name
                photoUrl
                createdAt
                lastLogin
                platform
                experiences {
                    DIBBA_AI {
                        plan
                        planStartsAt
                        planExpiresAt
                    }
                }
            }
        }
        """
}
