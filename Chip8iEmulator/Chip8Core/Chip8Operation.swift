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
    case JumpToAddress(address: UShort)
    case JumpToAddressPlusV0(address: UShort)
    
    case ConditionalSkipRegisterValue(registerIndex: Int, value: UByte, isEqual: Bool)
    case ConditionalSkipRegisters(registerXIndex: Int, registerYIndex: Int, isEqual: Bool)
    
    case ConditionalSkipKeyPress(registerIndex: Int, isPressed: Bool)
    
    case SetValueToRegister(registerIndex: Int, value: UByte)
    case AddValueToRegister(registerIndex: Int, value: UByte)
    case SetValueToIndexRegister(value: UShort)
    
    case RegistersOperation(registerXIndex: Int, registerYIndex: Int, operation: RegistersOperation)
    case SetValueToRegisterWithRandomness(registerIndex: Int, value: UByte)
    
    case RegistersStorage(maxIncludedRegisterIndex: Int, isRestoring: Bool)
    case RegisterBinaryToDecimal(registerXIndex: Int)
    
    case DrawSprite(height: Int, registerXIndex: Int, registerYIndex: Int)
    case Unknown(operationCode: UShort)
    
    static func decode(operationCode: UShort) -> Chip8Operation {
        // Extract common indices
        let registerXIndex = Int((operationCode & 0x0F00) >> 8)
        let registerYIndex = Int((operationCode & 0x00F0) >> 4)
        
        //print("Operation code \(String(format:"%02X", operationCode))")
        
        // Check each opcode pattern
        switch operationCode {
        case 0x00E0:
            return .ClearScreen
            
        case let code where (code & 0xF000) == 0x1000: // 1NNN - jump (set PC to NNN)
            let address = code & 0x0FFF
            return .JumpToAddress(address: address)
        case let code where (code & 0xF000) == 0xB000: // BNNN - jump (set PC to NNN+V0)
            let address = code & 0x0FFF
            return .JumpToAddressPlusV0(address: address)
            
        case let code where (code & 0xF000) == 0x2000: // 2NNN - call subroutine at NNN
            let subroutineAddress = code & 0x0FFF
            return .CallSubroutine(address: subroutineAddress)
        case let code where (code & 0xFFFF) == 0x00EE: // 00EE - return from subroutine
            return .ReturnFromSubroutine
        
        case let code where (code & 0xF000) == 0x3000: // 3XNN - Skip next instruction if VX == NN
            let value = UByte(code & 0x00FF)
            return .ConditionalSkipRegisterValue(registerIndex: registerXIndex, value: value, isEqual: true)
        case let code where (code & 0xF000) == 0x4000: // 4XNN - Skip next instruction if VX != NN
            let value = UByte(code & 0x00FF)
            return .ConditionalSkipRegisterValue(registerIndex: registerXIndex, value: value, isEqual: false)
        case let code where (code & 0xF00F) == 0x5000: // 5XY0 - Skip next instruction if VX == VY
            return .ConditionalSkipRegisters(registerXIndex: registerXIndex, registerYIndex: registerYIndex, isEqual: true)
        case let code where (code & 0xF00F) == 0x9000: // 9XY0 - Skip next instruction if VX != VY
            return .ConditionalSkipRegisters(registerXIndex: registerXIndex, registerYIndex: registerYIndex, isEqual: false)
            
        case let code where (code & 0xF000) == 0x6000: // 6XNN - set value NN to register X
            let value = UByte(code & 0x00FF)
            return .SetValueToRegister(registerIndex: registerXIndex, value: value)
        case let code where (code & 0xF000) == 0x7000: // 7XNN - add value NN to register X, NOTE: carry flag is not changed
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
        case let code where (code & 0xF00F) == 0x8004: // 8XY4 - Set VX into VX + VY
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .addition)
        case let code where (code & 0xF00F) == 0x8005: // 8XY4 - Set VX into VX + VY
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .subtractSecondFromFirst)
        case let code where (code & 0xF00F) == 0x8007: // 8XY4 - Set VX into VX + VY
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .subtractFirstFromSecond)
            
        case let code where (code & 0xF00F) == 0x8006: // 8XY6 - Set VX into VX >> 1
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .shiftRight)
        case let code where (code & 0xF00F) == 0x800E: // 8XYE - Set VX into VX << 1
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .shiftLeft)
            
        case let code where (code & 0xF000) == 0xC000: // CXNN - set value (NN & Random) to register X
            let value = UByte(code & 0x00FF)
            return .SetValueToRegisterWithRandomness(registerIndex: registerXIndex, value: value)
            
        case let code where (code & 0xF000) == 0xD000: // DXYN - draws N pixels tall sprite from memory location that Index register has onto screen at location pX = value of X register, pY= value of Y register
            let height = Int(code & 0x000F)
            return .DrawSprite(height: height, registerXIndex: registerXIndex, registerYIndex: registerYIndex)
            
        case let code where (code & 0xF0FF) == 0xE09E: // EX9E - Skip next instruction if key stored in VX is pressed
            return .ConditionalSkipKeyPress(registerIndex: registerXIndex, isPressed: true)
        case let code where (code & 0xF0FF) == 0xE0A1: // EX9E - Skip next instruction if key stored in VX is not pressed
            return .ConditionalSkipKeyPress(registerIndex: registerXIndex, isPressed: true)
            
        case let code where (code & 0xF0FF) == 0xF055: // FX55 - Store registers up to index X in memory addresses starting from the one stored in I
            return .RegistersStorage(maxIncludedRegisterIndex: registerXIndex, isRestoring: false)
        case let code where (code & 0xF0FF) == 0xF065: // FX65 - Restore registers up to index X from memory addresses starting from the one stored in I
            return .RegistersStorage(maxIncludedRegisterIndex: registerXIndex, isRestoring: true)
            
        case let code where (code & 0xF0FF) == 0xF033: // FX33 - Store register value decimal 3 digits in memory addresses starting from the one stored in I
            return .RegisterBinaryToDecimal(registerXIndex: registerXIndex)
            
        default:
            //print("Unknown operation code \(operationCode.hexDescription)")
            return .Unknown(operationCode: operationCode)
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
    case shiftRight
    case shiftLeft
}


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
