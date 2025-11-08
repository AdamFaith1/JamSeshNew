import Foundation

// Returned to your UI
struct SongSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let artworkURL: URL?
}

// MARK: - iTunes models
private struct ITunesResponse: Decodable {
    let results: [ITunesSong]
}
private struct ITunesSong: Decodable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let collectionName: String?
    let artworkUrl100: URL?
}

final class SongSearchService {
    static let shared = SongSearchService()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        cfg.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024,
                                diskCapacity: 200 * 1024 * 1024)
        return URLSession(configuration: cfg)
    }()
    private let decoder = JSONDecoder()

    // Main API
    func search(_ query: String, limit: Int = 20) async throws -> [SongSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let term = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string:
            "https://itunes.apple.com/search?media=music&entity=song&limit=\(limit)&term=\(term)"
        )!

        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }

        let res = try decoder.decode(ITunesResponse.self, from: data)
        return res.results.map { s in
            SongSuggestion(
                id: String(s.trackId),
                title: s.trackName,
                artist: s.artistName,
                album: s.collectionName ?? "",
                artworkURL: highResArtworkURL(from: s.artworkUrl100)
            )
        }
    }

    private func highResArtworkURL(from url: URL?) -> URL? {
        guard let url else { return nil }
        // iTunes CDN allows higher res by changing the size segment
        let up = url.absoluteString
            .replacingOccurrences(of: "100x100bb", with: "600x600bb")
        return URL(string: up)
    }
}

