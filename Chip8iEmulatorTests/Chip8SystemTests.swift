//
//  Chip8iEmulatorTests.swift
//  Chip8iEmulatorTests
//
//  Created by Danijel Stracenski on 28.05.2024..
//

import XCTest
@testable import Chip8iEmulator

final class Chip8SystemTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testLoadFontAndChip8ProgramRomIntoSystemRam() async throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        let system = Chip8System()
        XCTAssertEqual(Chip8System.DefaultFontSet[0], system.randomAccessMemory[0]) // first byte of font
        XCTAssertEqual(Chip8System.DefaultFontSet[0x4F], system.randomAccessMemory[0x4F]) // last (80th) byte of font at index 0x4F (79)
        
        let programROM: [UByte] = [0x00, 0x01]
        system.loadProgram(programROM)
        XCTAssertEqual(4096, system.randomAccessMemory.count)
        XCTAssertEqual(programROM[0], system.randomAccessMemory[0x200])
        XCTAssertEqual(programROM[1], system.randomAccessMemory[0x201])
    }
    
    func testEmulateCycleAndPcChange() async {
        let system = Chip8System()
        let programROM: [UByte] = [0x00, 0x01]
        system.loadProgram(programROM)
        
        XCTAssertEqual(0x200, system.pc)
        XCTAssertEqual(UShort(0x0001), system.UpcomingOperationCode) // Chip8 uses big endian
        
        await system.emulateCycle()
        
        XCTAssertEqual(0x202, system.pc)
        XCTAssertEqual(UShort(0x0), system.UpcomingOperationCode)
    }

    func testPerformanceExample() throws {
        // TODO: Implement
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
