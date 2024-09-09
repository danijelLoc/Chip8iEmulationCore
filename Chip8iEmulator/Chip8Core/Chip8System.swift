//
//  Chip8System.swift
//  Chip8iEmulator
//
//  Created by Danijel Stracenski on 28.05.2024..
//

import Foundation

public typealias UByte = UInt8
public typealias UShort = UInt16

///
/// Chip 8 System
///
class Chip8System {
    /// 4096 Bytes of memory. Chip8 uses BIG ENDIAN (when saving UShort value  we save upper byte at address x and then lower byte at memory address x+1)
    private(set) var randomAccessMemory: [UByte]
    
    /// 15 general purpose registers and 1 "carry-flag" register
    private(set) var registers: [UByte]
    private(set) var indexRegister: UShort
    /// Program Counter - points to memory location of operation code that will be executed next. Default value 0x200 (512). Each operation code takes 2 memory addresses so increment should be done by 2.
    private(set) var pc: UShort
    
    private(set) var callStack: [UShort] // 16 levels // Saves Current ProgramCounter
    private(set) var callStackPointer: UShort // Remembers which level of stack is used
    
    // if set above 0 they are counting down. Counting at 60Hz
    private(set) var delayTimer: UByte
    private(set) var soundTimer: UByte // Buzzer when reaches zero
    
    /// One dimension Byte array representing output screen (64x32). One byte represents one pixel (0: Black and 255: White), order from left top of the screen.
    private(set) var Output: [UByte] // 64x32
    /// Boolean Array containing states of all 16 keys of Chip8. If value at index X is set to True it means that button X is pressed. Chip8 has buttons marked with Hex digits from 0,1,2 ... E, F
    private(set) var InputKeys: [Bool] // 16 keys
    
    init(font: [UByte] = Chip8System.DefaultFontSet) {
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
        
        // Load font set
        self.randomAccessMemory.replaceSubrange(0..<80, with: font)
    }
    
    /// Load program rom into system ram at location 0x200 (512) where pc starts at default.
    public func loadProgram(_ programROM: [UByte]) {
        self.randomAccessMemory.replaceSubrange(512..<(512+programROM.count), with: programROM)
    }
    
    public func emulateCycle() async{
        // Fetch Opcode
        let opCode: UShort = fetchOperationCode(memoryLocation: pc)
        print(opCode.fullDescription)
        // Decode Opcode
        let operation = Chip8Operation.decode(operationCode: opCode)
        print(operation)
        // Execute Opcode
        executeOperation(operation: operation)
        
        // Update timers
        
    }
    
