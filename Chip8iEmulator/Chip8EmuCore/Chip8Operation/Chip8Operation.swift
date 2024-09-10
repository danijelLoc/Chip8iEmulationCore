//
//  Chip8Operation.swift
//  Chip8iEmulator
//
//  Created by Danijel Stracenski on 24.06.2024..
//

import Foundation



public enum Chip8Operation {
    
    /// Unknown operation whose code could not have been parsed
    case Unknown(operationCode: UShort)
    
    /// Clears the screen by setting all pixels to 0.
    ///
    /// 0x00E0
    case ClearScreen
    
    /// Calls the subroutine at the given address. First value of PC + 2 (address of next instruction) will be saved into call stack. Then PC will be set to address in arguments
    ///
    /// 2NNN - call subroutine at NNN
    case CallSubroutine(address: UShort)
    /// Returns from the subroutine by setting the PC to address removed from top of call stack (pop action)
    ///
    /// 00EE - return from subroutine
    case ReturnFromSubroutine
    /// Jump to address by setting PC to it.
    ///
    /// 1NNN - jump (set PC to NNN)
    case JumpToAddress(address: UShort)
    /// Jump  to (address + register0) by setting PC to it.
    ///
    /// BNNN - jump (set PC to NNN+V0) Note: V0 is register at the index 0
    case JumpToAddressPlusV0(address: UShort)
    
    /// Conditional skip next instruction on comparing register (at the index X) to the value. if condition is met then we will move PC by 4 memory location instead of 2 (current instruction takes 2 memory locations).
    ///
    /// 3XNN - Skip next instruction if VX == NN
    ///
    /// 4XNN - Skip next instruction if VX != NN
    case ConditionalSkipRegisterValue(registerIndex: Int, value: UByte, isEqual: Bool)
    /// Conditional skip next instruction on comparing VX to VY. If condition is met then we will move PC by 4 memory location instead of 2 (current instruction takes 2 memory locations).
    ///
    /// 5XY0 - Skip next instruction if VX == VY
    ///
    /// 9XY0 - Skip next instruction if VX != VY
    case ConditionalSkipRegisters(registerXIndex: Int, registerYIndex: Int, isEqual: Bool)
    /// Conditional skip next instruction if key stored in VX is pressed or not. If condition is met then we will move PC by 4 memory location instead of 2 (current instruction takes 2 memory locations).
    ///
    /// EX9E - Skip next instruction if key stored in VX is pressed
    ///
    /// EXA1 - Skip next instruction if key stored in VX is not pressed
    case ConditionalSkipKeyPress(registerIndex: Int, isPressed: Bool)
    /// Conditional wait for key stored in VX to be pressed to move to next instruction. If key is pressed then increase PC by 2 as always, otherwise don't change PC and remain at current command..
    ///
    /// FX0A - Wait until key stored at register is pressed
    case ConditionalPauseUntilKeyPress(registerIndex: Int)
    
    /// Set value to register
    ///
    /// 6XNN - set value NN to register X
    case SetValueToRegister(registerIndex: Int, value: UByte)
    /// Set value to register without carry flag change
    ///
    /// 7XNN - add value NN to register X, NOTE: carry flag is not changed
    case AddValueToRegister(registerIndex: Int, value: UByte)
    /// Set value  to Index register I
    ///
    /// ANNN - set value NNN to Index register
    case SetValueToIndexRegister(value: UShort)
    /// Set  (value & randomByte) to register
    ///
    /// CXNN - set value (NN & Random) to register X
    case SetValueToRegisterWithRandomness(registerIndex: Int, value: UByte)
    
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
    /// 8XY4 - Set VX into VX - VY
    /// 
    /// 8XY4 - Set VX into VY - VX
    /// 
    /// 8XY6 - Set VX into VX >> 1
    /// 
    /// 8XYE - Set VX into VX << 1
    case RegistersOperation(registerXIndex: Int, registerYIndex: Int, operation: RegistersOperation)

    /// Storing values from registers (from register0 til and including registerX) into memory addresses starting from I, or restoring them.
    ///
    /// FX55 - Store registers up to index X in memory addresses starting from the one stored in I
    /// 
    /// FX65 - Restore registers up to index X from memory addresses starting from the one stored in I
    case RegistersStorage(maxIncludedRegisterIndex: Int, isRestoring: Bool)
    /// Store decimal digits of VX value (UByte in decimal format so 000 - 255) in memory addresses starting from the one stored in register I.
    /// Leftmost digits is saved to address I, second one is saved at I+1 and third digit is saved at I+2
    ///
    /// FX33 - Store decimal digits of VX value (in decimal format 000 - 255) in memory addresses starting from the one stored in I
    case RegisterStoreDecimalDigits(registerXIndex: Int)
    
    /// Store value of delay timer into registerX
    ///
    /// FX07 sets VX to the current value of the delay timer
    case DelayTimerStore(registerIndex: Int)
    /// Set value of VX to delay timer
    ///
    /// FX15 sets the delay timer to the value in VX
    case DelayTimerSet(registerIndex: Int)
    /// Set value of VX to sound timer
    ///
    /// FX18 sets the sound timer to the value in VX
    case SoundTimerSet(registerIndex: Int)
    
    /// Draw sprite that  has given height at screen location pX = value in register with index X, pY= value in register with index Y. Sprite is fetched from memory starting at address stored in index register I. 
    /// One pixel is one bit so sprite width is always 8 pixels, hence one pixel row fits into one memory address. Sprite is saved in memory addresses I..<I+height.
    /// If any pixel is turned off after this, indicating collision, then value of register 15 (VF) is set to 1.
    ///
    /// DXYN - draws N pixels tall sprite from memory location that Index register has onto screen at location pX = value of X register, pY= value of Y register
    case DrawSprite(height: Int, registerXIndex: Int, registerYIndex: Int)
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
