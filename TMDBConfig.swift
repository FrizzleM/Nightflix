import Foundation

enum TMDBConfig {
    /// TMDB API v3 bearer token. Replace the placeholder with your token locally.
    static let bearerToken = "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI3MTNlY2VkZmQ1NmVkNDZiMDBiZTg1N2Q3ODg3NTE1MSIsIm5iZiI6MTc3OTYyMzA4Mi4xNzUsInN1YiI6IjZhMTJlNGFhOWFkOWYxOWE3ZWE5Y2NiZiIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.8g0u3KwAVxnWszrKGfqvxrUl0VuG-_e0ZvTv5xDVRd4"

    static let imageBaseURL = URL(string: "https://image.tmdb.org/t/p/w500")!
    static let posterImageBaseURL = URL(string: "https://image.tmdb.org/t/p/w500")!
    static let backdropImageBaseURL = URL(string: "https://image.tmdb.org/t/p/w1280")!

    static var hasConfiguredBearerToken: Bool {
        let trimmedToken = bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedToken.isEmpty && trimmedToken != "YOUR_TMDB_BEARER_TOKEN"
    }
}
