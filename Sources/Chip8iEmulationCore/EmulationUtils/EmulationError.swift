//
//  EmulationError.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 21.12.2024..
//

import Foundation

/// Errors that terminate the emulation
public enum EmulationError: LocalizedError, Equatable {
    case unknownOpcode(opcode: UShort)
    /// If address is not lower than 0xFFF or 4095 (operation code is 2 bytes so the second one will be out of bounds...)
    case opcodeFetchError(address: UShort)
    case unexpectedInterrupt
    
    public var errorDescription: String? {
        switch self {
        case .unknownOpcode(opcode: let opcode):
            return "Unknown opcode in program: \(opcode.hexDescription)"
        case .opcodeFetchError(address: let address):
            return "Opcode address not supported: \(address.hexDescription). Chip8 memory size is 4096 bytes."
        case .unexpectedInterrupt:
            return "Unexpected interrupt"
        }
    }
}
