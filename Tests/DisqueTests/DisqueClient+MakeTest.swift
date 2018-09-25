@testable import Disque
import Redis
import XCTest

extension DisqueClient {

	/// Creates a test event loop and Disque client.
	static func makeTest() throws -> DisqueClient {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		return try DisqueClient(redisClient:
			RedisClient.connect(
				hostname: "localhost",
				port: 7711,
				password: nil,
				on: group
			) { error in
				XCTFail("\(error)")
			}
			.wait()
		)
	}
}
