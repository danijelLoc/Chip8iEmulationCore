//
//  Chip8System.swift
//  Chip8iEmulator
//
//  Created by Danijel Stracenski on 28.05.2024..
//

import Foundation

public typealias UByte = UInt8
public typealias UShort = UInt16

/// Current state of memory, timers, inputs and output buffer
public struct Chip8SystemState {
    /// 4096 Bytes of memory. Chip8 uses BIG ENDIAN (when saving UShort value  we save upper byte at address x and then lower byte at memory address x+1)
    var randomAccessMemory: [UByte]
    
    /// 15 general purpose registers and 1 "carry-flag" register
    var registers: [UByte]
    var indexRegister: UShort
    /// Program Counter - points to memory location of operation code that will be executed next. Default value 0x200 (512). Each operation code takes 2 memory addresses so increment should be done by 2.
    var pc: UShort
    
    /// Saves Current ProgramCounter for later after returning from subroutines. 16 levels
    var callStack: [UShort]
    /// Remembers which level of stack will be used for next push
    var callStackPointer: UShort
    
    /// if set above 0 they are counting down. Counting at 60Hz
    var delayTimer: UByte
    /// Buzzer when reaches zero
    var soundTimer: UByte
    
    /// One dimension Byte array representing output screen (64x32). One byte represents one pixel (0: Black and 255: White), order from left top of the screen.
    var Output: [UByte] // 64x32
    /// Boolean Array containing states of all 16 keys of Chip8. If value at index X is set to True it means that button X is pressed. Chip8 has buttons marked with Hex digits from 0,1,2 ... E, F
    var InputKeys: [Bool] // 16 keys
    
    init() {
        self.randomAccessMemory = Array(repeating: 0, count: 4096)
        
        self.registers = Array(repeating: 0, count: 16)
        self.indexRegister = 0
        self.pc = 512 // program counter starts at hex location 0x200 (decimal 512)
        
        self.callStack = Array(repeating: 0, count: 16)
        self.callStackPointer = 0
        
        self.delayTimer = 0
        self.soundTimer = 0
        
        self.Output = Array(repeating: 0, count: 64*32)
        self.InputKeys = Array(repeating: false, count: 16)
    }
}

/// Chip 8 System including RAM, Registers, Call Stack, Timers, Program Counter, Input Keys States and Output Screen Buffer
///
class Chip8System {

    private(set) var state: Chip8SystemState
    
    private let opCodeParser: Chip8OperationParserProtocol
    
    init(font: [UByte] = Chip8System.DefaultFontSet, opCodeParser: Chip8OperationParserProtocol) {
        state = Chip8SystemState()
        
        // Load font set
        state.randomAccessMemory.replaceSubrange(0..<80, with: font)
        
        self.opCodeParser = opCodeParser
    }
    
    /// Load program rom into system ram at location 0x200 (512) where pc starts at default.
    public func loadProgram(_ programROM: [UByte]) {
        state.randomAccessMemory.replaceSubrange(512..<(512+programROM.count), with: programROM)
    }
    
    public func emulateCycle() async{
        // Fetch Opcode
        let opCode: UShort = fetchOperationCode(memoryLocation: state.pc)
        // Decode Opcode
        let operation = opCodeParser.decode(operationCode: opCode)
        print("\(opCode.hexDescription) -> \(operation)")
        // Execute Opcode
        executeOperation(operation: operation)
        
        // Update timers
        
    }
    
