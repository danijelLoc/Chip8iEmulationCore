//
//  Chip8EmuCore.swift
//  Chip8iEmulator
//
//  Created by Danijel Stracenski on 28.05.2024..
//

import Foundation


class Chip8EmuCore: ObservableObject {
    private var system: Chip8System
    
    @Published var outputScreen: [UByte] = Array(repeating: 0, count: 64*32)
    
    init() {
        self.system = Chip8System()
    }
    
    public func emulate() async {
        // Set up render system and register input callbacks
        setupInput();
        
        let program = readProgramFromFile(fileName: "DisplayTest")
        guard let program = program else { return }
        
        system.loadProgram(program.contentROM)
        
        while(true) {
            await system.emulateCycle()
            
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
        
    }
    
    private func showOutput() async {
        await MainActor.run {
            outputScreen = system.Output
        }

    }
    
    ///
    /// Chip8 only supports font with 16 letters  (0,1,...,9,A,....F)
    /// Reasons: memory constraints and input that also has 16 keys, so Hexadecimal digits were chosen for default font.
    /// This font is saved in RAM and can then be replaced by game ROM when executed.
    ///
    public static let DefaultFontSet: [UByte] = [
        0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
        0x20, 0x60, 0x20, 0x20, 0x70, // 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
        0x90, 0x90, 0xF0, 0x10, 0x10, // 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
        0xF0, 0x10, 0x20, 0x40, 0x40, // 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, // A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
        0xF0, 0x80, 0x80, 0x80, 0xF0, // C
        0xE0, 0x90, 0x90, 0x90, 0xE0, // D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
        0xF0, 0x80, 0xF0, 0x80, 0x80  // F
    ]
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
