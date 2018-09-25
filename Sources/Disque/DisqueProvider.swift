import DatabaseKit
import Service

/// Provides base `Disque` services such as database and connection.
public final class DisqueProvider: Provider {

	/// Creates a new `DisqueProvider`.
	public init() {}

	/// See `Provider`.
	public func register(_ services: inout Services) throws {
		try services.register(DatabaseKitProvider())
		services.register(DisqueClientConfig.self)
		services.register(DisqueDatabase.self)

		var databases = DatabasesConfig()
		databases.add(database: DisqueDatabase.self, as: .disque)
		services.register(databases)
	}

	public func didBoot(_ worker: Container) throws -> Future<Void> {
		return .done(on: worker)
	}
}
