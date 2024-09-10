//
//  SystemExtensions.swift
//  Chip8iEmulator
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
}

extension UByte {
    public var fullDescription: String {
        let bits = String(self, radix: 2).padding(toLength: 8, withPad: "0", startingAt: 0)
        return "\(String(format:"0x%02X", self))|0b\(bits)|\(self)"
    }
    
    public var hexDescription: String {
        return "\(String(format:"0x%02X", self))"
    }
}
