//
//  Chip8EmulationCore.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 28.05.2024..
//

import Foundation
import QuartzCore
import Combine

/// Emulation Core that should be used for starting emulation, sending inputs and subscribing to its screen and sound output. It also includes optional debug output info for advanced users.
/// This is a ViewModel that creates execution loop and communicates with internal Chip8 program operations processing modules.
public class Chip8EmulationCore: Chip8EmulationCoreProtocol {
    
    /// Internal Chip8 System/CPU that executes the commands
    private var system: Chip8System
    /// Internal Sound Handler
    private let soundHandler: SoundHandlerProtocol?
    /// Internal parser used for Chip8 operation codes
    private let opCodeParser: Chip8OperationParserProtocol
    private var logger: EmulationLoggerProtocol?
    
    /// Loaded Chip8 Program
    private var program: Chip8Program?
    private var emulationTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()

    /// Number of instructions done in a second. Usually shown in Hz. Default for most programs is 700 Hz
    private var systemCpuFrequency: Int = 600
    /// Number of frames (frame rate) drawn per second. Standard for Chip8 is 60 Hz. Also this is frequency for decrementing timers.
    private var systemScreenAndTimersFrequency = 60

    @Published internal fileprivate(set) var hasEmulationStarted = false
    @Published internal fileprivate(set) var isPlaying = false
    /// Output screen buffer 64 width x 32 height. Pixel can be 0 or 1. True is turned On and False is turned Off.
    /// One example of how to subscribe to this data is to create CGImage from it using fromMonochromeBitmap extension method and then show it in Image element.
    @Published internal fileprivate(set) var outputScreen: [Bool] = Array(
        repeating: false, count: 64 * 32)
    /// Indicates if emulator should play the sound. Returns (playSound, SoundTimerValue). If timer is greater than 0 playSound will be true.
    /// Important: On every change of timer if value is above 0 then beep should be played. Continuous sound should be played between the frames if value is still above 0, so looped continuous sound wave).
    /// When value  is 0 any playing sound should be stoped.
    @Published internal fileprivate(set) var outputSoundTimer: UByte = 0
    /// Debug Info about current Chip8 System State
    @Published internal fileprivate(set) var debugSystemState: Chip8SystemState?
    /// Debug Info about encountered error
    @Published internal fileprivate(set) var debugErrorInfo: Error?
    /// Info about play status
    @Published internal fileprivate(set) var playingInfo: PlayingInfo = PlayingInfo(hasStarted: false, isPlaying: false)


    /// Logger is by default EmulationConsoleLogger, to disable logging set it to nil, or replace it with your own implementation, for example logging into file.
    public init(
        parser: Chip8OperationParserProtocol = Chip8OperationParser(),
        soundHandler: SoundHandlerProtocol? = nil,
        logger: EmulationLoggerProtocol? = nil
    ) {
        self.opCodeParser = parser
        self.soundHandler = soundHandler
        self.logger = logger
        
        let system = Chip8System(parser: parser, logger: logger)
        self.system = system
        self.debugSystemState = nil
        self.debugErrorInfo = nil
        
        $outputSoundTimer.removeDuplicates().sink { newValue in
            soundHandler?.handleSoundTimerChange(soundTimer: newValue)
        }
        .store(in: &cancellables)
        
        $isPlaying.removeDuplicates().sink { newValue in
            soundHandler?.onEmulationPause(isPaused: !newValue)
        }
        .store(in: &cancellables)
    }

    public func emulate(_ program: Chip8Program) async {
        do {
            await resetPublishers()
            self.system = Chip8System(parser: opCodeParser, logger: logger)  // Reset the system
            self.program = program
            self.hasEmulationStarted = true
            self.isPlaying = true

            await system.loadFont()
            await system.loadProgram(program.contentROM)

            emulationTask = Task.detached(priority: .userInitiated) {
                try await self.emulationLoop(program: program)
            }
            try await emulationTask?.value

        } catch let error {
            logger?.log(
                "Stopping the emulation because error was thrown: \(error). Debug information sent to publishers.",
                level: .error)
            await publishDebugInfo(error: error)
            await publishSoundAndScreenOutput()
            return
        }
    }

    private func emulationLoop(program: Chip8Program) async throws {
        await publishDebugInfo()
        await publishSoundAndScreenOutput()
        
        let targetFrameTime = 1.0 / Double(systemScreenAndTimersFrequency)
        let systemCpuInstructionsCountPerFrame: Int = systemCpuFrequency / systemScreenAndTimersFrequency

        while !Task.isCancelled {
            if !isPlaying { continue }
            isPlaying = true
            let startTime = CACurrentMediaTime()
            
            for _ in 0..<systemCpuInstructionsCountPerFrame {
                if Task.isCancelled { return }

                try await system.emulateSingleCycle()
                await publishDebugInfo()
            }
            
            // Introduce waiting delay to reach target frame time...
            while true {
                let elapsed = CACurrentMediaTime() - startTime
                if elapsed >= targetFrameTime * 0.99 {
                    break
                }
            }

            // Decrement timers every 1 / 60 seconds.
            await system.decreaseDelayTimer()
            await system.decreaseSoundTimer()

            await publishSoundAndScreenOutput()
        }
    }

    public func onKeyDown(_ key: Chip8Key) {
        Task {
            await system.keyDown(key: key.rawValue)
        }

    }

    public func onKeyUp(_ key: Chip8Key) {
        Task {
            await system.keyUp(key: key.rawValue)
        }
    }

    public func togglePause() {
        Task {
            isPlaying = !isPlaying
            await publishDebugInfo()
        }
    }

    public func loadState(_ newState: EmulationState) {
        Task {
            if program?.contentHash == newState.programContentHash {
                await system.loadState(newState.systemState)
            }
        }
    }

    public func stop() {
        Task {
            isPlaying = false
            hasEmulationStarted = false
            emulationTask?.cancel()
            await system.reset()
            await resetPublishers()
        }
    }

    public func exportState() async -> EmulationState? {
        guard let program = program else { return nil }
        return EmulationState(
            programContentHash: program.contentHash, systemState: await system.exportState())
    }
}


// Publishers extension
extension Chip8EmulationCore {
    public var outputScreenPublisher: Published<[Bool]>.Publisher { $outputScreen }
    public var debugSystemStateInfoPublisher: Published<Chip8SystemState?>.Publisher { $debugSystemState }
    public var debugErrorInfoPublisher: Published<Error?>.Publisher { $debugErrorInfo }
    public var playingInfoPublisher: Published<PlayingInfo>.Publisher { $playingInfo }
    
    internal func publishDebugInfo(error: Error? = nil) async {
        playingInfo = PlayingInfo(
            hasStarted: hasEmulationStarted, isPlaying: isPlaying)
        debugSystemState = await system.exportState()
        debugErrorInfo = error
    }

    internal func publishSoundAndScreenOutput() async {
        outputScreen = await system.exportState().output
        outputSoundTimer = await system.exportState().soundTimer
    }

    internal func resetPublishers() async {
        outputScreen = Array(repeating: false, count: 64 * 32)
        outputSoundTimer = 0
        debugSystemState = await system.exportState()
        debugErrorInfo = nil
        playingInfo = PlayingInfo(hasStarted: false, isPlaying: false)
    }
}
