//
//  PrerecordedSoundHandler.swift
//  Chip8iEmulator
//
//  Created by Danijel Stracenski on 15.02.2025..
//

import AVFoundation

/// This handler requires short sound beep effect which it will use for emulation.
///
/// It was tested with 1 second beep sound in WAV file type.
public class PrerecordedSoundHandler: SoundHandlerProtocol {
    private var audioPlayer: AVAudioPlayer?
    private var isEmulationPaused: Bool = false
    
    public init(with soundUrl: URL) {
        loadSound(soundUrl)
    }
    
    public init(with bundleNameWithExtension: String) {
        guard let soundURL = Bundle.main.url(forResource: bundleNameWithExtension, withExtension: nil) else {
            print("Failed to locate sound file")
            return
        }
        loadSound(soundURL)
    }
    
    private func loadSound(_ shortSoundUrl: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: shortSoundUrl)
            audioPlayer?.prepareToPlay()
            audioPlayer?.numberOfLoops = -1  // Loop indefinitely
        } catch {
            print("Error loading sound: \(error)")
        }
    }
    
    public func handleSoundTimerChange(soundTimer: UInt8) {
        if isEmulationPaused {
            audioPlayer?.pause()
            return
        }
        
        if soundTimer > 0 && !(audioPlayer?.isPlaying == true) {
            audioPlayer?.play()
        } else if soundTimer == 0 && audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
    }
    
    public func onEmulationPause(isPaused: Bool) {
        isEmulationPaused = isPaused
    }
}
