import Foundation

// MARK: - Profile Queries

public enum ProfileQueries {
    public static let getProfile = """
        query profile {
            profile {
                goals
                occupation
                housing
                transport
                currency
                age
                notify_daily_report
                notify_weekly_report
                notify_monthly_report
                notify_annual_report
                notify_new_recommendation
                favorite_realtime_voice
                favorite_vibe
                achievements {
                    id
                    name
                    created_at
                }
                created_at
                email
                name
                first_name
                last_name
                picture
                timezone
                plan
                planStartsAt
                planExpiresAt
            }
        }
        """

    public static let updateProfile = """
        mutation updateProfile($input: ProfileInput!) {
            updateProfile(input: $input) {
                goals
                occupation
                housing
                transport
                currency
                age
                notify_daily_report
                notify_weekly_report
                notify_monthly_report
                notify_annual_report
                notify_new_recommendation
                favorite_realtime_voice
                favorite_vibe
                achievements {
                    id
                    name
                    created_at
                }
                created_at
                email
                name
                first_name
                last_name
                picture
                plan
                planStartsAt
                planExpiresAt
            }
        }
        """
}
