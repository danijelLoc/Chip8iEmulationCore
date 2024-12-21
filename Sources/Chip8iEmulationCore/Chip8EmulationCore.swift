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
    /// Important: On every change of timer value that is greater than 0 you should play short sound (tick).
    var outputSoundTimerPublisher: Published<UByte>.Publisher { get }
    
    /// A publisher that emits changes to the debugSystemStateInfo value.
    var debugSystemStateInfoPublisher: Published<Chip8SystemState?>.Publisher { get }
    
    /// Debug Info about encountered error
    var debugErrorInfoPublisher: Published<Error?>.Publisher { get }
    
    
    /// Starts emulation of the Chip8 program. Programs for Chip8 are executed indefinitely (infinite loop).
    ///
    /// Logger is by default EmulationConsoleLogger, to disable logging set it to nil, or replace it with your own implementation, for example logging into file.
    func emulate(program: Chip8Program) async
    
    
    /// Pause and resume the emulation of the Chip8 program
    func togglePause()
    
    /// Stops running emulation of the Chip8 program
    func stop()
    
    /// Loads emulation state if it belongs to the current loaded program
    func loadState(_ newState: EmulationState)
    
    /// Exports current Chip8SystemState so it can be saved in frontend app. Note: Saving and loading from files, internet etc. should be done in frontend depending on the OS.
    func exportState() -> EmulationState?
    
    /// Chip8 Gameplay key pressed down. See Chip8Key enum for more information.
    func onKeyDown(key: EmulationControls.Chip8Key)
    
    /// Chip8 Gameplay key released. See Chip8Key enum for more information.
    func onKeyUp(key: EmulationControls.Chip8Key)
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
    private var systemClockFrequency: Int = 600
    /// Number of frames (frame rate) drawn per second. Standard for Chip8 is 60 Hz.
    private var systemFrameCount = 60
    private var systemClockInstructionsCountPerFrame: Int  { systemClockFrequency / systemFrameCount }
    
    /// Delay and Sound timers decrement rate. Standard for Chip8 is 60 Hz.
    private var systemTimersFrequency = 60
    
    private var isPaused = false
    private var emulationTask: Task<Void, Error>?
    private var timersDecrementTask: Task<Void, Error>?
    
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
    
    // Publishers
    public var outputScreenPublisher: Published<[Bool]>.Publisher { $outputScreen }
    public var outputSoundTimerPublisher: Published<UByte>.Publisher { $outputSoundTimer}
    public var debugSystemStateInfoPublisher: Published<Chip8SystemState?>.Publisher { $debugSystemStateInfo }
    public var debugErrorInfoPublisher: Published<Error?>.Publisher { $debugErrorInfo }
    
    public init(parser: Chip8OperationParserProtocol = Chip8OperationParser(), logger: EmulationLoggerProtocol? = EmulationConsoleLogger()) {
        self.logger = logger
        self.opCodeParser = parser
        self.system = Chip8System(parser: parser, logger: logger)

    }
    
    public func emulate(program: Chip8Program) async {
        do {
            await resetPublishers()
            self.system = Chip8System(parser: opCodeParser, logger: logger) // Reset the system
            self.program = program
            self.isPaused = false
            
            system.loadProgram(program.contentROM)
            emulationTask = Task { try await emulationLoop(program: program) }
            timersDecrementTask = Task { try await timersDecrementLoop() }
            
            try await emulationTask?.value
            try await timersDecrementTask?.value

        } catch let error {
            logger?.log("Stopping the emulation because error was thrown: \(error). Debug information sent to publishers.", level: .error)
            await publishInfo(error: error)
            return
        }
    }
    
    private func emulationLoop(program: Chip8Program) async throws {
        while !Task.isCancelled {
            if isPaused { continue }
            
            let timeStart = Date()
            for _ in 0..<systemClockInstructionsCountPerFrame {
                try system.emulateSingleCycle()
            }
            
            let timeEnd = Date()
            let performedInstructionsInterval: Double = timeEnd.timeIntervalSince(timeStart).magnitude
            let targetFrameTime: Double = 1.0 / Double(systemFrameCount)
            
            /// To ensure constant target frame time. we have to introduce sleep interval.
            let sleepPeriod = targetFrameTime > performedInstructionsInterval ? targetFrameTime - performedInstructionsInterval : 0
            try? await Task.sleep(nanoseconds: UInt64(sleepPeriod * 1_000_000_000))
            
            await publishInfo()
        }
    }
    
    private func timersDecrementLoop() async throws {
        while !Task.isCancelled {
            if isPaused { continue }
            // Decrement timers
            system.decreaseDelayTimer()
            system.decreaseSoundTimer()
            let interval = 1.0 / Double(systemTimersFrequency)
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }
    
    
    public func onKeyDown(key: EmulationControls.Chip8Key) {
        system.keyDown(key: key.rawValue)
    }

    public func onKeyUp(key: EmulationControls.Chip8Key) {
        system.keyUp(key: key.rawValue)
    }
    
    public func togglePause() {
        isPaused = !isPaused
    }
    
    public func loadState(_ newState: EmulationState) {
        if program?.contentHash == newState.programContentHash {
            system.loadState(newState.systemState)
        }
    }
    
    public func stop() {
        emulationTask?.cancel()
        timersDecrementTask?.cancel()
    }

    public func exportState() -> EmulationState? {
        guard let program = program else { return nil }
        return EmulationState(programContentHash: program.contentHash, systemState: system.state)
    }
    
    private func publishInfo(error: Error? = nil) async {
        await MainActor.run {
            outputScreen = system.state.Output
            outputSoundTimer = system.state.soundTimer
            
            debugSystemStateInfo = system.state
            debugErrorInfo = error
        }
    }
    
    private func resetPublishers() async {
        await MainActor.run {
            outputScreen = Array(repeating: false, count: 64*32)
            outputSoundTimer = 0
            debugSystemStateInfo = nil
            debugErrorInfo = nil
        }
    }
}