    public func executeOperation(operation: Chip8Operation) {
        switch operation {
        case .ClearScreen:
            state.Output = Array(repeating: 0, count: 64*32)
            state.pc += 2
            break
            
        case .JumpToAddress(let location):
            state.pc = location
            break
        case .JumpToAddressPlusV0(let location):
            state.pc = location &+ UShort(state.registers[0])
            break
        case .CallSubroutine(let address):
            state.callStack[Int(state.callStackPointer)] = state.pc + 2
            state.callStackPointer += 1
            state.pc = address
        case .ReturnFromSubroutine:
            state.callStackPointer -= 1
            state.pc = state.callStack[Int(state.callStackPointer)]
            state.callStack[Int(state.callStackPointer)] = 0
            
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
        case .ConditionalSkipKeyPress(let registerIndex, let isPressed):
            let registerValue = state.registers[registerIndex]
            let keyState = state.InputKeys[Int(registerValue)] // TODO: This could easily be out of range and crash the app... throw error? each app should handle it.
            if isPressed && keyState || !isPressed && !keyState {
                state.pc += 4
            } else {
                state.pc += 2
            }
        case .ConditionalPauseUntilKeyPress(let registerIndex):
            let registerValue = state.registers[registerIndex]
            let keyState = state.InputKeys[Int(registerValue)]
            if keyState {
                state.pc += 2
            } else {
                state.pc += 0 // Remain at the current operation and wait for key press
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
        case .SetValueToIndexRegister(let value):
            state.indexRegister = value
            state.pc += 2
            break
            
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
        
        case .RegisterBinaryToDecimal(let registerXIndex):
            let decimalValue = Int(state.registers[registerXIndex])
            let thirdDecimalDigit = decimalValue % 10
            let secondDecimalDigit = ((decimalValue - thirdDecimalDigit) / 10) % 10
            let firstDecimalDigit = (decimalValue - secondDecimalDigit * 10 - thirdDecimalDigit) / 100
            
            state.randomAccessMemory[Int(state.indexRegister)] = UByte(firstDecimalDigit)
            state.randomAccessMemory[Int(state.indexRegister)+1] = UByte(secondDecimalDigit)
            state.randomAccessMemory[Int(state.indexRegister)+2] = UByte(thirdDecimalDigit)
    
            state.pc += 2
             
        case .DrawSprite(let height, let registerXIndex, let registerYIndex):
            let locationX = Int(state.registers[registerXIndex])
            let locationY = Int(state.registers[registerYIndex])
            
            state.registers[15] = 1 // collision
            
            let spriteStartAddress = Int(state.indexRegister)
            let spriteEndAddress = spriteStartAddress + height // Chip8 Spite is always 8 pixels (8 bits in memory) wide. One memory address stores one row of sprite. So whole sprite is <height> bytes long
            let sprite = Array(state.randomAccessMemory[spriteStartAddress..<spriteEndAddress])
            for j in 0..<height {
                if locationY+j >= 32 {
                    break
                }
                for i in 0..<8 {
                    if locationX+i >= 64 {
                        break
                    }
                    if locationX+i + (locationY+j)*64 >= state.Output.count {
                        continue
                    }
                    let pixelBefore = state.Output[locationX+i + (locationY+j)*64]
                    let spritePixel = (sprite[j] & UInt8(NSDecimalNumber(decimal: pow(2, (7-i))).intValue)) >> (7-i)
                    let pixel = spritePixel == 0 ? state.Output[locationX+i + (locationY+j)*64] : state.Output[locationX+i + (locationY+j)*64] ^ spritePixel
                    if pixel > 1 {
                        print("Error unexpected pixel value") // TODO: THROW
                        return
                    }
                    state.Output[locationX+i + (locationY+j)*64] = pixel
                    if (pixel != pixelBefore && pixelBefore == 1) {
                        state.registers[15] = 1 // collision
                    }
                }
            }
            state.pc += 2
            break
        case .Unknown(let operationCode):
            print("!!!!! Skipping unknown operation code: \(operationCode.fullDescription)")
            state.pc += 2
            break
        default:
            print("!!!!! Skipping not implemented operation: \(operation)")
            state.pc += 2
            break
        }
    }
    
    public func fetchOperationCode(memoryLocation: UShort) -> UShort {
        let firstByte = state.randomAccessMemory[Int(memoryLocation)]
        let secondByte = state.randomAccessMemory[Int(memoryLocation + 1)]
        let opCode: UShort = (UShort(firstByte) << 8) | UShort(secondByte) // chip8 uses big endian
        return opCode
    }
}
