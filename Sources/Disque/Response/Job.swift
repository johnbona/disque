import Redis

/// Struct returned by Disque when getting a job (`GETJOB`).
public struct Job<C: Codable> {

	/// Cluster-wide unique identifier.
	public let id: String

	/// Name of the queue the job is residing in.
	public let queue: String

	/// Best-effort count of negative acknowledgements received.
	/// - Note: NACKs explicitly indicate a worker was unable to process the job and to place the job immediately back onto the queue.
	public let nacks: Int

	/// Best-effort count of times the job was re-queued (excluding NACKs).
	/// - Note: Additional deliveries possibly indicate:
	///   - The job was lost either by a worker crashing while processing the job
	///   - A worker was unable to process the job before the expiration of the retry interval.
	public let additionalDeliveries: Int

	/// The body of the job.
	/// - Note: Maximum job body size is 4 GB.
	public let body: C?

	/// Creates a new `DisqueJob` from an array of `RedisData`.
	public init(redisData: [RedisData]) throws {
		self.id = redisData[1].string!
		self.queue = redisData[0].string!
		self.body = try redisData[2].data.map { try JSONDecoder().decode(C.self, from: $0) }
		self.nacks = redisData[4].int!
		self.additionalDeliveries = redisData[6].int!
	}
}
