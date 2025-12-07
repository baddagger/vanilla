import Foundation

enum PlaybackState {
    case idle
    case loading
    case playing(progress: TimeInterval, duration: TimeInterval)
    case paused(progress: TimeInterval, duration: TimeInterval)
    case stopped
    case error(String)
}
