//
//  Chip8EmulationCore.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 28.05.2024..
//

import Foundation


/// Emulation Core that should be used for starting emulation, sending inputs and subscribing to its screen output.
public class Chip8EmulationCore: ObservableObject { // TODO: Refactor... target app should insert all those parameters
    private var system: Chip8System
    /// Number of instructions done in a second. Usually shown in Hz. Default for most programs is 700 Hz
    private var systemClockCount = 600
    /// Number of frames (frame rate) drawn per second. Standard for Chip8 is 60 Hz.
    private var targetSystemFrameCount = 60
    private var isPaused = false
    
    private let opCodeParser: Chip8OperationParserProtocol
    
    /// Output screen buffer 64 width x 32 height. Pixel can be 0 or 1. True is turned On and False is turned Off.
    @Published var outputScreen: [Bool] = Array(repeating: false, count: 64*32)
    /// Indicates if emulator should ply the sound. Returns (playSound, SoundTimerValue). If timer is greater than 0 playSound will be true.
    /// Important: On every change of timer value that is greater than 0 you should play short sound (tick).
    @Published var outputSoundTimer: UByte = 0
    
    /// Input keys bindings for emulation menu actions EmulationMenuControl like Pause, SaveState, etc. Initially set to DefaultEmulationMenuKeyboardBindings
    public var EmulationMenuBindings: Dictionary<Character, EmulationMenuControl> = DefaultEmulationMenuKeyboardBindings
    /// Input keys bindings for Chip8 keys. Chip8 has 16 keys (0 to F). Initially set to DefaultChip8KeyboardBindings
    public var Chip8InputBindings: Dictionary<Character, UByte> = DefaultChip8KeyboardBindings
    
    init() {
        self.system = Chip8System()
        self.opCodeParser = Chip8OperationParser()
    }
    
    /// Start emulation of the Chip8 program
    public func emulate(programName: String) async {
        // TODO: refactor this... easier, pause, resume, execute command by command(what about delay and sound timer...), load, save...
        // Set up render system and register input callbacks
        
        let program = readProgramFromFile(fileName: programName)
        guard let program = program else { return }
        
        system.loadProgram(program.contentROM)
        
        while(true) {
            if isPaused { continue }
            let systemClockCountPerFrame = systemClockCount / targetSystemFrameCount
            
            let timeStart = Date()
            for _ in 0..<systemClockCountPerFrame {
                await emulateSingleCycle()
            }
            let timeEnd = Date()
            
            let performedInstructionsInterval: Double = timeEnd.timeIntervalSince(timeStart).magnitude
            let targetFrameTime: Double = 1.0 / Double(targetSystemFrameCount)
            
            /// To ensure constant target frame rate / frame time. we have to introduce sleep interval.
            let sleepPeriodForTargetFrameTime = targetFrameTime > performedInstructionsInterval ? targetFrameTime - performedInstructionsInterval : 0
            
            try? await Task.sleep(nanoseconds: UInt64(sleepPeriodForTargetFrameTime * 1_000_000_000)) // TODO: refactor
            
            // TODO: what if it's different frequency for frame-rate and timers?
            // TODO: (timers in its own task...)
            // Update timers
            system.decreaseDelayTimer()
            system.decreaseSoundTimer()
            
            await publishOutput()
            await publishSoundTimer()
        }
    }
    
    private func emulateSingleCycle() async {
        // Fetch Opcode
        let opCode: UShort = system.fetchOperationCode(memoryLocation: system.state.pc)
        // Decode Opcode
        let operation = opCodeParser.decode(operationCode: opCode)
        print("\(opCode.hexDescription) -> \(operation)")
        // Execute Opcode
        system.executeOperation(operation: operation)
    }
    
    private func readProgramFromFile(fileName: String) -> Chip8ProgramROM? {
        guard let fileUrl = Bundle.main.url(forResource: fileName, withExtension: Chip8ProgramROM.fileExtension) else { return nil }
        guard let data = try? Data(contentsOf: fileUrl) else { return nil }
        // print(data.flatMap{String(format:"%02X", $0)})
        let romData = data.compactMap {$0}
        return Chip8ProgramROM(name: fileName, contentROM: romData)
    }
    
    private func publishOutput() async {
        await MainActor.run {
            outputScreen = system.state.Output.map { byte in byte > 0 }
        }
    }
    
    private func publishSoundTimer() async {
        await MainActor.run {
            outputSoundTimer = system.state.soundTimer
        }
    }
    
    public func onKeyDown(key: Character) {
        if let chip8Key = Chip8InputBindings[key] {
            system.KeyDown(key: chip8Key)
        }
    }

    public func onKeyUp(key: Character) {
        if let chip8Key = Chip8InputBindings[key] {
            system.KeyUp(key: chip8Key)
        }
        else if let menuButtonPressed = EmulationMenuBindings[key] {
            switch menuButtonPressed {
                case .Pause:
                    isPaused = !isPaused
                default:
                    return
            }
        }
    }
}

/// Represents compiled program for Chip8 system. Compiled program binary data is saved in .ch8 files.
public struct Chip8ProgramROM {
    public static let fileExtension = "ch8"
    
    public let name: String
    /// Read Only Memory - ROM binary content of the compiled program
    public let contentROM: [UByte]
}

public enum EmulationMenuControl {
    case Pause
// TODO: Implement
//    case FastForward
//    case SaveState
//    case LoadState
//    case Rewind // maybe later on...
}
