//
//  EmulationState.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 21.12.2024..
//

/// A wrapper around the emulated program content id and Chip8SystemState. Saved system state can only be used with specific program/game loaded into the system.
public struct EmulationState: Codable {
    /// Unique Id of the program/game ROM data that was loaded into the Chip8System
    public let programContentHash: String
    /// State of Chip8 System with all its registers, stack, memory and output buffer
    public let systemState: Chip8SystemState
}
