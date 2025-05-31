//
//  Chip8EmulationCore.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 28.05.2024..
//

import Foundation
import QuartzCore

/// Emulation Core that should be used for starting emulation, sending inputs and subscribing to its screen and sound output. It also includes optional debug output info for advanced users.
/// This is a ViewModel that creates execution loop and communicates with internal Chip8 program operations processing modules.
@Observable
@MainActor
public final class Chip8EmulationCore: Chip8EmulationCoreProtocol {
    
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
    
    /// Number of instructions done in a second. Usually shown in Hz. Default for most programs is 700 Hz
    private var systemCpuFrequency: Int = 600
    /// Number of frames (frame rate) drawn per second. Standard for Chip8 is 60 Hz. Also this is frequency for decrementing timers.
    private var systemScreenAndTimersFrequency = 60

    // Observable public properties
    public fileprivate(set) var hasEmulationStarted = false
    /// Info about play status
    public fileprivate(set) var playingInfo: PlayingInfo = PlayingInfo(hasStarted: false, isPlaying: false)
    public fileprivate(set) var isPlaying = false {
        didSet {
            if oldValue != isPlaying {
                soundHandler?.onEmulationPause(isPaused: !isPlaying)
            }
        }
    }
    
    private var frameTimes: [Double] = []
    private var lastFrameUpdate: Date? = nil
    /// Output screen buffer 64 width x 32 height. Pixel can be 0 or 1. True is turned On and False is turned Off.
    /// One example of how to subscribe to this data is to create CGImage from it using fromMonochromeBitmap extension method and then show it in Image element.
    ///
    /// Structure includes last frame and frame rate information. Maximal frame rate is 60 frames per seconds.
    public fileprivate(set) var outputScreen: (screen: [Bool], fps: Double) = (Array(repeating: false, count: 64 * 32), 0)
    /// Indicates if emulator should play the sound. Returns (playSound, SoundTimerValue). If timer is greater than 0 playSound will be true.
    /// Important: On every change of timer if value is above 0 then beep should be played. Continuous sound should be played between the frames if value is still above 0, so looped continuous sound wave).
    /// When value  is 0 any playing sound should be stoped.
    public fileprivate(set) var outputSoundTimer: UByte = 0 {
        didSet {
            if oldValue != outputSoundTimer {
                self.soundHandler?.handleSoundTimerChange(soundTimer: outputSoundTimer)
            }
        }
    }
    
    
    /// Debug Info about current Chip8 System State.  This updates on every cpu cycle so be careful when observing it.
    public fileprivate(set) var debugSystemState: Chip8SystemState? = nil
    /// Debug Info about encountered error
    public fileprivate(set) var debugErrorInfo: Error? = nil

    /// Logger is disabled and nil by default, you can use EmulationConsoleLogger, or replace it with your own implementation, for example logging into file.
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
        

    }

    public func startEmulation(_ program: Chip8Program) async {
        await resetPublishers(lastState: await system.exportState())
        self.system = Chip8System(parser: opCodeParser, logger: logger)  // Reset the system
        self.program = program
        
        setHasEmulationStarted(true)
        setIsPlaying(true)


        await system.loadFont()
        await system.loadProgram(program.contentROM)

        // Launch and store emulationTask
        emulationTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                try await self?.emulationLoop(program: program)
            } catch {
                guard let self = self else { return }
                await self.logger?.log("Stopping the emulation because error was thrown: \(error). Debug information sent to publishers.",
                    level: .error)
                
                await self.publishDebugInfo(hasStarted: hasEmulationStarted, isPlaying: isPlaying, error: error)
                await self.publishSoundAndScreenOutput(lastState: await system.exportState())
            }
        }
        

    }

    /// This method should not be executed on main thread, hence usage of `nonisolated` since this class is `@MainActor`
    nonisolated private func emulationLoop(program: Chip8Program) async throws {
        await publishDebugInfo(hasStarted: self.hasEmulationStarted, isPlaying: self.isPlaying, error: nil)
        await publishSoundAndScreenOutput(lastState: await system.exportState())
        
        let targetFrameTime = await 1.0 / Double(systemScreenAndTimersFrequency)
        let systemCpuInstructionsCountPerFrame: Int = await (systemCpuFrequency) / (systemScreenAndTimersFrequency)

        while !Task.isCancelled {
            if await !isPlaying { continue }
            let startTime = CACurrentMediaTime()
            
            for _ in 0..<systemCpuInstructionsCountPerFrame {
                if Task.isCancelled { return }

                try await system.emulateSingleCycle()
                await publishDebugInfo(hasStarted: self.hasEmulationStarted, isPlaying: self.isPlaying, error: nil)
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

            let lastState = await system.exportState()
            await publishSoundAndScreenOutput(lastState: lastState)
        }
    }

    public func onKeyDown(_ key: Chip8Key) async {
        await system.keyDown(key: key.rawValue)
    }

    public func onKeyUp(_ key: Chip8Key) async {
        await system.keyUp(key: key.rawValue)
    }

    public func togglePause() async {
        setIsPlaying(!isPlaying)
        await publishDebugInfo(hasStarted: self.hasEmulationStarted, isPlaying: self.isPlaying, error: nil)
    }

    public func loadState(_ newState: EmulationState) async {
        if program?.contentHash == newState.programContentHash {
            await system.loadState(newState.systemState)
        }
    }

    public func stop() async {
        setIsPlaying(false)
        setHasEmulationStarted(false)
        emulationTask?.cancel()
        let lastState = await system.exportState()
        await system.reset()
        await resetPublishers(lastState: lastState)
    }

    public func exportState() async -> EmulationState? {
        guard let program = program else { return nil }
        return EmulationState(
            programContentHash: program.contentHash, systemState: await system.exportState())
    }
    
    private func setIsPlaying(_ newValue: Bool) {
        isPlaying = newValue
        if (newValue) {
            // on resume reset the frame times
            frameTimes.removeAll()
            self.lastFrameUpdate = nil
        }
    }
    
    private func setHasEmulationStarted(_ newValue: Bool) {
        hasEmulationStarted = newValue
    }
}


// ex. Publishers, now observable properties extension, update of these properties must be done in main thread
extension Chip8EmulationCore {
    internal func publishDebugInfo(hasStarted: Bool, isPlaying: Bool, error: Error?) async {
        playingInfo = PlayingInfo(
            hasStarted: hasEmulationStarted, isPlaying: isPlaying)
        debugSystemState = await system.exportState()
        debugErrorInfo = error
    }
    
    internal func publishSoundAndScreenOutput(lastState: Chip8SystemState) async {
        let fps = getFps()
        outputScreen = (lastState.output, fps)
        outputSoundTimer = lastState.soundTimer
    }
    
    private func getFps() -> Double {
        guard let lastFrameUpdate = self.lastFrameUpdate else {
            self.lastFrameUpdate = Date()
            return 0;
        }
        
        let now = Date()
        let frameTime = now.timeIntervalSince(lastFrameUpdate)
        
        if frameTimes.count == 60 {
            frameTimes.removeFirst()
        }

        frameTimes.append(frameTime)
        let avgFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
        let fps = 1.0 / avgFrameTime

        self.lastFrameUpdate = now
        
        return fps;
    }

    internal func resetPublishers(lastState: Chip8SystemState) async {
        outputScreen = (Array(repeating: false, count: 64 * 32), 0)
        outputSoundTimer = 0
        debugSystemState = lastState
        debugErrorInfo = nil
        playingInfo = PlayingInfo(hasStarted: false, isPlaying: false)
    }
}
