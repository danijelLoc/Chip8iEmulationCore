//
//  Chip8Operation.swift
//  Chip8iEmulator
//
//  Created by Danijel Stracenski on 24.06.2024..
//

import Foundation



public enum Chip8Operation {
    case ClearScreen
    
    case CallSubroutine(address: UShort)
    case ReturnFromSubroutine
    case Jump(address: UShort)
    
    case ConditionalSkipRegisterValue(registerIndex: Int, value: UByte, isEqual: Bool)
    case ConditionalSkipRegisters(registerXIndex: Int, registerYIndex: Int, isEqual: Bool)
    
    case SetValueToRegister(registerIndex: Int, value: UByte)
    case AddValueToRegister(registerIndex: Int, value: UByte)
    case SetValueToIndexRegister(value: UShort)
    
    case RegistersOperation(registerXIndex: Int, registerYIndex: Int, operation: RegistersOperation)
    
    case DrawSprite(height: Int, registerXIndex: Int, registerYIndex: Int)
    
    static func decode(operationCode: UShort) -> Chip8Operation? {
        // Extract common indices
        let registerXIndex = Int((operationCode & 0x0F00) >> 8)
        let registerYIndex = Int((operationCode & 0x00F0) >> 4)
        
        // Check each opcode pattern
        switch operationCode {
        case 0x00E0:
            return .ClearScreen
            
        case let code where (code & 0xF000) == 0x1000: // 1NNN - jump (set PC to NNN)
            let address = code & 0x0FFF
            return .Jump(address: address)
        case let code where (code & 0xF000) == 0x2000: // 2NNN - call subroutine at NNN
            let subroutineAddress = code & 0x0FFF
            return .CallSubroutine(address: subroutineAddress)
        case 0x00EE: // 00EE - return from subroutine
            return .ReturnFromSubroutine
        
        case let code where (code & 0xF000) == 0x3000: // 3XNN - Skip one instruction if VX == NN
            let value = UByte(code & 0x00FF)
            return .ConditionalSkipRegisterValue(registerIndex: registerXIndex, value: value, isEqual: true)
        case let code where (code & 0xF000) == 0x4000: // 4XNN - Skip one instruction if VX != NN
            let value = UByte(code & 0x00FF)
            return .ConditionalSkipRegisterValue(registerIndex: registerXIndex, value: value, isEqual: false)
        case let code where (code & 0xF00F) == 0x5000: // 5XY0 - Skip one instruction if VX == VY
            return .ConditionalSkipRegisters(registerXIndex: registerXIndex, registerYIndex: registerYIndex, isEqual: true)
        case let code where (code & 0xF00F) == 0x9000: // 9XY0 - Skip one instruction if VX != VY
            return .ConditionalSkipRegisters(registerXIndex: registerXIndex, registerYIndex: registerYIndex, isEqual: false)
            
        case let code where (code & 0xF000) == 0x6000: // 6XNN - set value NN to register X
            let value = UByte(code & 0x00FF)
            return .SetValueToRegister(registerIndex: registerXIndex, value: value)
        case let code where (code & 0xF000) == 0x7000: // 7XNN - add value NN to register X
            let value = UByte(code & 0x00FF)
            return .AddValueToRegister(registerIndex: registerXIndex, value: value)
        case let code where (code & 0xF000) == 0xA000: // ANNN - set value NNN to Index register
            let value = code & 0x0FFF
            return .SetValueToIndexRegister(value: value)
            
        case let code where (code & 0xF00F) == 0x8000: // 8XY0 - Set VX into VY
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .setToSecond)
        case let code where (code & 0xF00F) == 0x8001: // 8XY1 - Set VX into VX | VY
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .bitwiseOr)
        case let code where (code & 0xF00F) == 0x8002: // 8XY2 - Set VX into VX & VY
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .bitwiseAnd)
        case let code where (code & 0xF00F) == 0x8003: // 8XY3 - Set VX into VX ^ VY
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .bitwiseXOR)
        case let code where (code & 0xF00F) == 0x8004: // 8XY4 - Set VX into VX + VY // TODO: Note Overflow !!!
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .addition)
            
        case let code where (code & 0xF000) == 0xD000: // DXYN - draws N pixels tall sprite from memory location that Index register has onto screen at location pX = value of X register, pY= value of Y register
            let height = Int(code & 0x000F)
            return .DrawSprite(height: height, registerXIndex: registerXIndex, registerYIndex: registerYIndex)
            
        default:
            print("Unknown operation code \(String(format:"%02X", operationCode))")
            return nil
        }
    }

}

public enum RegistersOperation {
    case setToSecond
    case bitwiseOr
    case bitwiseAnd
    case bitwiseXOR
    case addition
    case subtractSecondFromFirst
    case subtractFirstFromSecond

//    func compute(_ first: UByte, _ second: UByte) -> UByte { // TODO: in addition checkout for carry bit...
//        switch self {
//        case .setToSecond:
//            return second
//        case .bitwiseOr:
//            return first | second
//        case .bitwiseAnd:
//            return first & second
//        case .bitwiseXOR:
//            return first ^ second
//        case .addition:
//            return first + second
//        case .subtractSecondFromFirst:
//            return first - second
//        case .subtractFirstFromSecond:
//            return second - first
//        }
//    }
}
