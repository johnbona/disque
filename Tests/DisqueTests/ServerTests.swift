@testable import Disque
import XCTest

final class ServerTests: XCTestCase {
	func testServerInfo() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		let info = try disque.info().wait()

		XCTAssert(info.prefix(8) == "# Server")
	}
}
