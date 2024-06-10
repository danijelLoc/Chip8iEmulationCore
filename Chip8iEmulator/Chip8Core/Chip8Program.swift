//
//  Chip8Program.swift
//  Chip8iEmulator
//
//  Created by Danijel Stracenski on 09.06.2024..
//

import Foundation

struct Chip8Program {
    public static let fileExtension = "ch8"
    
    public let name: String
    public let contentROM: [UByte] // Read Only Memory - ROM binary content of the compiled program
}
