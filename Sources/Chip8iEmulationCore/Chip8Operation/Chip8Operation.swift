//
//  Chip8Operation.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 24.06.2024..
//

import Foundation


public protocol Chip8OperationCommand: Equatable {
    func execute(state: inout Chip8SystemState)
}

/// Clears the screen by setting all pixels to 0.
///
/// 0x00E0
public struct ClearScreen: Chip8OperationCommand {
    public init() {}

    public func execute(state: inout Chip8SystemState) {
        state.Output = Array(repeating: false, count: 64*32)
        state.pc += 2
    }
}

/// Calls the subroutine at the given address. First value of PC + 2 (address of next instruction) will be saved into call stack. Then PC will be set to address in arguments.
///
/// 2NNN - call subroutine at NNN
public struct CallSubroutine: Chip8OperationCommand {
    public let address: UShort

    public init(address: UShort) {
        self.address = address
    }

    public func execute(state: inout Chip8SystemState) {
        state.callStack[state.callStackPointer.toInt] = state.pc + 2
        state.callStackPointer += 1
        state.pc = address
    }
}

/// Returns from the subroutine by setting the PC to address removed from top of call stack (pop action).
///
/// 00EE - return from subroutine
public struct ReturnFromSubroutine: Chip8OperationCommand {
    public init() {}

    public func execute(state: inout Chip8SystemState) {
        state.callStackPointer -= 1
        state.pc = state.callStack[state.callStackPointer.toInt]
        state.callStack[state.callStackPointer.toInt] = 0
    }
}

/// Jump to address by setting PC to it.
///
/// 1NNN - jump (set PC to NNN)
public struct JumpToAddress: Chip8OperationCommand {
    public let address: UShort

    public init(address: UShort) {
        self.address = address
    }

    public func execute(state: inout Chip8SystemState) {
        state.pc = address
    }
}

/// Jump to (address + register0) by setting PC to it.
///
/// BNNN - jump (set PC to NNN+V0) Note: V0 is register at the index 0
public struct JumpToAddressPlusV0: Chip8OperationCommand {
    public let address: UShort

    public init(address: UShort) {
        self.address = address
    }

    public func execute(state: inout Chip8SystemState) {
        state.pc = address &+ UShort(state.registers[0])
    }
}

/// Conditional skip next instruction on comparing register (at the index X) to the value. if condition is met then we will move PC by 4 memory location instead of 2 (current instruction takes 2 memory locations).
///
/// 3XNN - Skip next instruction if VX == NN
///
/// 4XNN - Skip next instruction if VX != NN
public struct ConditionalSkipRegisterValue: Chip8OperationCommand {
    public let registerIndex: Int
    public let value: UByte
    public let isEqual: Bool

    public init(registerIndex: Int, value: UByte, isEqual: Bool) {
        self.registerIndex = registerIndex
        self.value = value
        self.isEqual = isEqual
    }

    public func execute(state: inout Chip8SystemState) {
        let registerValue = state.registers[registerIndex]
        if isEqual && registerValue == value || !isEqual && registerValue != value {
            state.pc += 4
        } else {
            state.pc += 2
        }
    }
}

/// Conditional skip next instruction on comparing VX to VY. If condition is met then we will move PC by 4 memory location instead of 2 (current instruction takes 2 memory locations).
///
/// 5XY0 - Skip next instruction if VX == VY
///
/// 9XY0 - Skip next instruction if VX != VY
public struct ConditionalSkipRegisters: Chip8OperationCommand {
    public let registerXIndex: Int
    public let registerYIndex: Int
    public let isEqual: Bool

    public init(registerXIndex: Int, registerYIndex: Int, isEqual: Bool) {
        self.registerXIndex = registerXIndex
        self.registerYIndex = registerYIndex
        self.isEqual = isEqual
    }

    public func execute(state: inout Chip8SystemState) {
        let registerXValue = state.registers[registerXIndex]
        let registerYValue = state.registers[registerYIndex]
        if isEqual && registerXValue == registerYValue || !isEqual && registerXValue != registerYValue {
            state.pc += 4
        } else {
            state.pc += 2
        }
    }
}

/// Conditional skip next instruction if key stored in VX is pressed down or not. If condition is met then we will move PC by 4 memory location instead of 2 (current instruction takes 2 memory locations).
///
/// EX9E - Skip next instruction if key stored in VX is pressed down
///
/// EXA1 - Skip next instruction if key stored in VX is not pressed down
public struct ConditionalSkipKeyDown: Chip8OperationCommand {
    public let registerIndex: Int
    public let isKeyDown: Bool

