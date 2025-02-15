//
//  Chip8EmulationCore.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 28.05.2024..
//

import Foundation
import Combine

/// Protocol for emulation core that should be used for starting emulation, sending inputs and subscribing to its screen and sound output. It also includes optional debug output info for advanced users. This is a ViewModel that creates execution loop and communicates with internal Chip8 program operations processing modules.
public protocol Chip8EmulationCoreProtocol {

    /// Output screen buffer 64 width x 32 height. Pixel can be 0 or 1. True is turned On and False is turned Off.
    /// One example of how to subscribe to this data is to create CGImage from it using fromMonochromeBitmap extension method and then show it in Image element.
    var outputScreenPublisher: Published<[Bool]>.Publisher { get }

    /// Indicates if emulator should play the sound. Returns (playSound, SoundTimerValue). If timer is greater than 0 playSound will be true.
    /// Important: On every change of timer if value is above 0 then beep should be played. Continuous sound should be played between the frames if value is still above 0, so looped continuous sound wave).
    /// When value  is 0 any playing sound should be stoped.
    var outputSoundTimerPublisher: Published<UByte>.Publisher { get }
    
    /// A publisher that emits changes to the debugSystemStateInfo value.
    var debugSystemStateInfoPublisher: Published<Chip8SystemState?>.Publisher { get }
    
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
    func onKeyDown(_ key: EmulationControls.Chip8Key)
    
    /// Chip8 Gameplay key released. See Chip8Key enum for more information.
    func onKeyUp(_ key: EmulationControls.Chip8Key)
}

/// Emulation Core that should be used for starting emulation, sending inputs and subscribing to its screen and sound output. It also includes optional debug output info for advanced users. This is a ViewModel that creates execution loop and communicates with internal Chip8 program operations processing modules.
public class Chip8EmulationCore: ObservableObject, Chip8EmulationCoreProtocol {
    /// Internal Chip8 System/CPU that executes the commands
    private var system: Chip8System
    /// Internal parser used for Chip8 operation codes
    private let opCodeParser: Chip8OperationParserProtocol
    /// Loaded Chip8 Program
    private var program: Chip8Program?
    
    private var logger: EmulationLoggerProtocol?
    
    /// Number of instructions done in a second. Usually shown in Hz. Default for most programs is 700 Hz
    private var systemCpuFrequency: Int = 600
    /// Number of frames (frame rate) drawn per second. Standard for Chip8 is 60 Hz. Also this is frequency for decrementing timers.
    private var systemScreenAndTimersFrequency = 60
    private var targetFrameTime: Double { 1.0 / Double(systemScreenAndTimersFrequency) }
    private var systemCpuInstructionsCountPerFrame: Int  { systemCpuFrequency / systemScreenAndTimersFrequency }

    private var hasEmulationStarted = false
    private var isPlaying = false
    
    private var emulationTask: Task<Void, Error>?
    
    /// Output screen buffer 64 width x 32 height. Pixel can be 0 or 1. True is turned On and False is turned Off.
    /// One example of how to subscribe to this data is to create CGImage from it using fromMonochromeBitmap extension method and then show it in Image element.
    @Published public private(set) var outputScreen: [Bool] = Array(repeating: false, count: 64*32)
    /// Indicates if emulator should ply the sound. Returns (playSound, SoundTimerValue). If timer is greater than 0 playSound will be true.
    /// Important: On every change of timer value that is greater than 0 you should play short sound (tick).
    @Published public private(set) var outputSoundTimer: UByte = 0
    
    /// Debug Info about current Chip8 System State
    @Published public private(set) var debugSystemStateInfo: Chip8SystemState?
    /// Debug Info about encountered error
    @Published public private(set) var debugErrorInfo: Error?
    
    /// Info about play status
    @Published public private(set) var playingInfo: PlayingInfo = PlayingInfo(hasStarted: false, isPlaying: false)
    
    // Publishers
    public var outputScreenPublisher: Published<[Bool]>.Publisher { $outputScreen }
    public var outputSoundTimerPublisher: Published<UByte>.Publisher { $outputSoundTimer}
    public var debugSystemStateInfoPublisher: Published<Chip8SystemState?>.Publisher { $debugSystemStateInfo }
    public var debugErrorInfoPublisher: Published<Error?>.Publisher { $debugErrorInfo }
    public var playingInfoPublisher: Published<PlayingInfo>.Publisher { $playingInfo }
    
