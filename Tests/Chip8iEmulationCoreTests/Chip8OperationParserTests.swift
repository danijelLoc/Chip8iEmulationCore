import XCTest
@testable import Chip8iEmulationCore

final class Chip8OperationParserTests: XCTestCase {
    
    func testParseOpCodes() throws {
        let parser = Chip8OperationParser();
        
        XCTAssertEqual(Chip8Operation.ClearScreen, parser.decode(operationCode: 0x00E0))
        
        XCTAssertNotEqual(Chip8Operation.ClearScreen, parser.decode(operationCode: 0x00E1))
        XCTAssertEqual(Chip8Operation.Unknown(operationCode: 0x00E1), parser.decode(operationCode: 0x00E1)) // 0x00E1 is not a valid op code -> unknown
        
        XCTAssertEqual(Chip8Operation.JumpToAddress(address: 0x222), parser.decode(operationCode: 0x1222))
        XCTAssertEqual(Chip8Operation.JumpToAddressPlusV0(address: 0x222), parser.decode(operationCode: 0xB222))
        
        XCTAssertEqual(Chip8Operation.ConditionalSkipRegisterValue(registerIndex: 5, value: 0x22, isEqual: true), parser.decode(operationCode: 0x3522))
        XCTAssertEqual(Chip8Operation.ConditionalSkipRegisterValue(registerIndex: 0xF, value: 0x22, isEqual: true), parser.decode(operationCode: 0x3F22))
        
        XCTAssertEqual(Chip8Operation.RegistersOperation(registerXIndex: 1, registerYIndex: 0, operation: .subtractSecondFromFirst), parser.decode(operationCode: 0x8105))
        XCTAssertEqual(Chip8Operation.RegistersOperation(registerXIndex: 1, registerYIndex: 0xA, operation: .subtractFirstFromSecond), parser.decode(operationCode: 0x81A7))
        
        XCTAssertEqual(Chip8Operation.RegistersOperation(registerXIndex: 1, registerYIndex: 9, operation: .shiftRight), parser.decode(operationCode: 0x8196))
        XCTAssertNotEqual(Chip8Operation.RegistersOperation(registerXIndex: 1, registerYIndex: 9, operation: .shiftLeft), parser.decode(operationCode: 0x8196))
        
        XCTAssertEqual(Chip8Operation.DrawSprite(height: 8, registerXIndex: 3, registerYIndex: 1), parser.decode(operationCode: 0xD318))
        XCTAssertEqual(Chip8Operation.DrawSprite(height: 0xF, registerXIndex: 0xF, registerYIndex: 0xF), parser.decode(operationCode: 0xDFFF))
    }
}
