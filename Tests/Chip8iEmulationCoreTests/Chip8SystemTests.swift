import XCTest
@testable import Chip8iEmulationCore

final class Chip8SystemTests: XCTestCase {
    func testLoadFontAndChip8ProgramRomIntoSystemRam() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        let system = Chip8System()
        
        var ram = await system.exportState().randomAccessMemory
        let fontStartLocation = await system.exportState().fontStartingLocation.toInt
        
        await system.loadFont()
        ram = await system.exportState().randomAccessMemory
        XCTAssertEqual(Chip8SystemState.DefaultFontSet[0], ram[fontStartLocation]) // first byte of font
        XCTAssertEqual(Chip8SystemState.DefaultFontSet[0x4F], ram[fontStartLocation + Int(0x4F)]) // last (80th) byte of font at index 0x4F (79)
        
        let programROM: [UByte] = [0x00, 0x01]
        await system.loadProgram(programROM)
        ram = await system.exportState().randomAccessMemory
        XCTAssertEqual(4096, ram.count)
        XCTAssertEqual(programROM[0], ram[0x200])
        XCTAssertEqual(programROM[1], ram[0x201])
    }
    
    func testExecuteOperationAndPcChange() async throws {
        let parser = Chip8OperationParser();
        let system = Chip8System()
        let programROM: [UByte] = [0x00, 0xE0]
        await system.loadProgram(programROM)
        
        var pc = (await system.exportState()).pc
        XCTAssertEqual(0x200, pc)
        var opCodeToBeExecuted = try await system.fetchOperationCode(memoryLocation: pc)
        XCTAssertEqual(UShort(0x00E0), opCodeToBeExecuted) // Chip8 uses big endian
        
        // Execute the operation
        try await system.executeOperation(operation: parser.decode(opCodeToBeExecuted))
        
        // PC should change
        pc = (await system.exportState()).pc
        XCTAssertEqual(0x202, pc)
        opCodeToBeExecuted = try await system.fetchOperationCode(memoryLocation: pc)
        XCTAssertEqual(UShort(0x0), opCodeToBeExecuted)
    }
    
    func testDrawOperationAndCollision() async throws {
        let system = Chip8System()
        await system.loadFont()
        
        // Set value 2 into V0, other registers are set to zero
        try await system.executeOperation(operation: SetValueToRegister(registerIndex: 0, value: 2))
        
        // Set address of font character at the index 2 into I. In default font this is the digit 2 character itself.
        try await system.executeOperation(operation: SetFontCharacterAddressToIndexRegister(registerIndex: 0))
        
        
        // Draw the digit 2 character at the location x=0, y=0 (registers 3 and 4 have initial zero value inside them)
        try await system.executeOperation(operation: DrawSprite(height: 0x5, registerXIndex: 3, registerYIndex: 4))
        //print(EmulationConsoleLogger.getStringOutput((await system.exportState()).Output, width: 64, height: 32))
        
        // Cut out selected screen area x0y0 x8y5
        var selectedArea = (await system.exportState()).output.getSelectedArea(locationX: 0, locationY: 0, selectedWidth: 8, selectedHeight: 5, totalWidth: 64, totalHeight: 32)
        // [Bool] pixels -> [Byte] sprite data where 1 byte is 1 row
        var selectedAreaData = selectedArea?.toRowsBytes(totalWidth: 8, totalHeight: 5)
        
        // digit 2 font character byte representation
        let fontCharacterStartingAddress: Int = (await system.exportState()).fontStartingLocation.toInt + 2 * 5
        let fontCharacterData = Array((await system.exportState()).randomAccessMemory[fontCharacterStartingAddress..<fontCharacterStartingAddress+5])
        var registers = (await system.exportState()).registers
        XCTAssertEqual(fontCharacterData, selectedAreaData) // Font character is drawn on the screen
        XCTAssertEqual(0, registers[0xF]) // No collision
        
        // Test collision
        // Draw the digit 2 on the same place as before -> Collision
        try await system.executeOperation(operation: DrawSprite(height: 0x5, registerXIndex: 3, registerYIndex: 4))
        
        selectedArea = (await system.exportState()).output.getSelectedArea(locationX: 0, locationY: 0, selectedWidth: 8, selectedHeight: 5, totalWidth: 64, totalHeight: 32)
        selectedAreaData = selectedArea?.toRowsBytes(totalWidth: 8, totalHeight: 5)
        registers = (await system.exportState()).registers
        XCTAssertNotEqual(fontCharacterData, selectedAreaData) // Font character is not on the screen anymore
        XCTAssertEqual([0, 0, 0, 0, 0], selectedAreaData) // That area is now empty/erased cause of collision
        XCTAssertEqual(1, registers[0xF]) // Collision was registered
    }
    
    func testLoadAndExportState() async throws {
        let parser = Chip8OperationParser();
        let system = Chip8System()
        
        let programROM: [UByte] = [0x00, 0xE0]
        await system.loadProgram(programROM)
        
        let initialSavedState = (await system.exportState())
        
        var pc = await system.exportState().pc
        XCTAssertEqual(0x200, pc)
        var opCodeToBeExecuted = try await system.fetchOperationCode(memoryLocation: pc)
        XCTAssertEqual(UShort(0x00E0), opCodeToBeExecuted) // Chip8 uses big endian
        
        // Execute the operation
        try await system.executeOperation(operation: parser.decode(opCodeToBeExecuted))
        pc = await system.exportState().pc
        // PC of system should change
        XCTAssertEqual(0x202, pc)
        opCodeToBeExecuted = try await system.fetchOperationCode(memoryLocation: pc)
        XCTAssertEqual(UShort(0x0), opCodeToBeExecuted)
        
        XCTAssertEqual(0x200, initialSavedState.pc) // Exported initial state was not changed
        
        await system.loadState(initialSavedState)
        pc = await system.exportState().pc
        XCTAssertEqual(0x200, pc)
        opCodeToBeExecuted = try await system.fetchOperationCode(memoryLocation: pc)
        XCTAssertEqual(UShort(0x00E0), opCodeToBeExecuted) // Initial state successfully loaded back
    }
    
    func testKeys() async {
        let system = Chip8System()
        let key1: UByte = 0x1
        let key1Index = key1.toInt // Chip8 key 0x1 is saved at the index 1 in the (await system.exportState()).InputKeys. Same for the rest of the 16 keys. 0x0 at index 0 and 0xF at index 15
        var inputKeys = await system.exportState().inputKeys
        XCTAssertEqual(false, inputKeys[key1.toInt]) // All keys initially released (not pressed)
        
        // Press down one key
        await system.keyDown(key: key1)
        inputKeys = await system.exportState().inputKeys
        XCTAssertEqual(true, inputKeys[key1Index])
        
        // Release the key
        await system.keyUp(key: key1)
        inputKeys = await system.exportState().inputKeys
        XCTAssertEqual(false, inputKeys[key1Index]) // Key should be released now
        
        let keyF: UByte = 0xF
        let keyFIndex = keyF.toInt
        
        // Multiple keys can be pressed down at the same time
        await system.keyDown(key: key1)
        await system.keyDown(key: keyF)
        inputKeys = await system.exportState().inputKeys
        XCTAssertEqual(true, inputKeys[key1Index])
        XCTAssertEqual(true, inputKeys[keyFIndex])
        
        await system.keyUp(key: key1)
        await system.keyUp(key: keyF)
        inputKeys = await system.exportState().inputKeys
        
        XCTAssertEqual(false, inputKeys[key1Index])
        XCTAssertEqual(false, inputKeys[keyFIndex])
    }

    func testPerformanceExample() throws {
        // TODO: Implement
        // This is an example of a performance test case.
//        measure {
            // Put the code you want to measure the time of here.
//        }
    }
}
