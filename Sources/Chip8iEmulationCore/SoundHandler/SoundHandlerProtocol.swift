//
//  SoundHandler.swift
//  Chip8iEmulator
//
//  Created by Danijel Stracenski on 15.02.2025..
//

/// Sound handler protocol that will be used in Chip8EmulationCore. Custom generative wave implementations are welcomed.
public protocol SoundHandlerProtocol {
    /// On every change of timer if value is above 0 then beep should be played. Continuous sound should be played between the frames if value is still above 0, so looped continuous sound wave).
    /// When value  is 0 any playing sound should be stoped.
    func handleSoundTimerChange(soundTimer: UByte)
    
    /// If emulation is paused, all sounds should be paused also. This will also be called on stopping of the emulation.
    func onEmulationPause(isPaused: Bool)
}
