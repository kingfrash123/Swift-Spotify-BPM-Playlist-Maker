//
//  APIService.swift
//  take 3
//
//  Created by King on 11/25/23.
//

import Foundation


class APIService {
    
    static let shared = APIService()
    
    func getAccessTokenURL() -> URLRequest? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = APIHandler.authHost
        components.path = "/authorize"
        
        components.queryItems = APIHandler.authParams.map({URLQueryItem(name: $0, value: $1)})
        
        guard let url = components.url else { return nil }
        
        return URLRequest(url: url)
    }
    
    func constructFirst50UserSongs(offset: String) -> URLRequest? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = APIHandler.apiHost
        components.path = "/v1/me/tracks"
        
        //https://api.spotify.com/v1/me/tracks?market=us&limit=2&offset=0
        components.queryItems = [
            URLQueryItem(name: "market", value: "us"),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "offset", value: offset)
        ]
        
        guard let url = components.url else { return nil }
        
        var urlRequest = URLRequest(url: url)
        
        let token: String = UserDefaults.standard.value(forKey: "Authorization") as! String
        
        urlRequest.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        urlRequest.httpMethod = "GET"
        
        //print(urlRequest)
        return urlRequest
    }
    
    
    func getFirst50UserSongs(offset: Int) async throws -> [String] {
        let offsetString = String(offset)
        guard let urlRequest = constructFirst50UserSongs(offset: offsetString) else { throw NetworkError.invalidURL }
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        
        let decoder = JSONDecoder()
        
        
        struct Track: Codable {
            let id: String
        }

        struct Items: Codable {
            let track: Track
        }

        struct Response: Codable {
            let items: [Items]
        }
        
        let results = try decoder.decode(Response.self, from: data)
        
        let trackIDs = results.items.map { $0.track.id }
        
        return trackIDs
    }
    
    



    func constructSongSearch(song:String) -> URLRequest? {
    var components = URLComponents()
    components.scheme = "https"
    components.host = APIHandler.apiHost
    components.path = "/v1/search"
    
    components.queryItems = [
        URLQueryItem(name: "type", value: "track"),
        URLQueryItem(name: "query", value: song),
        URLQueryItem(name: "limit", value: "1")
    ]
    
    guard let url = components.url else { return nil }
    
    var urlRequest = URLRequest(url: url)
    
    let token: String = UserDefaults.standard.value(forKey: "Authorization") as! String
    
    urlRequest.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
    urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    urlRequest.httpMethod = "GET"
    
    return urlRequest
    
}
    
    
    func getSongSearch(song:String) async throws -> [String] {
        guard let urlRequest = constructSongSearch(song: song) else { throw NetworkError.invalidURL }
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        
        let decoder = JSONDecoder()
        
        
        struct Response: Codable {
            let tracks: Track
        }
        struct Track: Codable {
            let items: [Items]
        }

        struct Items: Codable {
            let id: String
        }

        let results = try decoder.decode(Response.self, from: data)
        
        let items = results.tracks.items
        
        let songs = items.map({$0.id})
        return songs
    }
    

    
    func constructTempoSearch(songId: [String]) -> URLRequest? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = APIHandler.apiHost
        components.path = "/v1/audio-features"
        
        // Join the array of songIds into a single string separated by commas
            let joinedIds = songId.joined(separator: ",")

            components.queryItems = [
                URLQueryItem(name: "ids", value: joinedIds),
            ]
        
        
        //https://api.spotify.com/v1/audio-features/1zqqPC2TUrUnZEvrsx28Wu
        guard let url = components.url else { return nil }
        
        var urlRequest = URLRequest(url: url)
        
        let token: String = UserDefaults.standard.value(forKey: "Authorization") as! String
        
        urlRequest.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        urlRequest.httpMethod = "GET"
        
        //print(urlRequest)
        
        return urlRequest
        
    }
        
        
    func getTempoSearch(songId: [String]) async throws -> [[String]] {
        guard let urlRequest = constructTempoSearch(songId: songId) else {
            throw NetworkError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(for: urlRequest)

        do {
            // Parse the JSON data
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

            // Extract the "audio_features" array
            if let audioFeatures = json?["audio_features"] as? [[String: Any]] {
                // Extract the "id" and "tempo" values for each feature and convert to strings
                let idsAndTempos = audioFeatures.compactMap { feature -> [String]? in
                    if let id = feature["id"] as? String, let tempo = feature["tempo"] as? Double {
                        return [id, String(tempo)]
                    }
                    return nil
                }

                if !idsAndTempos.isEmpty {
                    return idsAndTempos
                } else {
                    throw NetworkError.generalError
                }
            } else {
                throw NetworkError.generalError
            }
        } catch {
            throw NetworkError.generalError
        }
    }


    func constructAddToPlaylist(uris: [String], playlistId: String) async throws -> URLRequest? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = APIHandler.apiHost
        components.path = "/v1/playlists/\(playlistId)/tracks"
        
    //https://api.spotify.com/v1/playlists/03eWyRRZEf39IuufnkUUgF/track
        
        guard let url = components.url else { return nil }
        
        var urlRequest = URLRequest(url: url)
        
        let token: String = UserDefaults.standard.value(forKey: "Authorization") as! String
        
        urlRequest.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        urlRequest.httpMethod = "POST"
        
        // Create a dictionary for the request body
        let requestBody: [String: Any] = ["uris": uris.map { "spotify:track:\($0)" }]
        
        // Convert the dictionary to JSON data
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            urlRequest.httpBody = jsonData
        } catch {
            print("Error converting request body to JSON: \(error)")
            return nil
        }
        return urlRequest
        
    }

    
    func constructCreatePlaylist(username: String, playlistName: String) async throws -> String? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = APIHandler.apiHost
        components.path = "/v1/users/\(username)/playlists"
        
        //https://api.spotify.com/v1/users/kingfrash123/playlists
        
        guard let url = components.url else { return nil }
        
        var urlRequest = URLRequest(url: url)
        
        let token: String = UserDefaults.standard.value(forKey: "Authorization") as! String
        
        urlRequest.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        urlRequest.httpMethod = "POST"
        

        // Create a dictionary for the request body
        let requestBody: [String: Any] = ["name": playlistName]
        
        // Convert the dictionary to JSON data
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            urlRequest.httpBody = jsonData
        } catch {
            print("Error converting request body to JSON: \(error)")
            return nil
        }
        
        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        
        let decoder = JSONDecoder()
        
        
        struct Response: Codable {
            let id: String
        }

        let result = try decoder.decode(Response.self, from: data)
        return result.id
        
    }
    
    
    
    
    func constructUsername() -> URLRequest? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = APIHandler.apiHost
        components.path = "/v1/me"
        
        //https://api.spotify.com/v1/me
        
        
        guard let url = components.url else { return nil }
        
        var urlRequest = URLRequest(url: url)
        
        let token: String = UserDefaults.standard.value(forKey: "Authorization") as! String
        
        urlRequest.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        urlRequest.httpMethod = "GET"
        
        return urlRequest
        
    }
        
        
        func getUsername() async throws -> String {
            guard let urlRequest = constructUsername() else { throw NetworkError.invalidURL }
            
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            
            let decoder = JSONDecoder()
            
            
            struct Response: Codable {
                let id: String
            }

            let result = try decoder.decode(Response.self, from: data)
            return result.id
        }
}
