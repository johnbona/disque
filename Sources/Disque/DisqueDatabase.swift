import DatabaseKit
import Redis
import Service

/// Creates instances of `DisqueClient`.
public final class DisqueDatabase: Database, ServiceType {

	/// This client's configuration.
	public let config: DisqueClientConfig

	/// Creates a new `DisqueDatabase`.
	public init(config: DisqueClientConfig) {
		self.config = config
	}

	/// Creates a new `DisqueDatabase` from a Disque configuration URL.
	public init(url: URL) {
		self.config = DisqueClientConfig(url: url)
	}

	/// See `Database`.
	public func newConnection(on worker: Worker) -> Future<DisqueClient> {
		return RedisClient.connect(
			hostname: config.hostname,
			port: config.port,
			password: config.password,
			on: worker
		) { error in
			print("[Disque] \(error)")
		}
		.map { redisClient in
			return DisqueClient(redisClient: redisClient)
		}
	}

	/// See `ServiceType`.
	public static func makeService(for worker: Container) throws -> DisqueDatabase {
		return try .init(config: worker.make())
	}
}

extension DatabaseIdentifier {

	/// Default identifier for `DisqueClient`.
	public static var disque: DatabaseIdentifier<DisqueDatabase> {
		return .init("disque")
	}
}
