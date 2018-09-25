@testable import Disque
import XCTest

final class QueueTests: XCTestCase {
	func testQueueLength() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		// If queue doesn't exist, queue length should return 0.

		var length = try disque.length(of: "\(#function)").wait()

		XCTAssertEqual(length, 0)

		// If queue does exist, queue length should return number of jobs in the queue.

		_ = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		length = try disque.length(of: "\(#function)").wait()

		XCTAssertEqual(length, 1)
	}

	func testPauseQueue() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		var queueState = try disque.pause(queue: "\(#function)", state: .all).wait()
		var queueInfo = try disque.metrics(of: "\(#function)").wait()

		XCTAssertEqual(queueState, .all)
		XCTAssertNotNil(queueInfo)
		XCTAssertEqual(queueInfo!.pauseState, .all)

		queueState = try disque.pause(queue: "\(#function)", state: .none).wait()
		queueInfo = try disque.metrics(of: "\(#function)").wait()

		XCTAssertEqual(queueState, .none)
		XCTAssertNotNil(queueInfo)
		XCTAssertEqual(queueInfo!.pauseState, .none)
	}

	func testQueueMetrics() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		// If queue doesn't exist, queue metrics should return nil.

		var queueInfo = try disque.metrics(of: "\(#function)").wait()

		XCTAssertNil(queueInfo)

		// If queue does exist, queue metrics should return the queue info.

		_ = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		queueInfo = try disque.metrics(of: "\(#function)").wait()

		XCTAssertNotNil(queueInfo)
		XCTAssertEqual(queueInfo!.name, "\(#function)")
		XCTAssertEqual(queueInfo!.length, 1)
		XCTAssertEqual(queueInfo!.idle, 0)
		XCTAssertEqual(queueInfo!.blocked, 0)
		XCTAssertEqual(queueInfo!.importFrom, [])
		XCTAssertEqual(queueInfo!.importRate, 0)
		XCTAssertEqual(queueInfo!.jobsIn, 1)
		XCTAssertEqual(queueInfo!.jobsOut, 0)
		XCTAssertEqual(queueInfo!.pauseState, .none)
	}
}
