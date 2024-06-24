//
//  Chip8Operation.swift
//  Chip8iEmulator
//
//  Created by Danijel Stracenski on 24.06.2024..
//

import Foundation

public enum Chip8Operation {
    case ClearScreen
    case Jump(location: UShort)
    case SetValueToRegister(registerNumber: Int, value: UByte)
    case AddValueToRegister(registerNumber: Int, value: UByte)
    case SetValueToIndexRegister(value: UShort)
    case DrawSprite(height: Int, registerX: Int, registerY: Int)
    
    
    static func decode(operationCode: UShort) -> Chip8Operation? {
        switch (operationCode & 0xF000) {
        case 0x0000:
            return .ClearScreen
        case 0x1000: // 1NNN - jump (set PC to NNN)
            let location = operationCode & 0x0FFF
            return .Jump(location: location)
        case 0x6000: // 6XNN - set value NN to register X
            let registerNumber = Int((operationCode & 0x0F00) >> 8)
            let value = UByte(operationCode & 0x00FF)
            return .SetValueToRegister(registerNumber: registerNumber, value: value)
        case 0x7000: // 7XNN - add value NN to register X
            let registerNumber = Int((operationCode & 0x0F00) >> 8)
            let value = UByte(operationCode & 0x00FF)
            return .AddValueToRegister(registerNumber: registerNumber, value: value)
        case 0xA000: // ANNN - set value NNN to Index register
            let value = UShort(operationCode & 0x0FFF)
            return .SetValueToIndexRegister(value: value)
        case 0xD000: // DXYN - draws N pixels tall sprite from memory location that Index register has onto screen at location pX = value of X register, pY= value of Y register
            let registerX = Int((operationCode & 0x0F00) >> 8)
            let registerY = Int((operationCode & 0x00F0) >> 4)
            let height = Int(operationCode & 0x000F)
            return .DrawSprite(height: height, registerX: registerX, registerY: registerY)
        default:
            print("Unknown operation code \(String(format:"%02X", operationCode))")
            return nil
        }
    }
}
