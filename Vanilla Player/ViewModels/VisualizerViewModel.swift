import SwiftUI
import Combine

class VisualizerViewModel: ObservableObject {
    @Published var meteringLevels: [Float] = Array(repeating: 0, count: 32)
    
    private var cancellables = Set<AnyCancellable>()
    
    init(audioManager: AudioEngineManager) {
        audioManager.$meteringLevels
            .receive(on: RunLoop.main)
            .assign(to: &$meteringLevels)
    }
}