    public init(registerIndex: Int, isKeyDown: Bool) {
        self.registerIndex = registerIndex
        self.isKeyDown = isKeyDown
    }

    public func execute(state: inout Chip8SystemState) {
        let registerValue = state.registers[registerIndex]
        let keyIndex = registerValue;
        state.UsedKeysHelper.insert(keyIndex);
        
        let keyState = state.InputKeys[keyIndex.toInt]
        if isKeyDown && keyState || !isKeyDown && !keyState {
            state.pc += 4
        } else {
            state.pc += 2
        }
    }
}

/// Conditional wait for any key to be pressed down and released to store it in VX and move to next instruction. If key is pressed (down and released) then increase PC by 2 as always, otherwise don't change PC and remain at current command..
///
/// FX0A - Wait until key tap (press and release)  and  store it in VX
public struct ConditionalPauseUntilKeyTap: Chip8OperationCommand {
    public let registerIndex: Int

    public init(registerIndex: Int) {
        self.registerIndex = registerIndex
    }

    public func execute(state: inout Chip8SystemState) {
        if let keyIndexToBeReleased = state.InputKeyIndexToBeReleased {
            if state.InputKeys[keyIndexToBeReleased.toInt] == false {
                state.registers[registerIndex] = keyIndexToBeReleased // save index of pressed and released key into VX
                state.InputKeyIndexToBeReleased = nil // reset key to be released TODO: HMMM
                state.pc += 2
            }
        } else {
            let keyPressedDown = state.InputKeys.enumerated().first { (index, value) in
                value == true
            }
            
            if let keyPressedDown = keyPressedDown {
                state.UsedKeysHelper.insert(UByte(keyPressedDown.0));
                state.InputKeyIndexToBeReleased = UByte(keyPressedDown.0) // save index of pressed key and wait for it to be released
            }
        }
    }
}

/// Set value to register
///
/// 6XNN - set value NN to register X
public struct SetValueToRegister: Chip8OperationCommand {
    public let registerIndex: Int
    public let value: UByte

    public init(registerIndex: Int, value: UByte) {
        self.registerIndex = registerIndex
        self.value = value
    }

    public func execute(state: inout Chip8SystemState) {
        state.registers[registerIndex] = value
        state.pc += 2
    }
}

/// Set value to register without carry flag change
///
/// 7XNN - add value NN to register X, NOTE: carry flag is not changed
public struct AddValueToRegister: Chip8OperationCommand {
    public let registerIndex: Int
    public let value: UByte

    public init(registerIndex: Int, value: UByte) {
        self.registerIndex = registerIndex
        self.value = value
    }

    public func execute(state: inout Chip8SystemState) {
        state.registers[registerIndex] = state.registers[registerIndex] &+ (value) // overflow ignored here
        state.pc += 2
    }
}

/// Set value to Index register I
///
/// ANNN - set value NNN to Index register
public struct SetValueToIndexRegister: Chip8OperationCommand {
    public let value: UShort

    public init(value: UShort) {
        self.value = value
    }

    public func execute(state: inout Chip8SystemState) {
        state.indexRegister = value
        state.pc += 2
    }
}

/// Set (value & randomByte) to register
///
/// CXNN - set value (NN & Random) to register X
public struct SetValueToRegisterWithRandomness: Chip8OperationCommand {
    public let registerIndex: Int
    public let value: UByte

    public init(registerIndex: Int, value: UByte) {
        self.registerIndex = registerIndex
        self.value = value
    }

    public func execute(state: inout Chip8SystemState) {
        let randomValue = UByte.random(in: UByte.min...UByte.max)
        state.registers[registerIndex] = value & randomValue
        state.pc += 2
    }
}

/// Operations done on values from register X and Y and saved to register X
///
/// 8XY0 - Set VX into VY
///
/// 8XY1 - Set VX into VX | VY
///
/// 8XY2 - Set VX into VX & VY
///
/// 8XY3 - Set VX into VX ^ VY
///
/// 8XY4 - Set VX into VX + VY
///
/// 8XY5 - Set VX into VX - VY
///
/// 8XY7 - Set VX into VY - VX
///
/// 8XY6 - Set VX into VX >> 1
///
/// 8XYE - Set VX into VX << 1
public struct RegistersOperation: Chip8OperationCommand {
    public let registerXIndex: Int
    public let registerYIndex: Int
    public let registerOperationType: RegistersOperationType

