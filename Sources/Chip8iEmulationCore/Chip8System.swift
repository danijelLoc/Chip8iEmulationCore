//
//  Chip8System.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 28.05.2024..
//

import Foundation

public typealias UByte = UInt8
public typealias UShort = UInt16

/// Internal Chip8 System CPU module that executes system operation with resulting mutation of system state.
internal class Chip8System {

    private(set) var state: Chip8SystemState
    
    internal init(font: [UByte] = Chip8System.DefaultFontSet) {
        state = Chip8SystemState()
        
        // Load font set
        state.randomAccessMemory.replaceSubrange(state.fontStartingLocation.toInt..<(state.fontStartingLocation.toInt+80), with: font)
    }
    
    /// Load program rom into system ram at location 0x200 (512) where pc starts at default.
    internal func loadProgram(_ programROM: [UByte]) {
        state.randomAccessMemory.replaceSubrange(512..<(512+programROM.count), with: programROM)
    }
    
    /// Execute single given operation. It takes needed data from systemState and modifies it
    internal func executeOperation(operation: Chip8Operation, logger: EmulationLoggerProtocol?) {
        switch operation {
        case .ClearScreen:
            state.Output = Array(repeating: false, count: 64*32)
            state.pc += 2
            break
            
        case .JumpToAddress(let location):
            state.pc = location
            break
        case .JumpToAddressPlusV0(let location):
            state.pc = location &+ UShort(state.registers[0])
            break
        case .CallSubroutine(let address):
            state.callStack[state.callStackPointer.toInt] = state.pc + 2
            state.callStackPointer += 1
            state.pc = address
        case .ReturnFromSubroutine:
            state.callStackPointer -= 1
            state.pc = state.callStack[state.callStackPointer.toInt]
            state.callStack[state.callStackPointer.toInt] = 0
            
        case .ConditionalSkipRegisterValue(let registerIndex, let value, let isEqual):
            let registerValue = state.registers[registerIndex]
            if isEqual && registerValue == value || !isEqual && registerValue != value {
                state.pc += 4
            } else {
                state.pc += 2
            }
        case .ConditionalSkipRegisters(let registerXIndex, let registerYIndex, let isEqual):
            let registerXValue = state.registers[registerXIndex]
            let registerYValue = state.registers[registerYIndex]
            if isEqual && registerXValue == registerYValue || !isEqual && registerXValue != registerYValue {
                state.pc += 4
            } else {
                state.pc += 2
            }
        case .ConditionalSkipKeyDown(let registerIndex, let isKeyDown):
            let registerValue = state.registers[registerIndex]
            let keyState = state.InputKeys[registerValue.toInt]
            if isKeyDown && keyState || !isKeyDown && !keyState {
                state.pc += 4
            } else {
                state.pc += 2
            }
        case .ConditionalPauseUntilKeyTap(let registerIndex):
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
                    state.InputKeyIndexToBeReleased = UByte(keyPressedDown.0) // save index of pressed key and wait for it to be released
                }
            }
        case .SetValueToRegister(let registerIndex, let value):
            state.registers[registerIndex] = value
            state.pc += 2
            break
        case .SetValueToRegisterWithRandomness(let registerIndex, let value):
            let randomValue = UByte.random(in: UByte.min...UByte.max)
            state.registers[registerIndex] = value & randomValue
            state.pc += 2
            break
        case .AddValueToRegister(let registerIndex, let value):
            state.registers[registerIndex] = state.registers[registerIndex] &+ (value) // overflow ignored here
            state.pc += 2
            break
        case .AddRegisterValueToIndexRegister(let registerIndex):
            let registerValue = state.registers[registerIndex]
            state.indexRegister = state.indexRegister &+ (UShort(registerValue)) // overflow ignored here
            state.pc += 2
            break
        case .SetValueToIndexRegister(let value):
            state.indexRegister = value
            state.pc += 2
            break
        case .SetFontCharacterAddressToIndexRegister(let registerIndex):
            let fontCharacterIndex = state.registers[registerIndex]
            // single font character uses 5 bytes of memory
            let fontCharacterAddress = state.fontStartingLocation + UShort(fontCharacterIndex * 5)
            state.indexRegister = fontCharacterAddress
            state.pc += 2
            
            
        case .RegistersOperation(let registerXIndex, let registerYIndex, let registersOperation):
            switch registersOperation {
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
        
        case .RegistersStorage(let maxIncludedRegisterIndex, let isRestoring):
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
        
        case .RegisterStoreDecimalDigits(let registerXIndex):
            let decimalValue = Int(state.registers[registerXIndex])
            let thirdDecimalDigit = decimalValue % 10
            let secondDecimalDigit = ((decimalValue - thirdDecimalDigit) / 10) % 10
            let firstDecimalDigit = (decimalValue - secondDecimalDigit * 10 - thirdDecimalDigit) / 100
            
            state.randomAccessMemory[state.indexRegister.toInt] = UByte(firstDecimalDigit)
            state.randomAccessMemory[state.indexRegister.toInt + 1] = UByte(secondDecimalDigit)
            state.randomAccessMemory[state.indexRegister.toInt + 2] = UByte(thirdDecimalDigit)
    
            state.pc += 2
        case .DelayTimerStore(let registerIndex):
            state.registers[registerIndex] = state.delayTimer
            state.pc += 2
        case .DelayTimerSet(let registerIndex):
            state.delayTimer = state.registers[registerIndex]
            state.pc += 2
        case .SoundTimerSet(let registerIndex):
            state.soundTimer = state.registers[registerIndex]
            state.pc += 2
             
        case .DrawSprite(let height, let registerXIndex, let registerYIndex):
            let locationX = Int(state.registers[registerXIndex])
            let locationY = Int(state.registers[registerYIndex])
            
            state.registers[15] = 0 // collision
            
            let spriteStartAddress = Int(state.indexRegister)
            let spriteEndAddress = spriteStartAddress + height // Chip8 Spite is always 8 pixels (8 bits in memory) wide. One memory address stores one row of sprite. So whole sprite is <height> bytes long
            let sprite = Array(state.randomAccessMemory[spriteStartAddress..<spriteEndAddress])
            for j in 0..<height { // row by row
                if locationY+j >= 32 {
                    break
                }
                for i in 0..<8 { // column by column (pixels in one row)
                    if locationX+i >= 64 {
                        break
                    }
                    if locationX+i + (locationY+j)*64 >= state.Output.count {
                        continue
                    }
                    let pixelBefore = state.Output[locationX+i + (locationY+j)*64]
                    let spritePixel = Bool.fromOneOrZero((sprite[j] & UInt8(NSDecimalNumber(decimal: pow(2, (7-i))).intValue)) >> (7-i))
                    let pixel = spritePixel == false ? pixelBefore : pixelBefore.xor(other: spritePixel)
                    state.Output[locationX+i + (locationY+j)*64] = pixel
                    if (pixel != pixelBefore && pixelBefore == true) {
                        state.registers[15] = 1 // collision
                    }
                }
            }
            state.pc += 2
            break
        case .Unknown(let operationCode):
            logger?.log("Skipping unknown operation code: \(operationCode.fullDescription)", level: .warning)
            state.pc += 2
            break
        default:
            logger?.log("Skipping not implemented operation: \(operation)", level: .warning)
            state.pc += 2
            break
        }
    }
    
    internal func fetchOperationCode(memoryLocation: UShort) -> UShort {
        let firstByte = state.randomAccessMemory[Int(memoryLocation)]
        let secondByte = state.randomAccessMemory[Int(memoryLocation + 1)]
        let opCode: UShort = (UShort(firstByte) << 8) | UShort(secondByte) // chip8 uses big endian
        return opCode
    }
    
    internal func decreaseDelayTimer() {
        if state.delayTimer == 0 { return }
        state.delayTimer -= 1
    }
    
    internal func decreaseSoundTimer() {
        if state.soundTimer == 0 { return }
        state.soundTimer -= 1
    }
    
    internal func KeyDown(key: UByte) {
        state.InputKeys[key.toInt] = true
    }
    
    internal func KeyUp(key: UByte) {
        state.InputKeys[key.toInt] = false
    }
}
