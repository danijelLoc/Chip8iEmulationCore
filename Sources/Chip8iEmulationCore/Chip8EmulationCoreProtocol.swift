//
//  Chip8EmulationCoreProtocol.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 25.02.2025..
//
import Foundation
import Combine


/// Protocol for emulation core that should be used for starting emulation, sending inputs and subscribing to its screen and sound output. It also includes optional debug output info for advanced users.
/// This is a ViewModel that creates execution loop and communicates with internal Chip8 program operations processing modules.
public protocol Chip8EmulationCoreProtocol {

    /// Output screen buffer 64 width x 32 height. Pixel can be 0 or 1. True is turned On and False is turned Off.
    /// One example of how to subscribe to this data is to create CGImage from it using fromMonochromeBitmap extension method and then show it in Image element.
    var outputScreenPublisher: Published<[Bool]>.Publisher { get }
    /// A publisher that emits changes to the debugSystemStateInfo value.
    var debugSystemStateInfoPublisher: Published<Chip8SystemState>.Publisher { get }
    /// Debug Info about encountered error
    var debugErrorInfoPublisher: Published<Error?>.Publisher { get }
    /// Info about play status
    var playingInfoPublisher: Published<PlayingInfo>.Publisher { get }

    /// Starts emulation of the Chip8 program. Programs for Chip8 are executed indefinitely (infinite loop).
    func emulate(_ program: Chip8Program) async
    
    /// Pause and resume the emulation of the Chip8 program
    func togglePause() async
    /// Stops running emulation of the Chip8 program
    func stop() async
    /// Loads emulation state if it belongs to the current loaded program
    func loadState(_ newState: EmulationState)
    /// Exports current Chip8SystemState so it can be saved in frontend app. Note: Saving and loading from files, internet etc. should be done in frontend depending on the OS.
    func exportState() -> EmulationState?
    /// Chip8 Gameplay key pressed down. See Chip8Key enum for more information.
    func onKeyDown(_ key: Chip8Key)
    /// Chip8 Gameplay key released. See Chip8Key enum for more information.
    func onKeyUp(_ key: Chip8Key)
}
