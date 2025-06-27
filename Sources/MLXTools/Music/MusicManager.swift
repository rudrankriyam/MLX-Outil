import Foundation
import MusicKit
import os

/// Error types for music operations
public enum MusicError: Error, LocalizedError {
    case invalidAction
    case authorizationDenied
    case missingQuery
    case itemNotFound
    case noResults
    
    public var errorDescription: String? {
        switch self {
        case .invalidAction:
            return "Invalid action. Use 'search', 'play', 'pause', 'next', 'previous', or 'currentSong'."
        case .authorizationDenied:
            return "Apple Music access denied. Please grant permission in Settings."
        case .missingQuery:
            return "Search query is required."
        case .itemNotFound:
            return "The requested music item was not found."
        case .noResults:
            return "No results found for your search."
        }
    }
}

/// Input for music operations
public struct MusicInput: Codable, Sendable {
    public let action: String
    public let query: String?
    public let searchType: String?
    public let limit: Int?
    public let itemId: String?
    
    public init(
        action: String,
        query: String? = nil,
        searchType: String? = nil,
        limit: Int? = nil,
        itemId: String? = nil
    ) {
        self.action = action
        self.query = query
        self.searchType = searchType
        self.limit = limit
        self.itemId = itemId
    }
}

/// Output for music operations
public struct MusicOutput: Codable, Sendable {
    public let status: String
    public let message: String
    public let results: String?
    public let nowPlaying: String?
    public let playbackState: String?
    
    public init(
        status: String,
        message: String,
        results: String? = nil,
        nowPlaying: String? = nil,
        playbackState: String? = nil
    ) {
        self.status = status
        self.message = message
        self.results = results
        self.nowPlaying = nowPlaying
        self.playbackState = playbackState
    }
}

/// Manager for music operations using MusicKit
@MainActor
public class MusicManager {
    public static let shared = MusicManager()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MLXTools", category: "MusicManager")
    
    private init() {
        logger.info("MusicManager initialized")
    }
    
    /// Main entry point for music operations
    public func performAction(_ input: MusicInput) async throws -> MusicOutput {
        logger.info("Performing music action: \(input.action)")
        
        // Check if MusicKit is authorized
        let authStatus = MusicAuthorization.currentStatus
        
        if authStatus != .authorized {
            if authStatus == .notDetermined {
                let status = await MusicAuthorization.request()
                if status != .authorized {
                    throw MusicError.authorizationDenied
                }
            } else {
                throw MusicError.authorizationDenied
            }
        }
        
        switch input.action.lowercased() {
        case "search":
            return try await searchMusic(query: input.query, type: input.searchType, limit: input.limit)
        case "play":
            return try await playMusic(itemId: input.itemId, query: input.query)
        case "pause":
            return pauseMusic()
        case "next":
            return try await skipToNext()
        case "previous":
            return try await skipToPrevious()
        case "currentsong":
            return getCurrentSong()
        default:
            throw MusicError.invalidAction
        }
    }
    
