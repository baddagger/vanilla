import Accelerate
import AVFoundation
import Combine
import Foundation

class AudioEngineManager: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var meteringLevels: [Float] = Array(repeating: 0, count: 32)

    var onPlaybackFinished: (() -> Void)?

    private var engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var eqNode = AVAudioUnitEQ(numberOfBands: 1)
    private var audioFile: AVAudioFile?
    private var timer: Timer?
    private var startingFrame: AVAudioFramePosition = 0

    // Playback Session ID to handle race conditions
    private var currentPlaybackID = UUID()
    private var isActive = true

    // FFT Properties
    private let fftSize = 1024
    private var fftSetup: vDSP_DFT_Setup?

    // FAST PROCESSING: Pre-allocated buffers to avoid allocations in hot path
    private var window: [Float] = []
    private var realInput: [Float] = []
    private var imagInput: [Float] = []
    private var realOutput: [Float] = []
    private var imagOutput: [Float] = []

    // Caching for Frequency Bands
    private struct MelBand {
        let binStart: Int
        let binEnd: Int
    }

    private var cachedMelBands: [MelBand] = []
    private var lastSampleRate: Float = 0

    // UI Throttling
    private var lastUIUpdateTime: TimeInterval = 0
    private let uiUpdateInterval: TimeInterval = 0.033 // ~30 FPS

    init() {
        setupFFT()
        setupAudioEngine()
    }

    private func setupFFT() {
        // Create DFT setup for real-to-complex FFT
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)

        // Create Hanning window
        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        // Initialize buffers
        realInput = [Float](repeating: 0, count: fftSize)
        imagInput = [Float](repeating: 0, count: fftSize)
        realOutput = [Float](repeating: 0, count: fftSize)
        imagOutput = [Float](repeating: 0, count: fftSize)
    }

    private func setupAudioEngine() {
        // Configure EQ
        let bassBand = eqNode.bands[0]
        bassBand.filterType = .lowShelf
        bassBand.frequency = 150.0
        bassBand.bypass = false
        bassBand.gain = 0

        engine.attach(playerNode)
        engine.attach(eqNode)

        engine.connect(playerNode, to: eqNode, format: nil)
        engine.connect(eqNode, to: engine.mainMixerNode, format: nil)

        // Install tap for FFT
        let mixer = engine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)
        // Ensure buffer size is power of 2 suitable for FFT
        mixer
            .installTap(onBus: 0, bufferSize: UInt32(fftSize),
                        format: format)
            { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
            }

        do {
            try engine.start()
        } catch {
            print("Failed to start engine: \(error)")
        }
    }

    func play(url: URL) {
        // Generate new session ID to invalidate any pending completion handlers
        currentPlaybackID = UUID()
        let sessionID = currentPlaybackID

        do {
            // Stop current playback and engine to allow safe reconfiguration
            playerNode.stop()
            engine.stop()

            // Load new file
            audioFile = try AVAudioFile(forReading: url)
            guard let audioFile else { return }

            // Reconnect with correct format
            engine.disconnectNodeOutput(playerNode)
            engine.disconnectNodeOutput(eqNode)

            engine.connect(playerNode, to: eqNode, format: audioFile.processingFormat)
            engine.connect(eqNode, to: engine.mainMixerNode, format: audioFile.processingFormat)

            // Schedule file with ID check
            playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    // Only trigger finish if this matches the current session
                    if self.currentPlaybackID == sessionID {
                        self.audioPlayerDidFinishPlaying()
                    }
                }
            }

            // Update state
            duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            startingFrame = 0
            currentTime = 0

            // Start playback
            try engine.start()
            playerNode.play()
            isPlaying = true
            startTimer()

            // Invalidate stale FFT data
            lastSampleRate = 0

        } catch {
            print("Error loading track: \(error)")
        }
    }

    func pause() {
        if isPlaying {
            if let nodeTime = playerNode.lastRenderTime,
               let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
            {
                startingFrame = playerTime.sampleTime
            }
            playerNode.pause()
            isPlaying = false
            timer?.invalidate()
        }
    }

    func resume() {
        if !isPlaying {
            if !engine.isRunning {
                try? engine.start()
            }
            playerNode.play()
            isPlaying = true
            startTimer()
        }
    }

    func seek(to time: TimeInterval) {
        guard let audioFile else { return }

        // Create new session ID because seeking effectively restarts the scheduling
        currentPlaybackID = UUID()
        let sessionID = currentPlaybackID

        let sampleRate = audioFile.processingFormat.sampleRate
        let newFrame = AVAudioFramePosition(time * sampleRate)
        let framesRemaining = AVAudioFrameCount(audioFile.length - newFrame)

        guard newFrame >= 0, newFrame < audioFile.length else { return }

        playerNode.stop()

        playerNode
            .scheduleSegment(
                audioFile,
                startingFrame: newFrame,
                frameCount: framesRemaining,
                at: nil,
            ) { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if self.currentPlaybackID == sessionID {
                        self.audioPlayerDidFinishPlaying()
                    }
                }
            }

        startingFrame = newFrame
        currentTime = time

        if isPlaying {
            playerNode.play()
        }
    }

    func setAppActiveState(_ isActive: Bool) {
        self.isActive = isActive
        if isActive {
            if isPlaying {
                startTimer()
            }
        } else {
            timer?.invalidate()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        // Run at 60Hz for smooth UI updates
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
    }

    private func updateCurrentTime() {
        guard let audioFile,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else { return }

        let sampleRate = audioFile.processingFormat.sampleRate
        let calculatedTime = Double(startingFrame + playerTime.sampleTime) / sampleRate
        currentTime = max(0, min(calculatedTime, duration))
    }

    private func audioPlayerDidFinishPlaying() {
        isPlaying = false
        timer?.invalidate()
        onPlaybackFinished?()
    }

    // MARK: - FFT Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isActive else { return }
        guard let channelData = buffer.floatChannelData?[0], let fftSetup else { return }

        let frameCount = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)

        // Check if we need to recalculate bands (sample rate changed)
        if sampleRate != lastSampleRate {
            recalculateMelBands(sampleRate: sampleRate)
            lastSampleRate = sampleRate
        }

        // Copy audio data using vDSP
        let copyCount = min(frameCount, fftSize)

        // Use UnsafeMutableBufferPointer access for all buffers to ensure exclusivity
        // and avoid Copy-on-Write triggers during the DSP operations.
        // We access all buffers at once to keep the pointers valid during the operation sequence.

        realInput.withUnsafeMutableBufferPointer { realInputPtr in
            guard let realInputBase = realInputPtr.baseAddress else { return }

            // 1. CLEAR & COPY
            // Equivalent to memset(realInput, 0)
            realInputBase.update(repeating: 0, count: fftSize)
            // Safe copy from source
            realInputBase.assign(from: channelData, count: copyCount)

            // 2. WINDOWING
            // vDSP_vmul(input, 1, window, 1, output, 1, length)
            // Use local copies of pointers to avoid Array exclusivity checks
            window.withUnsafeBufferPointer { windowPtr in
                guard let windowBase = windowPtr.baseAddress else { return }

                // In-place windowing: input = realInput, output = realInput
                vDSP_vmul(realInputBase, 1, windowBase, 1, realInputBase, 1, vDSP_Length(fftSize))
            }

            // 3. FFT EXECUTION
            imagInput.withUnsafeMutableBufferPointer { imagInputPtr in
                guard let imagInputBase = imagInputPtr.baseAddress else { return }

                // Clear imaginary input
                vDSP_vclr(imagInputBase, 1, vDSP_Length(fftSize))

                realOutput.withUnsafeMutableBufferPointer { realOutputPtr in
                    guard let realOutputBase = realOutputPtr.baseAddress else { return }

                    imagOutput.withUnsafeMutableBufferPointer { imagOutputPtr in
                        guard let imagOutputBase = imagOutputPtr.baseAddress else { return }

                        // Execute FFT
                        vDSP_DFT_Execute(
                            fftSetup,
                            realInputBase,
                            imagInputBase,
                            realOutputBase,
                            imagOutputBase,
                        )

                        // 4. MAGNITUDE CALCULATION
                        // We do this inside these closures to keep the output pointers valid
                        // although we could copy them out, it's faster to process here.

                        // Calculate normalized amplitudes using Mel scale
                        var newLevels = [Float](repeating: 0, count: 32)
                        let effectiveN = fftSize / 2

                        for (i, band) in cachedMelBands.enumerated() {
                            guard i < newLevels.count else { break }

                            var binStart = band.binStart
                            var binEnd = band.binEnd
                            binStart = max(0, binStart)
                            binEnd = min(effectiveN - 1, max(binStart, binEnd))

                            var sum: Float = 0

                            // Sum magnitudes for this band
                            for bin in binStart ... binEnd {
                                let real = realOutputBase[bin]
                                let imag = imagOutputBase[bin]
                                let magnitude = sqrtf(real * real + imag * imag)
                                sum += magnitude
                            }

                            let count = max(1, binEnd - binStart + 1)
                            let avgMagnitude = sum / Float(count)

                            let dBMin: Float = -60.0
                            let dBMax: Float = 40.0

                            let dBValue = 20 * log10f(max(avgMagnitude, 1e-10))
                            var normalizedValue = (dBValue - dBMin) / (dBMax - dBMin)
                            normalizedValue = min(1.0, max(0.0, normalizedValue))

                            newLevels[i] = normalizedValue
                        }

                        // 5. UPDATE UI
                        // Using local copy of newLevels
                        self.dispatchUIUpdate(newLevels: newLevels)
                    }
                }
            }
        }
    }

    private func dispatchUIUpdate(newLevels: [Float]) {
        let now = Date().timeIntervalSinceReferenceDate
        if now - lastUIUpdateTime >= uiUpdateInterval {
            lastUIUpdateTime = now
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                // Optimized Update: Smooth interpolation
                // We create a new array to avoid modifying state in a loop if possible,
                // but since we need previous values for decay, we map it.

                var updatedLevels = meteringLevels

                for i in 0 ..< updatedLevels.count {
                    let current = updatedLevels[i]
                    let target = newLevels[i]
                    if target > current {
                        // Instant attack
                        updatedLevels[i] = target
                    } else {
                        // Quick decay
                        updatedLevels[i] = current + (target - current) * 0.7
                    }
                }

                // SINGLE ASSIGNMENT to trigger Publisher only once per frame
                meteringLevels = updatedLevels
            }
        }
    }

    private func recalculateMelBands(sampleRate: Float) {
        cachedMelBands.removeAll(keepingCapacity: true)

        let effectiveN = fftSize / 2
        let freqResolution = sampleRate / Float(fftSize)
        let barsCount = 32

        let maxFreq = sampleRate / 2.0
        let minMel = freqToMel(20.0)
        let maxMel = freqToMel(maxFreq)
        let melStep = (maxMel - minMel) / Float(barsCount + 1)

        for i in 0 ..< barsCount {
            let melStart = minMel + Float(i) * melStep
            let melEnd = melStart + melStep
            let freqStart = melToFreq(melStart)
            let freqEnd = melToFreq(melEnd)

            let binStart = Int(freqStart / freqResolution)
            let binEnd = Int(freqEnd / freqResolution)

            cachedMelBands.append(MelBand(binStart: binStart, binEnd: binEnd))
        }
    }

    private func freqToMel(_ freq: Float) -> Float {
        2595.0 * log10f(1.0 + freq / 700.0)
    }

    private func melToFreq(_ mel: Float) -> Float {
        700.0 * (powf(10.0, mel / 2595.0) - 1.0)
    }

    // Public method to set the player volume
    func setPlayerVolume(_ volume: Float) {
        playerNode.volume = volume
    }

    func setBass(_ value: Float) {
        // Map -1...1 to -12...12 dB
        let gain = value * 12.0
        eqNode.bands[0].gain = gain
    }

    deinit {
        timer?.invalidate()
        if let fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }
}