    /// Logger is by default EmulationConsoleLogger, to disable logging set it to nil, or replace it with your own implementation, for example logging into file.
    public init(parser: Chip8OperationParserProtocol = Chip8OperationParser(), logger: EmulationLoggerProtocol? = EmulationConsoleLogger()) {
        self.logger = logger
        self.opCodeParser = parser
        self.system = Chip8System(parser: parser, logger: logger)

    }
    
    public func emulate(_ program: Chip8Program) async {
        do {
            await resetPublishers()
            self.system = Chip8System(parser: opCodeParser, logger: logger) // Reset the system
            self.program = program
            self.hasEmulationStarted = true
            self.isPlaying = true
            
            system.loadProgram(program.contentROM)
            
            emulationTask = Task { try await emulationLoop(program: program) }
            try await emulationTask?.value
            
        } catch let error {
            logger?.log("Stopping the emulation because error was thrown: \(error). Debug information sent to publishers.", level: .error)
            await publishDebugInfo(error: error)
            await publishSoundAndScreenOutput()
            return
        }
    }
    
    private func emulationLoop(program: Chip8Program) async throws {
        await publishDebugInfo()
        await publishSoundAndScreenOutput()
        
        while !Task.isCancelled {
            if !isPlaying { continue }
            
            let timeStart = Date()
            for _ in 0..<systemCpuInstructionsCountPerFrame {
                if Task.isCancelled { return }
                
                try system.emulateSingleCycle()
                await publishDebugInfo()
            }
            
            let timeEnd = Date()
            let instructionsInterval: Double = timeEnd.timeIntervalSince(timeStart).magnitude
            
            // To ensure constant target frame time. We have to introduce sleep interval.
            let sleepPeriod = targetFrameTime > instructionsInterval ? targetFrameTime - instructionsInterval : 0
            try? await Task.sleep(nanoseconds: UInt64(sleepPeriod * 1_000_000_000))
            
            // Decrement timers every 1 / 60 seconds.
            system.decreaseDelayTimer()
            system.decreaseSoundTimer()
            
            await publishSoundAndScreenOutput()
        }
    }
    
    
    public func onKeyDown(_ key: EmulationControls.Chip8Key) {
        system.keyDown(key: key.rawValue)
    }

    public func onKeyUp(_ key: EmulationControls.Chip8Key) {
        system.keyUp(key: key.rawValue)
    }
    
    public func togglePause() async {
        isPlaying = !isPlaying
        await publishDebugInfo()
    }
    
    public func loadState(_ newState: EmulationState) {
        if program?.contentHash == newState.programContentHash {
            system.loadState(newState.systemState)
        }
    }
    
    public func stop() async {
        isPlaying = false;
        hasEmulationStarted = false;
        emulationTask?.cancel()
        await resetPublishers()
    }

    public func exportState() -> EmulationState? {
        guard let program = program else { return nil }
        return EmulationState(programContentHash: program.contentHash, systemState: system.state)
    }
    
    private func publishDebugInfo(error: Error? = nil) async {
        await MainActor.run {
            playingInfo = PlayingInfo(hasStarted: hasEmulationStarted, isPlaying: isPlaying)
            debugSystemStateInfo = system.state
            debugErrorInfo = error
        }
    }
    
    private func publishSoundAndScreenOutput() async {
        await MainActor.run {
            outputScreen = system.state.Output
            outputSoundTimer = system.state.soundTimer
        }
    }
    
    private func resetPublishers() async {
        await MainActor.run {
            outputScreen = Array(repeating: false, count: 64*32)
            outputSoundTimer = 0
            debugSystemStateInfo = nil
            debugErrorInfo = nil
            playingInfo = PlayingInfo(hasStarted: false, isPlaying: false)
        }
    }
}

public struct PlayingInfo: Equatable, Codable {
    public var hasStarted: Bool
    public var isPlaying: Bool
    
    public init(hasStarted: Bool, isPlaying: Bool) {
        self.hasStarted = hasStarted
        self.isPlaying = isPlaying
    }
    
    public static func == (lhs: PlayingInfo, rhs: PlayingInfo) -> Bool {
        return lhs.hasStarted == rhs.hasStarted &&
        lhs.isPlaying == rhs.isPlaying
    }
}
