import Foundation
import Service

/// Config options for a `DisqueClient`.
public struct DisqueClientConfig: Codable, ServiceType {

	/// The Disque server's hostname.
	public var hostname: String

	/// The Disque server's port.
	public var port: Int

	/// The Disque server's optional password.
	public var password: String?

	/// Creates a new `DisqueClientConfig`.
	public init(hostname: String = "localhost", port: Int = 7711, password: String? = nil) {
		self.hostname = hostname
		self.port = port
		self.password = password
	}

	/// Creates a new `DisqueClientConfig` from a Disque configuration URL.
	public init(url: URL) {
		self.hostname = url.host ?? "localhost"
		self.port = url.port ?? 7711
		self.password = url.password
	}

	/// See `ServiceType`.
	public static func makeService(for worker: Container) throws -> DisqueClientConfig {
		return .init()
	}
}
