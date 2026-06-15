import Foundation

enum TMDBConfig {
    static let imageBaseURL = URL(string: "https://image.tmdb.org/t/p/w500")!
    static let posterImageBaseURL = URL(string: "https://image.tmdb.org/t/p/w500")!
    static let backdropImageBaseURL = URL(string: "https://image.tmdb.org/t/p/w1280")!

    static var credential: String {
        NightFlixUserConfiguration.effectiveTMDBCredential
    }

    static var hasConfiguredCredential: Bool {
        NightFlixUserConfiguration.isValidTMDBReadAccessToken(credential)
    }
}
