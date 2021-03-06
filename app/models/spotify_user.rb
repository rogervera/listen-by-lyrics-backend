class SpotifyUser < ApplicationRecord
  validates :spotify_id, uniqueness: true, presence: true
  # has_many :tracks

  def access_token_expired?
    #return true if access_token is older than 55 minutes, based on update_at
    (Time.now - self.updated_at) > 3300
  end

  # TODO: Use HTTP/NET to see if that solves 400 error
  def refresh_access_token
    # Check if user's access token has expired
    if access_token_expired?
      #Request a new access token using refresh token
      #Create body of request
      body = {
        grant_type: "refresh_token",
        refresh_token: self.refresh_token,
        client_id: ENV['CLIENT_ID'],
        client_secret: ENV["CLIENT_SECRET"]
      }
      # Send request and updated user's access_token
      auth_response = RestClient.post('https://accounts.spotify.com/api/token', body)
      auth_params = JSON.parse(auth_response)
      self.update(access_token: auth_params["access_token"])
    else
      puts "Current user's access token has not expired"
    end
  end

  def get_playlist_tracks
    getUrl = "https://api.spotify.com/v1/playlists/#{self.playlist_id}"
    getHeader = {
      Authorization: "Bearer #{self.access_token}"
    }
    begin
      response = RestClient.get(getUrl, getHeader)
      response_body = JSON.parse(response.body)
      playlist_tracks = response_body['tracks']['items']
      user_track_ids = playlist_tracks.map {|playlist_track| playlist_track['track']['id']}
      users_tracks = Track.all.select {|server_track| user_track_ids.include? server_track.spotify_track_id}
      json_tracks = users_tracks.map {|track| track.to_json_object}
      return json_tracks
    rescue => e
      return e
    end
  end

  def find_or_create_playlist
    getUrl = "https://api.spotify.com/v1/playlists/#{self.playlist_id}"
    getHeader = {
      Authorization: "Bearer #{self.access_token}"
    }
    begin
      RestClient.get(getUrl, getHeader)
      self.playlist_id
    rescue => e
      # Playlist not found
      # Create a new playlist
      postUrl = "https://api.spotify.com/v1/users/#{self.spotify_id}/playlists"
      postHeader = {
        Authorization: "Bearer #{self.access_token}",
        "Content-Type": 'application/json'
      }
      payload = "{\"name\":\"ListenByLyrics Songs\", \"public\":false}"
      response = RestClient.post(postUrl, payload, postHeader)
      playlist_object = JSON.parse(response.body)
      self.update(playlist_id: playlist_object["id"])
      self.playlist_id
    end
  end

end
