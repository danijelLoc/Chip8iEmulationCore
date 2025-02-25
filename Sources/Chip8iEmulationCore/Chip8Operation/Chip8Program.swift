//
//  Chip8Program.swift
//
//
//  Created by Danijel Stracenski on 14.09.2024..
//

import Foundation
import CryptoKit

/// Represents compiled program for Chip8 system, for example game "Pong". Compiled program binary data can be loaded from .ch8 files for example.
/// Compiled program binary data aka machine code includes operation codes and sprites.
public struct Chip8Program: Equatable {
    /// Name of the program, used for list of programs in emulator frontend for example
    public let name: String
    /// Read Only Memory - ROM binary content of the compiled program
    public let contentROM: [UByte]
    /// Unique content Id from the hash of ROM binary. Calculated with SHA256
    public let contentHash: String
    
    public init(name: String, contentROM: [UByte]) {
        self.name = name
        self.contentROM = contentROM
        self.contentHash = Chip8Program.calculateContentHash(from: contentROM)
    }
    
    public static func calculateContentHash(from contentData: [UByte]) -> String {
        // Convert [UByte] to Data
        let data = Data(contentData)
        
        // Use SHA256 to hash the data
        let hash = SHA256.hash(data: data)
        
        // Convert the hash to a hex string
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }
    
    public static func == (lhs: Chip8Program, rhs: Chip8Program) -> Bool {
        return lhs.contentHash == rhs.contentHash
    }
}
