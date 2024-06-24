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
    /// 4096 bytes of memory. Chip8 uses BIG ENDIAN (when saving UShort value  we save upper byte at address x and then lower byte at memory address x+1)
    private(set) var randomAccessMemory: [UByte]
    
    /// 15 general purpose registers and 1 "carry-flag" register
    private(set) var registers: [UByte]
    private(set) var indexRegister: UShort
    /// Program Counter - points to memory location of operation that will be executed next. Each operation takes 2 memory addresses so increment should be done by 2
    private(set) var pc: UShort
    
    private(set) var callStack: [UShort] // 16 levels // Saves Current ProgramCounter
    private(set) var callStackPointer: UShort // Remembers which level of stack is used
    
    // if set above 0 they are counting down. Counting at 60Hz
    private(set) var delayTimer: UByte
    private(set) var soundTimer: UByte // Buzzer when reaches zero
    
    /// One dimension Byte array representing output screen (64x32). One byte represents one pixel (0: Black and 255: White), order from left top of the screen.
    private(set) var Output: [UByte] // 64x32
    private(set) var InputKeys: [UByte] // 16 keys
    
    init(font: [UByte] = Chip8EmuCore.DefaultFontSet) {
        self.randomAccessMemory = Array(repeating: 0, count: 4096)
        
        self.registers = Array(repeating: 0, count: 16)
        self.indexRegister = 0
        self.pc = 0x200 // program counter starts at hex location 0x200 (512)
        
        self.callStack = Array(repeating: 0, count: 16)
        self.callStackPointer = 0
        
        self.delayTimer = 0
        self.soundTimer = 0
        
        self.Output = Array(repeating: 0, count: 64*32)
        self.InputKeys = Array(repeating: 0, count: 16)
        
        // Load font set
        self.randomAccessMemory.replaceSubrange(0...0x50, with: font)
    }
    
    public func loadProgram(_ programROM: [UByte]) {
        // Load program rom into system ram at location 0x200
        self.randomAccessMemory.replaceSubrange(0x200...(0x200+programROM.count), with: programROM)
    }
    
    public func emulateCycle() async{
        // Fetch Opcode
        let opCode: UShort = fetchOperationCode(memoryLocation: pc)

        // Decode Opcode
        guard let operation = Chip8Operation.decode(operationCode: opCode) else { return }
        // Execute Opcode
        executeOperation(operation: operation)
        
        try? await Task.sleep(nanoseconds: 5_000_000) // TODO: test speed
        
        // Update timers
        
//        let i = Int.random(in: 0..<64*32)
//        OutputScreen[i] = 1
    }
    
    private func executeOperation(operation: Chip8Operation) {
        switch operation {
        case .ClearScreen:
            self.Output = Array(repeating: 0, count: 64*32)
            self.pc += 2
            break
        case .Jump(let location):
            self.pc = location
            break
        case .SetValueToRegister(let registerNumber, let value):
            self.registers[registerNumber] = value
            self.pc += 2
            break
        case .AddValueToRegister(let registerNumber, let value):
            self.registers[registerNumber] += value
            self.pc += 2
            break
        case .SetValueToIndexRegister(let value):
            self.indexRegister = value
            self.pc += 2
            break
        case .DrawSprite(let height, let registerX, let registerY):
            let locationX = Int(registers[registerX])
            let locationY = Int(registers[registerY])
            
            // TODO: Collision flag, pixel by pixel bit by bit.
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
                    let spritePixel = (sprite[j] & UInt8(NSDecimalNumber(decimal: pow(2, (7-i))).intValue)) >> (7-i)
                    let pixel = spritePixel == 0 ? Output[locationX+i + (locationY+j)*64] : Output[locationX+i + (locationY+j)*64] ^ spritePixel
                    if pixel > 1 {
                        return
                    }
                    Output[locationX+i + (locationY+j)*64] = pixel
                }
            }
            self.pc += 2
            break
        default:
            print("Operation execution not implemented")
            return
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
