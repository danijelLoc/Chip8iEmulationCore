//
//  EmulationLogger.swift
//
//
//  Created by Danijel Stracenski on 14.09.2024..
//

import Foundation

/// Protocol that defines method for logging emulation messages. Custom implementations are supported in Chip8EmulationCore.emulate method.
public protocol EmulationLoggerProtocol {
    func log(_ message: String, level: EmulationLogLevel)
}

/// A simple console logger that prints emulation log messages in the console.
public class EmulationConsoleLogger: EmulationLoggerProtocol {
    private let includedLevels: [EmulationLogLevel]
    
    /// Included levels can be customised. If level is not included, its messages will not be logged into console.
    public init(includedLevels: [EmulationLogLevel] = [.error, .warning, .info]) {
        self.includedLevels = includedLevels
    }

    public func log(_ message: String, level: EmulationLogLevel) {
        if includedLevels.contains(where: { includedLevel in includedLevel == level }) {
            print("[\(level.rawValue)] \(message)")
        }
    }
    
    /// Helper method that returns multi-row string representation of screen buffer. Useful for debugging
    public static func getStringOutput(_ pixels: [Bool], width: Int, height: Int) -> String {
        var output = ""
        for i in 0..<height {
            var rowString = ""
            for j in 0..<width {
                let index = i * width + j
                rowString += pixels[index] ? "██" : "{}"
            }
            output = output + rowString + "\n"
        }
        
        return output
    }
}

/// Errors that terminate the emulation
public enum EmulationError: Error, Equatable {
    case unknownOpcode(opcode: UShort)
    /// If address is not lower than 0xFFF or 4095 (operation code is 2 bytes so the second one will be out of bounds...)
    case opcodeFetchError(address: UShort)
}

/// Enum to define different emulation logging levels.
public enum EmulationLogLevel: String {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}
