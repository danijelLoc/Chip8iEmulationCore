//
//  Chip8System.swift
//  Chip8iEmulationCore
//
//  Created by Danijel Stracenski on 28.05.2024..
//

import Foundation


/// Internal Chip8 System CPU module that executes system operation with resulting mutation of system state.
internal class Chip8System {

    private var parser: Chip8OperationParserProtocol
    private var logger: EmulationLoggerProtocol?
    
    private var _state: Chip8SystemState
    private let stateLock = NSLock()  // Lock to synchronise access
    // Thread-safe getter and setter for the state property
    private(set) var state: Chip8SystemState {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _state
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            _state = newValue
        }
    }
    
    internal init(parser: Chip8OperationParserProtocol = Chip8OperationParser(), font: [UByte] = Chip8SystemState.DefaultFontSet, logger: EmulationLoggerProtocol? = .none) {
        self._state = Chip8SystemState()
        self.logger = logger
        self.parser = parser
        // Load font set
        state.randomAccessMemory.replaceSubrange(state.fontStartingLocation.toInt..<(state.fontStartingLocation.toInt+80), with: font)
    }
    
    /// Load program rom into system ram at location 0x200 (512) where pc starts at default.
    internal func loadProgram(_ programROM: [UByte]) {
        state.randomAccessMemory.replaceSubrange(512..<(512+programROM.count), with: programROM)
    }
    
    /// Executes single parsed operation of opcode at memory location saved in PC
    internal func emulateSingleCycle() throws {
        // Fetch Opcode
        let opCode: UShort = try fetchOperationCode(memoryLocation: state.pc)
        // Decode Opcode
        let operation = parser.decode(opCode)
        logger?.log("Parsed \(opCode.hexDescription) -> \(operation)", level: .info)
        
        // Execute Operation
        try executeOperation(operation: operation)
    }
    
    /// Execute single given operation. It takes needed data from systemState and modifies it
    internal func executeOperation(operation: any Chip8OperationCommand) throws {
        if let unknownOperation = operation as? Unknown {
            logger?.log("Unknown operation with code: \(unknownOperation.operationCode.fullDescription)", level: .error)
            throw EmulationError.unknownOpcode(opcode: unknownOperation.operationCode)
        }
        
        operation.execute(state: &self.state)
    }
    
    
    internal func fetchOperationCode(memoryLocation: UShort) throws -> UShort  {
        guard memoryLocation < 0xFFF else {
            logger?.log("Opcode memory location out of bounds, address: \(memoryLocation)", level: .error)
            throw EmulationError.opcodeFetchError(address: memoryLocation)
        }
        let firstByte = state.randomAccessMemory[Int(memoryLocation)]
        let secondByte = state.randomAccessMemory[Int(memoryLocation + 1)]
        let opCode: UShort = (UShort(firstByte) << 8) | UShort(secondByte) // chip8 uses big endian
        return opCode
    }
    
    internal func loadState(_ newState: Chip8SystemState) {
        state = newState
        logger?.log("Loaded state", level: .info)
    }
    
    internal func decreaseDelayTimer() {
        if state.delayTimer == 0 { return }
        state.delayTimer -= 1
    }
    
    internal func decreaseSoundTimer() {
        if state.soundTimer == 0 { return }
        state.soundTimer -= 1
    }
    
    internal func keyDown(key: UByte) {
        state.InputKeys[key.toInt] = true
    }
    
    internal func keyUp(key: UByte) {
        state.InputKeys[key.toInt] = false
    }
}
