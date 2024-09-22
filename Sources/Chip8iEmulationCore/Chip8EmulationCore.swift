//
//  Chip8EmulationCore.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 28.05.2024..
//

import Foundation

/// Emulation Core that should be used for starting emulation, sending inputs and subscribing to its screen and sound output. It also includes optional debug output info for advanced users. This is a ViewModel that creates execution loop and communicates with internal Chip8 program operations processing modules.
public class Chip8EmulationCore: ObservableObject {
    
    /// Internal Chip8 System/CPU that executes the commands
    private var system: Chip8System
    /// Loaded Chip8 Program
    private var program: Chip8Program?
    
    
    /// Number of instructions done in a second. Usually shown in Hz. Default for most programs is 700 Hz
    private var systemClockCount = 600
    /// Number of frames (frame rate) drawn per second. Standard for Chip8 is 60 Hz.
    private var targetSystemFrameCount = 60
    private var isPaused = false
    
    private let opCodeParser: Chip8OperationParserProtocol
    
    /// Output screen buffer 64 width x 32 height. Pixel can be 0 or 1. True is turned On and False is turned Off.
    /// One example of how to subscribe to this data is to create CGImage from it using fromMonochromeBitmap extension method and then show it in Image element.
    @Published public private(set) var outputScreen: [Bool] = Array(repeating: false, count: 64*32)
    /// Indicates if emulator should ply the sound. Returns (playSound, SoundTimerValue). If timer is greater than 0 playSound will be true.
    /// Important: On every change of timer value that is greater than 0 you should play short sound (tick).
    @Published public private(set) var outputSoundTimer: UByte = 0
    
    /// Debug Info about previous Operation Code and Operation parsed from it
    @Published public private(set) var debugPreviousCodeAndOperationInfo: (UShort, Chip8Operation)?
    /// Debug Info about current Chip8 System State
    @Published public private(set) var debugSystemStateInfo: Chip8SystemState?
    
    public init() {
        self.system = Chip8System()
        self.opCodeParser = Chip8OperationParser()
    }
    
    /// Starts emulation of the Chip8 program. Programs for Chip8 are executed indefinitely (infinite loop).
    ///
    /// Logger is by default EmulationConsoleLogger, to disable logging set it to nil, or replace it with your own implementation, for example logging into file.
    public func emulate(program: Chip8Program, logger: EmulationLoggerProtocol? = EmulationConsoleLogger()) async {

        self.system = Chip8System() // Reset the system
        self.program = program
        system.loadProgram(program.contentROM)
        
        while(true) {
            if isPaused { continue }
            let systemClockCountPerFrame = systemClockCount / targetSystemFrameCount
            
            let timeStart = Date()
            for _ in 0..<systemClockCountPerFrame {
                await emulateSingleCycle(logger: logger)
            }
            let timeEnd = Date()
            
            let performedInstructionsInterval: Double = timeEnd.timeIntervalSince(timeStart).magnitude
            let targetFrameTime: Double = 1.0 / Double(targetSystemFrameCount)
            
            /// To ensure constant target frame rate / frame time. we have to introduce sleep interval.
            let sleepPeriodForTargetFrameTime = targetFrameTime > performedInstructionsInterval ? targetFrameTime - performedInstructionsInterval : 0
            
            try? await Task.sleep(nanoseconds: UInt64(sleepPeriodForTargetFrameTime * 1_000_000_000))
            
            // TODO: what if it's different frequency for frame-rate and timers? timers in its own task...
            // Update timers
            system.decreaseDelayTimer()
            system.decreaseSoundTimer()
            
            await publishOutput()
            await publishSoundTimer()
        }
    }
    
    private func emulateSingleCycle(logger: EmulationLoggerProtocol?) async {
        // Fetch Opcode
        let opCode: UShort = system.fetchOperationCode(memoryLocation: system.state.pc)
        // Decode Opcode
        let operation = opCodeParser.decode(operationCode: opCode)
        logger?.log("Parsed \(opCode.hexDescription) -> \(operation)", level: .info)
        
        // Execute Operation
        system.executeOperation(operation: operation, logger: logger)
        
        // Send debug info
        await MainActor.run {
            debugSystemStateInfo = system.state
            debugPreviousCodeAndOperationInfo = (opCode, operation)
        }
    }
    
    /// Chip8 Gameplay key pressed down. See Chip8Key enum for more information.
    public func onKeyDown(key: EmulationControls.Chip8Key) {
        system.keyDown(key: key.rawValue)
    }

    /// Chip8 Gameplay key released. See Chip8Key enum for more information.
    public func onKeyUp(key: EmulationControls.Chip8Key) {
        system.keyUp(key: key.rawValue)
    }
    
    public func togglePause() {
        isPaused = !isPaused
    }
    
    /// Loads emulation state if it belongs to the current loaded program
    public func loadState(_ newState: EmulationState) {
        if program?.contentHash == newState.programContentHash {
            system.loadState(newState.systemState)
        }
    }
    
    /// Exports current Chip8SystemState so it can be saved in frontend app. Note: Saving and loading from files, internet etc. should be done in frontend depending on the OS.
    public func exportState() -> EmulationState? {
        guard let program = program else { return nil }
        return EmulationState(programContentHash: program.contentHash, systemState: system.state)
    }
    
    private func publishOutput() async {
        await MainActor.run {
            outputScreen = system.state.Output
        }
    }
    
    private func publishSoundTimer() async {
        await MainActor.run {
            outputSoundTimer = system.state.soundTimer
        }
    }
}
