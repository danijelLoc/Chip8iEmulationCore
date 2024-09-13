//
//  Chip8OperationParser.swift
//  Chip8iEmulator
//
//  Created by Danijel Stracenski on 10.09.2024..
//

import Foundation

public protocol Chip8OperationParserProtocol {
    /// Decode operation code (UShort) into Chip8Operation with its parameters.
    func decode(operationCode: UShort) -> Chip8Operation;
}

public struct Chip8OperationParser: Chip8OperationParserProtocol {
    public func decode(operationCode: UShort) -> Chip8Operation {
        // Extract common indices
        let registerXIndex = Int((operationCode & 0x0F00) >> 8)
        let registerYIndex = Int((operationCode & 0x00F0) >> 4)
        
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
        
        case let code where (code & 0xF0FF) == 0xE09E: // EX9E - Skip next instruction if key stored in VX is pressed down
            return .ConditionalSkipKeyDown(registerIndex: registerXIndex, isKeyDown: true)
        case let code where (code & 0xF0FF) == 0xE0A1: // EXA1 - Skip next instruction if key stored in VX is not pressed down
            return .ConditionalSkipKeyDown(registerIndex: registerXIndex, isKeyDown: false)
        case let code where (code & 0xF0FF) == 0xF00A: // FX0A - Wait until key pressed (down and released) and  store it in VX
            return .ConditionalPauseUntilKeyTap(registerIndex: registerXIndex)
            
        case let code where (code & 0xF000) == 0x6000: // 6XNN - set value NN to register X
            let value = UByte(code & 0x00FF)
            return .SetValueToRegister(registerIndex: registerXIndex, value: value)
        case let code where (code & 0xF000) == 0x7000: // 7XNN - add value NN to register X, NOTE: carry flag is not changed
            let value = UByte(code & 0x00FF)
            return .AddValueToRegister(registerIndex: registerXIndex, value: value)
        case let code where (code & 0xF000) == 0xA000: // ANNN - set value NNN to Index register I
            let value = code & 0x0FFF
            return .SetValueToIndexRegister(value: value)
        case let code where (code & 0xF000) == 0xC000: // CXNN - set value (NN & Random) to register X
            let value = UByte(code & 0x00FF)
            return .SetValueToRegisterWithRandomness(registerIndex: registerXIndex, value: value)
            
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
        case let code where (code & 0xF00F) == 0x8005: // 8XY4 - Set VX into VX - VY
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .subtractSecondFromFirst)
        case let code where (code & 0xF00F) == 0x8007: // 8XY4 - Set VX into VY - VX
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .subtractFirstFromSecond)
        case let code where (code & 0xF00F) == 0x8006: // 8XY6 - Set VX into VX >> 1
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .shiftRight)
        case let code where (code & 0xF00F) == 0x800E: // 8XYE - Set VX into VX << 1
            return .RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .shiftLeft)
            
        case let code where (code & 0xF000) == 0xD000: // DXYN - draws N pixels tall sprite from memory location that Index register has onto screen at location pX = value of X register, pY= value of Y register
            let height = Int(code & 0x000F)
            return .DrawSprite(height: height, registerXIndex: registerXIndex, registerYIndex: registerYIndex)
        
        case let code where (code & 0xF0FF) == 0xF01E: // FX1E - add value of VX to index register I, NOTE: carry flag is not changed
            return .AddRegisterValueToIndexRegister(registerIndex: registerXIndex)
        case let code where (code & 0xF0FF) == 0xF029: // FX29 - Set address of font character saved in VX to Index register I
            return .SetFontCharacterAddressToIndexRegister(registerIndex: registerXIndex)
            
        case let code where (code & 0xF0FF) == 0xF055: // FX55 - Store registers up to index X in memory addresses starting from the one stored in I
            return .RegistersStorage(maxIncludedRegisterIndex: registerXIndex, isRestoring: false)
        case let code where (code & 0xF0FF) == 0xF065: // FX65 - Restore registers up to index X from memory addresses starting from the one stored in I
            return .RegistersStorage(maxIncludedRegisterIndex: registerXIndex, isRestoring: true)
            
        case let code where (code & 0xF0FF) == 0xF033: // FX33 - Store decimal digits of VX value in memory addresses starting from the one stored in I
            return .RegisterStoreDecimalDigits(registerXIndex: registerXIndex)
        case let code where (code & 0xF0FF) == 0xF007: // FX07 sets VX to the current value of the delay timer
            return .DelayTimerStore(registerIndex: registerXIndex)
        case let code where (code & 0xF0FF) == 0xF015: // FX15 sets the delay timer to the value in VX
            return .DelayTimerSet(registerIndex: registerXIndex)
        case let code where (code & 0xF0FF) == 0xF018: // FX18 sets the sound timer to the value in VX
            return .SoundTimerSet(registerIndex: registerXIndex)
            
        default:
            //print("!!!! Unknown operation code \(operationCode.hexDescription)")
            return .Unknown(operationCode: operationCode)
        }
    }
}