    private func searchMusic(query: String?, type: String?, limit: Int?) async throws -> MusicOutput {
        guard let query = query, !query.isEmpty else {
            throw MusicError.missingQuery
        }
        
        let searchLimit = limit ?? 10
        var request = MusicCatalogSearchRequest(term: query, types: [Song.self, Artist.self, Album.self])
        request.limit = searchLimit
        
        do {
            let response = try await request.response()
            var resultDescription = ""
            
            // Process songs
            if !response.songs.isEmpty {
                resultDescription += "🎵 Songs:\n"
                for (index, song) in response.songs.prefix(5).enumerated() {
                    resultDescription += "\(index + 1). \"\(song.title)\" by \(song.artistName)\n"
                    if let album = song.albumTitle {
                        resultDescription += "   Album: \(album)\n"
                    }
                    resultDescription += "   ID: \(song.id)\n\n"
                }
            }
            
            // Process artists
            if !response.artists.isEmpty {
                resultDescription += "👤 Artists:\n"
                for (index, artist) in response.artists.prefix(3).enumerated() {
                    resultDescription += "\(index + 1). \(artist.name)\n"
                    resultDescription += "   ID: \(artist.id)\n\n"
                }
            }
            
            // Process albums
            if !response.albums.isEmpty {
                resultDescription += "💿 Albums:\n"
                for (index, album) in response.albums.prefix(3).enumerated() {
                    resultDescription += "\(index + 1). \"\(album.title)\" by \(album.artistName)\n"
                    if let releaseDate = album.releaseDate {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        resultDescription += "   Released: \(formatter.string(from: releaseDate))\n"
                    }
                    resultDescription += "   ID: \(album.id)\n\n"
                }
            }
            
            if resultDescription.isEmpty {
                resultDescription = "No results found for '\(query)'"
            }
            
            return MusicOutput(
                status: "success",
                message: "Found music matching '\(query)'",
                results: resultDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            logger.error("Search failed: \(error)")
            throw MusicError.noResults
        }
    }
    
    private func playMusic(itemId: String?, query: String?) async throws -> MusicOutput {
        do {
            let player = ApplicationMusicPlayer.shared
            
            if let itemId = itemId {
                // Play specific item by ID
                let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(itemId))
                let response = try await request.response()
                
                if let song = response.items.first {
                    player.queue = [song]
                    try await player.play()
                    
                    return MusicOutput(
                        status: "success",
                        message: "Now playing: \(song.title)",
                        nowPlaying: "\(song.title) by \(song.artistName)"
                    )
                } else {
                    throw MusicError.itemNotFound
                }
            } else if let query = query {
                // Search and play first result
                var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
                request.limit = 1
                let response = try await request.response()
                
                if let song = response.songs.first {
                    player.queue = [song]
                    try await player.play()
                    
                    return MusicOutput(
                        status: "success",
                        message: "Now playing: \(song.title)",
                        nowPlaying: "\(song.title) by \(song.artistName)"
                    )
                } else {
                    throw MusicError.noResults
                }
            } else {
                // Resume playback
                try await player.play()
                return MusicOutput(
                    status: "success",
                    message: "Playback resumed"
                )
            }
        } catch {
            logger.error("Play failed: \(error)")
            throw error
        }
    }
    
    private func pauseMusic() -> MusicOutput {
        let player = ApplicationMusicPlayer.shared
        player.pause()
        
        return MusicOutput(
            status: "success",
            message: "Playback paused"
        )
    }
    
    private func skipToNext() async throws -> MusicOutput {
        let player = ApplicationMusicPlayer.shared
        
        do {
            try await player.skipToNextEntry()
            return MusicOutput(
                status: "success",
                message: "Skipped to next song"
            )
        } catch {
            logger.error("Skip next failed: \(error)")
            throw error
        }
    }
    
    private func skipToPrevious() async throws -> MusicOutput {
        let player = ApplicationMusicPlayer.shared
        
        do {
            try await player.skipToPreviousEntry()
            return MusicOutput(
                status: "success",
                message: "Skipped to previous song"
            )
        } catch {
            logger.error("Skip previous failed: \(error)")
            throw error
        }
    }
    
    private func getCurrentSong() -> MusicOutput {
        let player = ApplicationMusicPlayer.shared
        
        guard let nowPlaying = player.queue.currentEntry else {
            return MusicOutput(
                status: "success",
                message: "No song currently playing"
            )
        }
        
        // Check if the entry has an item (non-transient)
        if case let .song(song) = nowPlaying.item {
            let nowPlayingText = "\(song.title) by \(song.artistName)"
            if let album = song.albumTitle {
                return MusicOutput(
                    status: "success",
                    message: "Currently playing: \(nowPlayingText) from \(album)",
                    nowPlaying: nowPlayingText,
                    playbackState: String(describing: player.state.playbackStatus)
                )
            } else {
                return MusicOutput(
                    status: "success",
                    message: "Currently playing: \(nowPlayingText)",
                    nowPlaying: nowPlayingText,
                    playbackState: String(describing: player.state.playbackStatus)
                )
            }
        } else if let item = nowPlaying.item {
            return MusicOutput(
                status: "success",
                message: "Currently playing: \(item.id)",
                playbackState: String(describing: player.state.playbackStatus)
            )
        } else {
            return MusicOutput(
                status: "success",
                message: "Unknown playback state"
            )
        }
    }
}