    public init(registerXIndex: Int, registerYIndex: Int, operation: RegistersOperationType) {
        self.registerXIndex = registerXIndex
        self.registerYIndex = registerYIndex
        self.registerOperationType = operation
    }

    public func execute(state: inout Chip8SystemState) {
        switch registerOperationType {
        case .setToSecond:
            state.registers[registerXIndex] = state.registers[registerYIndex]
        case .bitwiseOr:
            state.registers[registerXIndex] = state.registers[registerXIndex] | state.registers[registerYIndex]
        case .bitwiseAnd:
            state.registers[registerXIndex] = state.registers[registerXIndex] & state.registers[registerYIndex]
        case .bitwiseXOR:
            state.registers[registerXIndex] = state.registers[registerXIndex] ^ state.registers[registerYIndex]
        case .addition:
            let res = state.registers[registerXIndex].addingReportingOverflow(state.registers[registerYIndex])
            state.registers[registerXIndex]  = res.partialValue
            state.registers[15] = res.overflow ? 1 : 0
        case .subtractSecondFromFirst:
            let res = state.registers[registerXIndex].subtractingReportingOverflow(state.registers[registerYIndex])
            state.registers[registerXIndex]  = res.partialValue
            state.registers[15] = res.overflow ? 0 : 1
        case .subtractFirstFromSecond:
            let res = state.registers[registerYIndex].subtractingReportingOverflow(state.registers[registerXIndex])
            state.registers[registerXIndex]  = res.partialValue
            state.registers[15] = res.overflow ? 0 : 1
        case .shiftRight:
            let res = state.registers[registerXIndex] >> 1
            let overflow = 0x01 & state.registers[registerXIndex]
            state.registers[registerXIndex]  = res
            state.registers[15] = overflow
        case .shiftLeft:
            let res = state.registers[registerXIndex] << 1
            let overflow = (0x80 & state.registers[registerXIndex]) >> 7
            state.registers[registerXIndex]  = res
            state.registers[15] = overflow
        }
        
        state.pc += 2
    }
}

/// Set address of font character saved in VX to Index register I
///
/// FX29 - Set address of font character saved in VX to Index register I
public struct SetFontCharacterAddressToIndexRegister: Chip8OperationCommand {
    public let registerIndex: Int

    public init(registerIndex: Int) {
        self.registerIndex = registerIndex
    }

    public func execute(state: inout Chip8SystemState) {
        let fontCharacterIndex = state.registers[registerIndex]
        // single font character uses 5 bytes of memory
        let fontCharacterAddress = state.fontStartingLocation + UShort(fontCharacterIndex * 5)
        state.indexRegister = fontCharacterAddress
        state.pc += 2
    }
}

/// Add value from register X to the Index register I
///
/// DXYN - Add value from VX to Index register
public struct AddRegisterValueToIndexRegister: Chip8OperationCommand {
    public let registerIndex: Int

    public init(registerIndex: Int) {
        self.registerIndex = registerIndex
    }

    public func execute(state: inout Chip8SystemState) {
        let registerValue = state.registers[registerIndex]
        state.indexRegister = state.indexRegister &+ (UShort(registerValue)) // overflow ignored here
        state.pc += 2
    }
}

/// Store registers from V0 to VX into memory (or restore from memory if isRestoring is true)
///
/// 8XY0 - Store registers V0 to VX into memory (or restore from memory if isRestoring)
public struct RegistersStorage: Chip8OperationCommand {
    public let maxIncludedRegisterIndex: Int
    public let isRestoring: Bool

    public init(maxIncludedRegisterIndex: Int, isRestoring: Bool) {
        self.maxIncludedRegisterIndex = maxIncludedRegisterIndex
        self.isRestoring = isRestoring
    }

    public func execute(state: inout Chip8SystemState) {
        var address = Int(state.indexRegister);
        for i in 0...maxIncludedRegisterIndex {
            if isRestoring {
                state.registers[i] = state.randomAccessMemory[address]
            }else{
                state.randomAccessMemory[address] = state.registers[i]
            }
            address += 1
        }
        state.pc += 2
    }
}

/// Store the decimal representation of register X into memory
///
/// FX33 - Store the decimal representation of VX (register X) into memory at I
public struct RegisterStoreDecimalDigits: Chip8OperationCommand {
    public let registerXIndex: Int

