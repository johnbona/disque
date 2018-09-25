import Redis

/// A Disque client.
public final class DisqueClient: BasicWorker, DatabaseConnection {

	/// Internal Redis client used by the Disque client.
	let redisClient: RedisClient

	/// See `BasicWorker`.
	public var eventLoop: EventLoop {
		return redisClient.eventLoop
	}

	/// See `DatabaseConnection`.
	public typealias Database = DisqueDatabase

	public var isClosed: Bool {
		return redisClient.isClosed
	}

	public func close() {
		redisClient.close()
	}

	/// See `Extendable`.
	public var extend: Extend {
		get {
			return redisClient.extend
		}
		set {
			redisClient.extend = newValue
		}
	}

	/// Creates a new `DisqueClient` from a Redis client.
	init(redisClient: RedisClient) {
		self.redisClient = redisClient
		self.extend = [:]
	}
}
