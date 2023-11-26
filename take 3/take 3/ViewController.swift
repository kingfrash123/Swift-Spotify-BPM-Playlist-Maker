//
//  ViewController.swift
//  take 3
//
//  Created by King on 11/25/23.
//

import UIKit
import WebKit

class ViewController: UIViewController {

    
    
    @IBOutlet weak var songEntered: UITextField!
    
    @IBOutlet weak var sliderValue: UISlider!
    
    @IBOutlet weak var playlistEntered: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }
    @IBAction func startButtonPressed(_ sender: Any) {
        if let token = UserDefaults.standard.value(forKey: "Authorization") {
            
            makeNetworkCall(searchedSong: songEntered.text ?? "Rick Roll", BPMRange: Double(sliderValue.value), PlaylistName: playlistEntered.text ?? "Rick Roll")
            
        } else {
            getAccessTokenFromWebView()
        }
    }
    // MARK: - about button
    @IBAction func aboutButtonPressed(_ sender: Any) {
        showPopup(description: "This App will make a playlist from your liked spotify songs that matches the BPM of the song you searched")
    }
    func showPopup(description: String) {
            let alertController = UIAlertController(title: "About", message: description, preferredStyle: .alert)

            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(okAction)

            present(alertController, animated: true, completion: nil)
        }
    
    // MARK: - Generate new Token
    private func getAccessTokenFromWebView() {
        guard let urlRequest = APIService.shared.getAccessTokenURL() else { return }
        let webview = WKWebView()
        
        webview.load(urlRequest)
        webview.navigationDelegate = self
        view = webview
    }
    
    // MARK: - All API service calls
    private func makeNetworkCall(searchedSong: String, BPMRange: Double, PlaylistName: String) {
        Task {
            print("sliderValue: \(BPMRange)")
            
            var username = ""
            username = try await APIService.shared.getUsername()
            print(username)
            
            
            var songIds = []
            var offset = 0
            var tempo: [[String]] = []
            
            var searchTempo = ""
            var searchTempoDouble = 0.0
            
            
            var searchedSongId = ["Init"]
            searchedSongId = try await APIService.shared.getSongSearch(song: searchedSong)
            
            print(searchedSongId)
            
           
            
            let singleTempo = try await APIService.shared.getTempoSearch(songId: searchedSongId)
                
                // Check if the result contains at least one inner array
            if let firstInnerArray = singleTempo.first {
                // Check if the first inner array contains at least one element
                searchTempo = firstInnerArray.last!
                    print(searchTempo)
                
            }
            
            
            repeat {
                do {
                    let partialSongIds = try await APIService.shared.getFirst50UserSongs(offset: offset)
                    songIds += partialSongIds
                    
                    tempo += try await APIService.shared.getTempoSearch(songId: partialSongIds)
                    
                    
                    
                    // Increment the offset for the next batch
                    offset += partialSongIds.count
                } catch {
                    // Handle error if needed
                    print("Error fetching user songs: \(error)")
                    // break or handle the error as necessary
                }
            } while songIds.count % 50 == 0  // Continue until the count is no longer a multiple of 50

            //print(songIds)
            print(songIds.count)
            //print(tempo)

            
            searchTempoDouble = Double(searchTempo)!
            
            

            let filteredData = tempo.filter { array in
                if array.count == 2, let tempoString = array.last, let tempoDouble = Double(tempoString) {
                    return tempoDouble >= searchTempoDouble - BPMRange && tempoDouble <= searchTempoDouble + BPMRange
                }
                return false
            }

            let filteredIDs = filteredData.map { $0.first ?? "" }

            //print(filteredIDs)

            var newPlaylistId = ""
            
            newPlaylistId = try await APIService.shared.constructCreatePlaylist(username: username, playlistName: PlaylistName)!
            
            print("playlist created with id: \(newPlaylistId)")
            
            
            
            let chunkSize = 100
            let totalItems = filteredIDs.count

            for startIndex in stride(from: 0, to: totalItems, by: chunkSize) {
                let endIndex = min(startIndex + chunkSize, totalItems)
                let chunk = Array(filteredIDs[startIndex..<endIndex])

                do {
                    guard let addToPlaylist = try await APIService.shared.constructAddToPlaylist(uris: chunk, playlistId: newPlaylistId) else {
                        throw NetworkError.invalidURL
                    }

                    let (data, _) = try await URLSession.shared.data(for: addToPlaylist)
                    print(data)
                } catch {
                    print("Error: \(error)")
                }
            }
            
            let alertController = UIAlertController(title: "Process Done", message: "You can now open Spotify to view your playlist in your library", preferredStyle: .alert)

            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(okAction)

            present(alertController, animated: true, completion: nil)
            
        }
    }
    
}

extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let urlString = webView.url?.absoluteString else { return }
        print(urlString)
        
        var tokenString = ""
        if urlString.contains("#access_token=") {
            let range = urlString.range(of: "#access_token=")
            guard let index = range?.upperBound else { return }
            
            tokenString = String(urlString[index...])
        }
        
        if !tokenString.isEmpty {
            let range = tokenString.range(of: "&token_type=Bearer")
            guard let index = range?.lowerBound else { return }
            
            tokenString = String(tokenString[..<index])
            UserDefaults.standard.setValue(tokenString, forKey: "Authorization")
            webView.removeFromSuperview()
            makeNetworkCall(searchedSong: songEntered.text ?? "Rick Roll", BPMRange: Double(sliderValue.value), PlaylistName: playlistEntered.text ?? "Rick Roll")
        }
    }
}
