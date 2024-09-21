//
//  Chip8SystemState.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 14.09.2024..
//

import Foundation

/// State of the emulated Chip8 system, including RAM, Registers, Call Stack, Timers, Program Counter, Input Keys States and Output Screen Buffer.
public struct Chip8SystemState: Codable {
    /// 4096 Bytes of memory. Chip8 uses BIG ENDIAN (when saving UShort value  we save upper byte at address x and then lower byte at memory address x+1). Whole program ROM is loaded into the RAM at starting PC address of 0x200.
    public var randomAccessMemory: [UByte]
    
    /// 15 general purpose registers and 1 "carry-flag" register. Starting from V0 to VF (register with index 0xF or 15 in decimal)
    public var registers: [UByte]
    public var indexRegister: UShort
    /// Program Counter - points to memory location of operation code that will be executed next. Default value 0x200 (512). Each operation code takes 2 memory addresses so increment should be done by 2.
    public var pc: UShort
    
    /// Saves Current ProgramCounter for later after returning from subroutines. 16 levels
    public var callStack: [UShort]
    /// Remembers which level of stack will be used for next push
    public var callStackPointer: UShort
    
    /// if set above 0 timer is counting down. Counting at 60Hz
    public var delayTimer: UByte
    /// if set above 0 system is beeping and timer is counting down. Counting at 60Hz.
    public var soundTimer: UByte
    
    /// One dimension Byte array representing output screen (64 width x 32 height). One bit represents one pixel, order from left top of the screen. Rows saved in on dimensional array one after another.
    public var Output: [Bool] // 64x32
    /// Boolean Array containing states of all 16 keys of Chip8. System has buttons marked with Hex digits from 0,1,2 ... E, F. If value at index X is set to True it means that X-th button is pressed.
    public var InputKeys: [Bool] // 16 keys
    
    /// Key for FX0A command that was registered to be pressed and now needs to be released.
    public var InputKeyIndexToBeReleased: UByte?
    
    /// Address of the start of memory where system font is saved. Font is made of 16 character and each takes 5 bytes so 80 bytes from starting address is taken by font data.
    public var fontStartingLocation: UShort
    
    public init() {
        self.randomAccessMemory = Array(repeating: 0, count: 4096)
        
        self.registers = Array(repeating: 0, count: 16)
        self.indexRegister = 0
        self.pc = 512 // program counter starts at hex location 0x200 (decimal 512)
        
        self.callStack = Array(repeating: 0, count: 16)
        self.callStackPointer = 0
        
        self.delayTimer = 0
        self.soundTimer = 0
        
        self.Output = Array(repeating: false, count: 64*32)
        self.InputKeys = Array(repeating: false, count: 16)
        self.InputKeyIndexToBeReleased = nil
        
        self.fontStartingLocation = 0x50 // default location for font 0x50 (decimal 80)
    }
}

/// A wrapper around the emulated program data id and Chip8SystemState. Saved system state can only be used with specific program/game loaded into the system.
public struct EmulationState: Codable {
    /// Unique Id of the program/game ROM data that was loaded into the Chip8System
    public let programContentHash: String
    /// State of Chip8 System with all its registers, stack, memory and output buffer
    public let systemState: Chip8SystemState
}
