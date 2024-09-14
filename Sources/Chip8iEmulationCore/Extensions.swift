//
//  SystemExtensions.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 10.09.2024..
//

import Foundation

extension UShort {
    public var fullDescription: String {
        let bits = String(self, radix: 2).padding(toLength: 16, withPad: "0", startingAt: 0)
        return "\(String(format:"0x%04X", self))|0b\(bits)|\(self)"
    }
    
    public var hexDescription: String {
        return "\(String(format:"0x%04X", self))"
    }
    
    public var toInt: Int {
        return Int(self)
    }
}

extension UByte {
    public var fullDescription: String {
        let bits = String(self, radix: 2).padding(toLength: 8, withPad: "0", startingAt: 0)
        return "\(String(format:"0x%02X", self))|0b\(bits)|\(self)"
    }
    
    public var hexDescription: String {
        return "\(String(format:"0x%02X", self))"
    }
    
    public var toInt: Int {
        return Int(self)
    }
}

extension Bool {
    public func xor(other: Bool) -> Bool {
        return other != self;
    }
    
    /// Returns true for 1, false for 0. Otherwise throws error.
    public static func fromOneOrZero(_ value: UByte) ->  Bool {
        if value > 1 {
            fatalError("Method expects 1 or 0")
        } else if value == 1 {
            return true;
        } else {
            return false;
        }
    }
}