    package func executeOperation(operation: Chip8Operation) {
        switch operation {
        case .ClearScreen:
            self.Output = Array(repeating: 0, count: 64*32)
            self.pc += 2
            break
            
        case .JumpToAddress(let location):
            self.pc = location
            break
        case .JumpToAddressPlusV0(let location):
            self.pc = location &+ UShort(registers[0])
            break
        case .CallSubroutine(let address):
            self.callStack[Int(callStackPointer)] = self.pc + 2
            self.callStackPointer += 1
            self.pc = address
        case .ReturnFromSubroutine:
            self.callStackPointer -= 1
            self.pc = callStack[Int(callStackPointer)]
            self.callStack[Int(callStackPointer)] = 0
            
        case .ConditionalSkipRegisterValue(let registerIndex, let value, let isEqual):
            let registerValue = self.registers[registerIndex]
            if isEqual && registerValue == value || !isEqual && registerValue != value {
                self.pc += 4
            } else {
                self.pc += 2
            }
        case .ConditionalSkipRegisters(let registerXIndex, let registerYIndex, let isEqual):
            let registerXValue = self.registers[registerXIndex]
            let registerYValue = self.registers[registerYIndex]
            if isEqual && registerXValue == registerYValue || !isEqual && registerXValue != registerYValue {
                self.pc += 4
            } else {
                self.pc += 2
            }
        case .ConditionalSkipKeyPress(let registerIndex, let isPressed):
            let registerValue = registers[registerIndex]
            let keyState = InputKeys[Int(registerValue)] // TODO: This could easily be out of range and crash the app... throw error? each app should handle it.
            if isPressed && keyState || !isPressed && !keyState {
                self.pc += 4
            } else {
                self.pc += 2
            }
            
        case .SetValueToRegister(let registerIndex, let value):
            self.registers[registerIndex] = value
            self.pc += 2
            break
        case .SetValueToRegisterWithRandomness(let registerIndex, let value):
            let randomValue = UByte.random(in: UByte.min...UByte.max)
            self.registers[registerIndex] = value & randomValue
            self.pc += 2
            break
        case .AddValueToRegister(let registerIndex, let value):
            self.registers[registerIndex] = registers[registerIndex] &+ (value) // overflow ignored here
            self.pc += 2
            break
        case .SetValueToIndexRegister(let value):
            self.indexRegister = value
            self.pc += 2
            break
            
        case .RegistersOperation(let registerXIndex, let registerYIndex, let registersOperation):
            switch registersOperation {
            case .setToSecond:
                registers[registerXIndex] = registers[registerYIndex]
            case .bitwiseOr:
                registers[registerXIndex] = registers[registerXIndex] | registers[registerYIndex]
            case .bitwiseAnd:
                registers[registerXIndex] = registers[registerXIndex] & registers[registerYIndex]
            case .bitwiseXOR:
                registers[registerXIndex] = registers[registerXIndex] ^ registers[registerYIndex]
            case .addition:
                let res = registers[registerXIndex].addingReportingOverflow(registers[registerYIndex])
                registers[registerXIndex]  = res.partialValue
                registers[15] = res.overflow ? 1 : 0
            case .subtractSecondFromFirst:
                let res = registers[registerXIndex].subtractingReportingOverflow(registers[registerYIndex])
                registers[registerXIndex]  = res.partialValue
                registers[15] = res.overflow ? 0 : 1
            case .subtractFirstFromSecond:
                let res = registers[registerYIndex].subtractingReportingOverflow(registers[registerXIndex])
                registers[registerXIndex]  = res.partialValue
                registers[15] = res.overflow ? 0 : 1
            case .shiftRight:
                let res = registers[registerXIndex] >> 1
                let overflow = 0x01 & registers[registerXIndex]
                registers[registerXIndex]  = res
                registers[15] = overflow
            case .shiftLeft:
                let res = registers[registerXIndex] << 1
                let overflow = (0x80 & registers[registerXIndex]) >> 7
                registers[registerXIndex]  = res
                registers[15] = overflow
            }
            self.pc += 2
        
        case .RegistersStorage(let maxIncludedRegisterIndex, let isRestoring):
            var address = Int(indexRegister);
            for i in 0...maxIncludedRegisterIndex {
                if isRestoring {
                    registers[i] = randomAccessMemory[address]
                }else{
                    randomAccessMemory[address] = registers[i]
                }
                address += 1
            }
            self.pc += 2
        
        case .RegisterBinaryToDecimal(let registerXIndex):
            let decimalValue = Int(registers[registerXIndex])
            let thirdDecimalDigit = decimalValue % 10
            let secondDecimalDigit = ((decimalValue - thirdDecimalDigit) / 10) % 10
            let firstDecimalDigit = (decimalValue - secondDecimalDigit * 10 - thirdDecimalDigit) / 100
            
            randomAccessMemory[Int(indexRegister)] = UByte(firstDecimalDigit)
            randomAccessMemory[Int(indexRegister)+1] = UByte(secondDecimalDigit)
            randomAccessMemory[Int(indexRegister)+2] = UByte(thirdDecimalDigit)
    
            self.pc += 2
             
        case .DrawSprite(let height, let registerXIndex, let registerYIndex):
            let locationX = Int(registers[registerXIndex])
            let locationY = Int(registers[registerYIndex])
            
            registers[15] = 1 // collision
            
            let spriteStartAddress = Int(self.indexRegister)
            let spriteEndAddress = spriteStartAddress + height // Chip8 Spite is always 8 pixels (8 bits in memory) wide. One memory address stores one row of sprite. So whole sprite is <height> bytes long
            let sprite = Array(self.randomAccessMemory[spriteStartAddress..<spriteEndAddress])
            for j in 0..<height {
                if locationY+j >= 32 {
                    break
                }
                for i in 0..<8 {
                    if locationX+i >= 64 {
                        break
                    }
                    if locationX+i + (locationY+j)*64 >= Output.count {
                        continue
                    }
                    let pixelBefore = Output[locationX+i + (locationY+j)*64]
                    let spritePixel = (sprite[j] & UInt8(NSDecimalNumber(decimal: pow(2, (7-i))).intValue)) >> (7-i)
                    let pixel = spritePixel == 0 ? Output[locationX+i + (locationY+j)*64] : Output[locationX+i + (locationY+j)*64] ^ spritePixel
                    if pixel > 1 {
                        print("Error unexpected pixel value") // TODO: THROW
                        return
                    }
                    Output[locationX+i + (locationY+j)*64] = pixel
                    if (pixel != pixelBefore && pixelBefore == 1) {
                        registers[15] = 1 // collision
                    }
                }
            }
            self.pc += 2
            break
        case .Unknown(let operationCode):
            print("!!!!! Skipping unknown operation code: \(operationCode.fullDescription)")
            self.pc += 2
            break
        default:
            print("!!!!! Skipping not implemented operation: \(operation)")
            self.pc += 2
            break
        }
    }
    
    private func fetchOperationCode(memoryLocation: UShort) -> UShort {
        let firstByte = randomAccessMemory[Int(memoryLocation)]
        let secondByte = randomAccessMemory[Int(memoryLocation + 1)]
        let opCode: UShort = (UShort(firstByte) << 8) | UShort(secondByte) // chip8 uses big endian
        return opCode
    }
    
    public var UpcomingOperationCode: UShort {
        get {
            fetchOperationCode(memoryLocation: pc)
        }
    }
}
