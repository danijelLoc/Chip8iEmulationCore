//
//  Chip8ProgramROM.swift
//
//
//  Created by Danijel Stracenski on 14.09.2024..
//

import Foundation

/// Represents compiled program for Chip8 system, for example game "Pong". Compiled program binary data can be loaded from .ch8 files for example.
public struct Chip8Program {
    /// Name of the program, used for list of programs in emulator frontend for example
    public let name: String
    /// Read Only Memory - ROM binary content of the compiled program
    public let contentROM: [UByte]
    
    public init(name: String, contentROM: [UByte]) {
        self.name = name
        self.contentROM = contentROM
    }
}
