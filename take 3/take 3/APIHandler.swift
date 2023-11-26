//
//  APIHandler.swift
//  take 3
//
//  Created by King on 11/25/23.
//

import Foundation

enum APIHandler {
    static let apiHost = "api.spotify.com"
    static let authHost = "accounts.spotify.com"
    static let clientId = "8297650d46c941839638fcc443da4610"
    static let clientSecret = "bc08a06883374bd1ba0c9c6519b1b603"
    static let redirectUri = "https://www.google.com"
    static let responseType = "token"
    static let scopes = "user-library-read playlist-modify-public playlist-modify-private"
    
    static var authParams = [
            "response_type": responseType,
            "client_id": clientId,
            "redirect_uri": redirectUri,
            "scope": scopes
        ]
    }
