//
//  Chip8EmuCore.swift
//  Chip8iEmulator
//
//  Created by Danijel Stracenski on 28.05.2024..
//

import Foundation

enum EmulationMenuControl {
    case Pause
    case FastForward
    case SaveState
    case LoadState
    case Rewind
}


class Chip8EmuCore: ObservableObject { // TODO: Refactor... target app should insert all those parameters
    private var system: Chip8System
    /// Number of instructions done in a second. Usually shown in Hz. Default for most programs is 700 Hz
    private var systemClockCount = 600
    /// Number of frames (frame rate) drawn per second. Standard for Chip8 is 60 Hz.
    private var targetSystemFrameCount = 60
    private var isPaused = false
    
    @Published var outputScreen: [UByte] = Array(repeating: 0, count: 64*32)
    
    private(set) var EmulationMenuBindings: Dictionary<Character, EmulationMenuControl> = Dictionary() // TODO: CUSTOM SETUP SCREEN
    private(set) var Chip8InputBindings: Dictionary<UByte, Character> = Dictionary() // TODO: CUSTOM SETUP SCREEN
    
    init() {
        self.system = Chip8System(opCodeParser: Chip8OperationParser())
    }
    
    public func emulate(_ programName: String) async {
        // Set up render system and register input callbacks
        setupInput();
        
        let program = readProgramFromFile(fileName: programName)
        guard let program = program else { return }
        
        system.loadProgram(program.contentROM)
        
        while(true) {
            if isPaused { continue }
            let systemClockCountPerFrame = systemClockCount / targetSystemFrameCount
            
            let timeStart = Date()
            for _ in 0..<systemClockCountPerFrame {
                await system.emulateCycle()
            }
            let timeEnd = Date()
            
            let performedInstructionsInterval: Double = timeEnd.timeIntervalSince(timeStart).magnitude
            let targetFrameTime: Double = 1.0 / Double(targetSystemFrameCount)
            
            /// To ensure constant target frame rate / frame time. we have to introduce sleep interval.
            let sleepPeriodForTargetFrameTime = targetFrameTime > performedInstructionsInterval ? targetFrameTime - performedInstructionsInterval : 0
            
            try? await Task.sleep(nanoseconds: UInt64(sleepPeriodForTargetFrameTime * 1_000_000_000))
            await showOutput()
        }
    }
    
    private func readProgramFromFile(fileName: String) -> Chip8Program? {
        guard let fileUrl = Bundle.main.url(forResource: fileName, withExtension: Chip8Program.fileExtension) else { return nil }
        guard let data = try? Data(contentsOf: fileUrl) else { return nil }
        // print(data.flatMap{String(format:"%02X", $0)})
        let romData = data.compactMap {$0}
        return Chip8Program(name: fileName, contentROM: romData)
    }
    
    private func setupInput() {
        Chip8InputBindings = [1: "1", 2: "2", 3: "3", 0xC: "1", 4: "q", 5: "w", 6: "e", 0xD: "r", 7: "a", 8: "s", 9: "d", 0xE: "f", 0xA: "y", 0: "x", 0xB: "c", 0xF: "v"] // TODO: SWAP
        EmulationMenuBindings = ["p": .Pause, "l": .FastForward]
    }
    
    private func showOutput() async {
        await MainActor.run {
            outputScreen = system.Output
        }

    }
    
    func onKeyDown(key: Character) {

    }

    func onKeyUp(key: Character) {
        let menuButtonPressed = EmulationMenuBindings[key]
        switch menuButtonPressed {
            case .Pause:
                isPaused = !isPaused
            default:
                return
        }
    }
}

///
/// Represents compiled program for Chip8 system. Compiled program binary data is saved in .ch8 files.
///
struct Chip8Program {
    public static let fileExtension = "ch8"
    
    public let name: String
    /// Read Only Memory - ROM binary content of the compiled program
    public let contentROM: [UByte]
}