    public init(registerXIndex: Int) {
        self.registerXIndex = registerXIndex
    }

    public func execute(state: inout Chip8SystemState) {
        let decimalValue = Int(state.registers[registerXIndex])
        let thirdDecimalDigit = decimalValue % 10
        let secondDecimalDigit = ((decimalValue - thirdDecimalDigit) / 10) % 10
        let firstDecimalDigit = (decimalValue - secondDecimalDigit * 10 - thirdDecimalDigit) / 100
        
        state.randomAccessMemory[state.indexRegister.toInt] = UByte(firstDecimalDigit)
        state.randomAccessMemory[state.indexRegister.toInt + 1] = UByte(secondDecimalDigit)
        state.randomAccessMemory[state.indexRegister.toInt + 2] = UByte(thirdDecimalDigit)

        state.pc += 2
    }
}

/// Store the current value of the delay timer into register
///
/// FX15 - Store the current value of delay timer into VX register
public struct DelayTimerStore: Chip8OperationCommand {
    public let registerIndex: Int

    public init(registerIndex: Int) {
        self.registerIndex = registerIndex
    }

    public func execute(state: inout Chip8SystemState) {
        state.registers[registerIndex] = state.delayTimer
        state.pc += 2
    }
}

/// Set the delay timer value from register VX
///
/// FX18 - Set the delay timer value from register VX
public struct DelayTimerSet: Chip8OperationCommand {
    public let registerIndex: Int

    public init(registerIndex: Int) {
        self.registerIndex = registerIndex
    }

    public func execute(state: inout Chip8SystemState) {
        state.delayTimer = state.registers[registerIndex]
        state.pc += 2
    }
}

/// Set the sound timer value from register VX
///
/// FX1E - Set the sound timer value from register VX
public struct SoundTimerSet: Chip8OperationCommand {
    public let registerIndex: Int

    public init(registerIndex: Int) {
        self.registerIndex = registerIndex
    }

    public func execute(state: inout Chip8SystemState) {
        state.soundTimer = state.registers[registerIndex]
        state.pc += 2
    }
}

/// Draw a sprite at position (VX, VY) with the given height (N)
///
/// DXYN - Draw sprite at position (VX, VY) with given height (N)
public struct DrawSprite: Chip8OperationCommand {
    public let height: Int
    public let registerXIndex: Int
    public let registerYIndex: Int

    public init(height: Int, registerXIndex: Int, registerYIndex: Int) {
        self.height = height
        self.registerXIndex = registerXIndex
        self.registerYIndex = registerYIndex
    }

    public func execute(state: inout Chip8SystemState) {
        let locationX = Int(state.registers[registerXIndex])
        let locationY = Int(state.registers[registerYIndex])
        
        state.registers[15] = 0 // collision
        
        let spriteStartAddress = Int(state.indexRegister)
        let spriteEndAddress = spriteStartAddress + height // Chip8 Spite is always 8 pixels (8 bits in memory) wide. One memory address stores one row of sprite. So whole sprite is <height> bytes long
        let sprite = Array(state.randomAccessMemory[spriteStartAddress..<spriteEndAddress])
        for i in 0..<height { // row by row
            if locationY+i >= 32 {
                break
            }
            for j in 0..<8 { // column by column (pixels in one row)
                if locationX+j >= 64 {
                    break
                }
                if locationX+j + (locationY+i)*64 >= state.Output.count {
                    continue
                }
                let pixelBefore = state.Output[locationX+j + (locationY+i)*64]
                let spritePixel = Bool.fromOneOrZero((sprite[i] & UInt8(NSDecimalNumber(decimal: pow(2, (7-j))).intValue)) >> (7-j))
                let pixel = spritePixel == false ? pixelBefore : pixelBefore.xor(other: spritePixel)
                state.Output[locationX+j + (locationY+i)*64] = pixel
                if (pixel != pixelBefore && pixelBefore == true) {
                    state.registers[15] = 1 // collision
                }
            }
        }
        state.pc += 2
    }
}

/// Unknown operation whose code could not have been parsed
public struct Unknown: Chip8OperationCommand {
    public let operationCode: UShort

    public init(operationCode: UShort) {
        self.operationCode = operationCode
    }

    public func execute(state: inout Chip8SystemState) {
    }
}

public enum RegistersOperationType {
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


