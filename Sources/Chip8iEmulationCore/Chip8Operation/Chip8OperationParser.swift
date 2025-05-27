//
//  Chip8OperationParser.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 10.09.2024..
//

import Foundation

public protocol Chip8OperationParserProtocol: Sendable {
//    /// Decode machine operation code (UShort) into Chip8Operation with its parameters.
//    func decode(_ operationCode: UShort) -> Chip8Operation;
//    /// Encode back Chip8Operation enum into machine operation code (UShort)
//    func encode(_ operation: Chip8Operation) -> UShort;
    
    /// Decode machine operation code (UShort) into Chip8OperationCommand with its parameters.
    func decode(_ operationCode: UShort) -> any Chip8OperationCommand
    /// Encode back Chip8OperationCommand enum into machine operation code (UShort)
    func encode(_ operation: any Chip8OperationCommand) throws -> UShort;
}

public struct Chip8OperationParser: Chip8OperationParserProtocol {
    
    
    public init () {}
    
    public func decode(_ operationCode: UShort) -> any Chip8OperationCommand {
        // Extract common indices
        let registerXIndex = Int((operationCode & 0x0F00) >> 8)
        let registerYIndex = Int((operationCode & 0x00F0) >> 4)
        
        // Check each opcode pattern
        switch operationCode {
        case 0x00E0:
            return ClearScreen()
            
        case let code where (code & 0xF000) == 0x1000: // 1NNN - jump (set PC to NNN)
            let address = code & 0x0FFF
            return JumpToAddress(address: address)
        case let code where (code & 0xF000) == 0xB000: // BNNN - jump (set PC to NNN+V0)
            let address = code & 0x0FFF
            return JumpToAddressPlusV0(address: address)
            
        case let code where (code & 0xF000) == 0x2000: // 2NNN - call subroutine at NNN
            let subroutineAddress = code & 0x0FFF
            return CallSubroutine(address: subroutineAddress)
        case let code where (code & 0xFFFF) == 0x00EE: // 00EE - return from subroutine
            return ReturnFromSubroutine()
        
        case let code where (code & 0xF000) == 0x3000: // 3XNN - Skip next instruction if VX == NN
            let value = UByte(code & 0x00FF)
            return ConditionalSkipRegisterValue(registerIndex: registerXIndex, value: value, isEqual: true)
        case let code where (code & 0xF000) == 0x4000: // 4XNN - Skip next instruction if VX != NN
            let value = UByte(code & 0x00FF)
            return ConditionalSkipRegisterValue(registerIndex: registerXIndex, value: value, isEqual: false)
        case let code where (code & 0xF00F) == 0x5000: // 5XY0 - Skip next instruction if VX == VY
            return ConditionalSkipRegisters(registerXIndex: registerXIndex, registerYIndex: registerYIndex, isEqual: true)
        case let code where (code & 0xF00F) == 0x9000: // 9XY0 - Skip next instruction if VX != VY
            return ConditionalSkipRegisters(registerXIndex: registerXIndex, registerYIndex: registerYIndex, isEqual: false)
        
        case let code where (code & 0xF0FF) == 0xE09E: // EX9E - Skip next instruction if key stored in VX is pressed down
            return ConditionalSkipKeyDown(registerIndex: registerXIndex, isKeyDown: true)
        case let code where (code & 0xF0FF) == 0xE0A1: // EXA1 - Skip next instruction if key stored in VX is not pressed down
            return ConditionalSkipKeyDown(registerIndex: registerXIndex, isKeyDown: false)
        case let code where (code & 0xF0FF) == 0xF00A: // FX0A - Wait until key pressed (down and released) and  store it in VX
            return ConditionalPauseUntilKeyTap(registerIndex: registerXIndex)
            
        case let code where (code & 0xF000) == 0x6000: // 6XNN - set value NN to register X
            let value = UByte(code & 0x00FF)
            return SetValueToRegister(registerIndex: registerXIndex, value: value)
        case let code where (code & 0xF000) == 0x7000: // 7XNN - add value NN to register X, NOTE: carry flag is not changed
            let value = UByte(code & 0x00FF)
            return AddValueToRegister(registerIndex: registerXIndex, value: value)
        case let code where (code & 0xF000) == 0xA000: // ANNN - set value NNN to Index register I
            let value = code & 0x0FFF
            return SetValueToIndexRegister(value: value)
        case let code where (code & 0xF000) == 0xC000: // CXNN - set value (NN & Random) to register X
            let value = UByte(code & 0x00FF)
            return SetValueToRegisterWithRandomness(registerIndex: registerXIndex, value: value)
            
        case let code where (code & 0xF00F) == 0x8000: // 8XY0 - Set VX into VY
            return RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .setToSecond)
        case let code where (code & 0xF00F) == 0x8001: // 8XY1 - Set VX into VX | VY
            return RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .bitwiseOr)
        case let code where (code & 0xF00F) == 0x8002: // 8XY2 - Set VX into VX & VY
            return RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .bitwiseAnd)
        case let code where (code & 0xF00F) == 0x8003: // 8XY3 - Set VX into VX ^ VY
            return RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .bitwiseXOR)
        case let code where (code & 0xF00F) == 0x8004: // 8XY4 - Set VX into VX + VY
            return RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .addition)
        case let code where (code & 0xF00F) == 0x8005: // 8XY5 - Set VX into VX - VY
            return RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .subtractSecondFromFirst)
        case let code where (code & 0xF00F) == 0x8007: // 8XY7 - Set VX into VY - VX
            return RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .subtractFirstFromSecond)
        case let code where (code & 0xF00F) == 0x8006: // 8XY6 - Set VX into VX >> 1
            return RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .shiftRight)
        case let code where (code & 0xF00F) == 0x800E: // 8XYE - Set VX into VX << 1
            return RegistersOperation(registerXIndex: registerXIndex, registerYIndex: registerYIndex, operation: .shiftLeft)
            
        case let code where (code & 0xF000) == 0xD000: // DXYN - draws N pixels tall sprite from memory location that Index register has onto screen at location pX = value of X register, pY= value of Y register
            let height = Int(code & 0x000F)
            return DrawSprite(height: height, registerXIndex: registerXIndex, registerYIndex: registerYIndex)
        
        case let code where (code & 0xF0FF) == 0xF01E: // FX1E - add value of VX to index register I, NOTE: carry flag is not changed
            return AddRegisterValueToIndexRegister(registerIndex: registerXIndex)
        case let code where (code & 0xF0FF) == 0xF029: // FX29 - Set address of font character saved in VX to Index register I
            return SetFontCharacterAddressToIndexRegister(registerIndex: registerXIndex)
            
        case let code where (code & 0xF0FF) == 0xF055: // FX55 - Store registers up to index X in memory addresses starting from the one stored in I
            return RegistersStorage(maxIncludedRegisterIndex: registerXIndex, isRestoring: false)
        case let code where (code & 0xF0FF) == 0xF065: // FX65 - Restore registers up to index X from memory addresses starting from the one stored in I
            return RegistersStorage(maxIncludedRegisterIndex: registerXIndex, isRestoring: true)
        case let code where (code & 0xF0FF) == 0xF033: // FX33 - Store decimal digits of VX value in memory addresses starting from the one stored in I
            return RegisterStoreDecimalDigits(registerXIndex: registerXIndex)
            
        case let code where (code & 0xF0FF) == 0xF007: // FX07 sets VX to the current value of the delay timer
            return DelayTimerStore(registerIndex: registerXIndex)
        case let code where (code & 0xF0FF) == 0xF015: // FX15 sets the delay timer to the value in VX
            return DelayTimerSet(registerIndex: registerXIndex)
        case let code where (code & 0xF0FF) == 0xF018: // FX18 sets the sound timer to the value in VX
            return SoundTimerSet(registerIndex: registerXIndex)
            
        default:
            return Unknown(operationCode: operationCode)
        }
    }
    
    
    public func encode(_ operation: any Chip8OperationCommand) -> UShort {
        switch (operation) {
        case _ as ClearScreen:
            return 0x00E0
            
        case let operation as JumpToAddress:
            return 0x1000 | (operation.address & 0x0FFF)
        case let operation as JumpToAddressPlusV0:
            return 0xB000 | (operation.address & 0x0FFF)
            
        case let operation as CallSubroutine:
            return 0x2000 | (operation.address & 0x0FFF)
        case _ as ReturnFromSubroutine:
            return 0x00EE
            
        case let operation as ConditionalSkipRegisterValue:
            let base: UShort = operation.isEqual ? 0x3000 : 0x4000
            return base | (UShort(operation.registerIndex) << 8) | UShort(operation.value)
        case let operation as ConditionalSkipRegisters:
            let base: UShort = operation.isEqual ? 0x5000 : 0x9000
            return base | (UShort(operation.registerXIndex) << 8) | (UShort(operation.registerYIndex) << 4)
            
        case let operation as ConditionalSkipKeyDown:
            let base: UShort = operation.isKeyDown ? 0xE09E : 0xE0A1
            return base | (UShort(operation.registerIndex) << 8)
        case let operation as ConditionalPauseUntilKeyTap:
            return 0xF00A | (UShort(operation.registerIndex) << 8)
            
        case let operation as SetValueToRegister:
            return 0x6000 | (UShort(operation.registerIndex) << 8) | UShort(operation.value)
        case let operation as AddValueToRegister:
            return 0x7000 | (UShort(operation.registerIndex) << 8) | UShort(operation.value)
        case let operation as SetValueToIndexRegister:
            return 0xA000 | (operation.value & 0x0FFF)
        case let operation as SetValueToRegisterWithRandomness:
            return 0xC000 | (UShort(operation.registerIndex) << 8) | UShort(operation.value)
            
        case let operation as RegistersOperation:
            let opCode: UShort
            switch operation.registerOperationType {
            case .setToSecond:
                opCode = 0x0
            case .bitwiseOr:
                opCode = 0x1
            case .bitwiseAnd:
                opCode = 0x2
            case .bitwiseXOR:
                opCode = 0x3
            case .addition:
                opCode = 0x4
            case .subtractSecondFromFirst:
                opCode = 0x5
            case .subtractFirstFromSecond:
                opCode = 0x7
            case .shiftRight:
                opCode = 0x6
            case .shiftLeft:
                opCode = 0xE
            }
            return 0x8000 | (UShort(operation.registerXIndex) << 8) | (UShort(operation.registerYIndex) << 4) | opCode
            
        case let operation as DrawSprite:
            return 0xD000 | (UShort(operation.registerXIndex) << 8) | (UShort(operation.registerYIndex) << 4) | UShort(operation.height)
            
        case let operation as AddRegisterValueToIndexRegister:
            return 0xF01E | (UShort(operation.registerIndex) << 8)
        case let operation as SetFontCharacterAddressToIndexRegister:
            return 0xF029 | (UShort(operation.registerIndex) << 8)
            
        case let operation as RegistersStorage:
            let base: UShort = operation.isRestoring ? 0xF065 : 0xF055
            return base | (UShort(operation.maxIncludedRegisterIndex) << 8)
        case let operation as RegisterStoreDecimalDigits:
            return 0xF033 | (UShort(operation.registerXIndex) << 8)
            
        case let operation as DelayTimerStore:
            return 0xF007 | (UShort(operation.registerIndex) << 8)
        case let operation as DelayTimerSet:
            return 0xF015 | (UShort(operation.registerIndex) << 8)
        case let operation as SoundTimerSet:
            return 0xF018 | (UShort(operation.registerIndex) << 8)
            
        case let operation as Unknown:
            return operation.operationCode
        default:
            return 0;
        }
    }
}
