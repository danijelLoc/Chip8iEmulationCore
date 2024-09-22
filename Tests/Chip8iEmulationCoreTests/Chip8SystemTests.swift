import XCTest
@testable import Chip8iEmulationCore

final class Chip8SystemTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }
    
    func testLoadFontAndChip8ProgramRomIntoSystemRam() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        let system = Chip8System()
        XCTAssertEqual(Chip8SystemState.DefaultFontSet[0], system.state.randomAccessMemory[system.state.fontStartingLocation.toInt]) // first byte of font
        XCTAssertEqual(Chip8SystemState.DefaultFontSet[0x4F], system.state.randomAccessMemory[system.state.fontStartingLocation.toInt + Int(0x4F)]) // last (80th) byte of font at index 0x4F (79)
        
        let programROM: [UByte] = [0x00, 0x01]
        system.loadProgram(programROM)
        XCTAssertEqual(4096, system.state.randomAccessMemory.count)
        XCTAssertEqual(programROM[0], system.state.randomAccessMemory[0x200])
        XCTAssertEqual(programROM[1], system.state.randomAccessMemory[0x201])
    }
    
    func testExecuteOperationAndPcChange() throws {
        let parser = Chip8OperationParser();
        let system = Chip8System()
        let programROM: [UByte] = [0x00, 0xE0]
        system.loadProgram(programROM)
        
        XCTAssertEqual(0x200, system.state.pc)
        var opCodeToBeExecuted = try system.fetchOperationCode(memoryLocation: system.state.pc)
        XCTAssertEqual(UShort(0x00E0), opCodeToBeExecuted) // Chip8 uses big endian
        
        // Execute the operation
        try system.executeOperation(operation: parser.decode(operationCode: opCodeToBeExecuted))
        
        // PC should change
        XCTAssertEqual(0x202, system.state.pc)
        opCodeToBeExecuted = try system.fetchOperationCode(memoryLocation: system.state.pc)
        XCTAssertEqual(UShort(0x0), opCodeToBeExecuted)
    }
    
    func testDrawOperationAndCollision() throws {
        let system = Chip8System()
        
        // Set value 2 into V0, other registers are set to zero
        try system.executeOperation(operation: .SetValueToRegister(registerIndex: 0, value: 2))
        
        // Set address of font character at the index 2 into I. In default font this is the digit 2 character itself.
        try system.executeOperation(operation: .SetFontCharacterAddressToIndexRegister(registerIndex: 0))
        
        
        // Draw the digit 2 character at the location x=0, y=0 (registers 3 and 4 have initial zero value inside them)
        try system.executeOperation(operation: .DrawSprite(height: 0x5, registerXIndex: 3, registerYIndex: 4))
        //print(EmulationConsoleLogger.getStringOutput(system.state.Output, width: 64, height: 32))
        
        // Cut out selected screen area x0y0 x8y5
        var selectedArea = system.state.Output.getSelectedArea(locationX: 0, locationY: 0, selectedWidth: 8, selectedHeight: 5, totalWidth: 64, totalHeight: 32)
        // [Bool] pixels -> [Byte] sprite data where 1 byte is 1 row
        var selectedAreaData = selectedArea?.toRowsBytes(totalWidth: 8, totalHeight: 5)
        
        // digit 2 font character byte representation
        let fontCharacterStartingAddress: Int = system.state.fontStartingLocation.toInt + 2 * 5
        let fontCharacterData = Array(system.state.randomAccessMemory[fontCharacterStartingAddress..<fontCharacterStartingAddress+5])
        
        XCTAssertEqual(fontCharacterData, selectedAreaData) // Font character is drawn on the screen
        XCTAssertEqual(0, system.state.registers[0xF]) // No collision
        
        // Test collision
        // Draw the digit 2 on the same place as before -> Collision
        try system.executeOperation(operation: .DrawSprite(height: 0x5, registerXIndex: 3, registerYIndex: 4))
        
        selectedArea = system.state.Output.getSelectedArea(locationX: 0, locationY: 0, selectedWidth: 8, selectedHeight: 5, totalWidth: 64, totalHeight: 32)
        selectedAreaData = selectedArea?.toRowsBytes(totalWidth: 8, totalHeight: 5)
        XCTAssertNotEqual(fontCharacterData, selectedAreaData) // Font character is not on the screen anymore
        XCTAssertEqual([0, 0, 0, 0, 0], selectedAreaData) // That area is now empty/erased cause of collision
        XCTAssertEqual(1, system.state.registers[0xF]) // Collision was registered
    }
    
    func testLoadAndExportState() throws {
        let parser = Chip8OperationParser();
        let system = Chip8System()
        
        let programROM: [UByte] = [0x00, 0xE0]
        system.loadProgram(programROM)
        
        let initialSavedState = system.state
        
        XCTAssertEqual(0x200, system.state.pc)
        var opCodeToBeExecuted = try system.fetchOperationCode(memoryLocation: system.state.pc)
        XCTAssertEqual(UShort(0x00E0), opCodeToBeExecuted) // Chip8 uses big endian
        
        // Execute the operation
        try system.executeOperation(operation: parser.decode(operationCode: opCodeToBeExecuted))
        
        // PC of system should change
        XCTAssertEqual(0x202, system.state.pc)
        opCodeToBeExecuted = try system.fetchOperationCode(memoryLocation: system.state.pc)
        XCTAssertEqual(UShort(0x0), opCodeToBeExecuted)
        
        XCTAssertEqual(0x200, initialSavedState.pc) // Exported initial state was not changed
        
        system.loadState(initialSavedState)
        XCTAssertEqual(0x200, system.state.pc)
        opCodeToBeExecuted = try system.fetchOperationCode(memoryLocation: system.state.pc)
        XCTAssertEqual(UShort(0x00E0), opCodeToBeExecuted) // Initial state successfully loaded back
    }
    
    func testKeys() {
        let system = Chip8System()
        let key1: UByte = 0x1
        let key1Index = key1.toInt // Chip8 key 0x1 is saved at the index 1 in the system.state.InputKeys. Same for the rest of the 16 keys. 0x0 at index 0 and 0xF at index 15
        
        XCTAssertEqual(false, system.state.InputKeys[key1.toInt]) // All keys initially released (not pressed)
        
        // Press down one key
        system.keyDown(key: key1)
        XCTAssertEqual(true, system.state.InputKeys[key1Index])
        
        // Release the key
        system.keyUp(key: key1)
        XCTAssertEqual(false, system.state.InputKeys[key1Index]) // Key should be released now
        
        let keyF: UByte = 0xF
        let keyFIndex = keyF.toInt
        
        // Multiple keys can be pressed down at the same time
        system.keyDown(key: key1)
        system.keyDown(key: keyF)
        XCTAssertEqual(true, system.state.InputKeys[key1Index])
        XCTAssertEqual(true, system.state.InputKeys[keyFIndex])
        
        system.keyUp(key: key1)
        system.keyUp(key: keyF)
        XCTAssertEqual(false, system.state.InputKeys[key1Index])
        XCTAssertEqual(false, system.state.InputKeys[keyFIndex])
    }

    func testPerformanceExample() throws {
        // TODO: Implement
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
}
