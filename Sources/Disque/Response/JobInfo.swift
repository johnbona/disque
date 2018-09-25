import Foundation
import Redis

public enum JobState: String {

	/// Job is waiting to be synchronously replicated.
	case waitingReplication = "wait-repl"

	/// Job is waiting to be processed.
	case queued

	/// Job is being processed or waiting for delay to expire.
	case active

	/// Job has been completed.
	case acked
}

/// Struct returned by Disque when getting info about a job (`SHOW`).
public struct JobInfo<C: Codable> {

	/// Cluster-wide unique identifier.
	public let id: String

	/// Name of the queue the job is residing in.
	public let queue: String

	/// Current job state.
	public let state: JobState

	/// Number of seconds left before the job is deleted even if not completed.
	public let timeToLive: Int

	/// Job creation time (local to node).
	public let createdAt: Date

	/// Number of seconds before the job was first placed into the queue.
	public let delay: Int

	/// Number of seconds after which, if the job is not postponed or no ACK is received, job is automatically re-queued.
	public let retryInterval: Int

	/// Number of seconds left before the job is automatically re-queued.
	public let nextRetryWithin: Int

	/// Best-effort count of negative acknowledgements received for the job.
	/// - Note: NACKs explicitly indicate a worker was unable to process the job and to place the job immediately back onto the queue.
	public let nacks: Int

	/// Best-effort count of times the job was re-queued (excluding NACKs).
	/// - Note: Additional deliveries possibly indicate:
	///   - The job was lost either by a worker crashing while processing the job
	///   - A worker was unable to process the job before the expiration of the retry interval.
	public let additionalDeliveries: Int

	/// Nodes the job has been delivered to for replication.
	public let nodesDelivered: [String]

	/// Nodes that are confirmed to have a copy of the job.
	public let nodesConfirmed: [String]

	/// The body of the job.
	/// - Note: Maximum job body size is 4 GB.
	public let body: C?

	/// Creates a new `DisqueJob`.
	public init(
		id: String,
		queue: String,
		state: JobState,
		timeToLive: Int,
		createdAt: Date,
		delay: Int,
		retryInterval: Int,
		nextRetryWithin: Int,
		nacks: Int,
		additionalDeliveries: Int,
		nodesDelivered: [String],
		nodesConfirmed: [String],
		body: C?
	) {
		self.id = id
		self.queue = queue
		self.state = state
		self.timeToLive = timeToLive
		self.createdAt = createdAt
		self.delay = delay
		self.retryInterval = retryInterval
		self.nextRetryWithin = nextRetryWithin
		self.nacks = nacks
		self.additionalDeliveries = additionalDeliveries
		self.nodesDelivered = nodesDelivered
		self.nodesConfirmed = nodesConfirmed
		self.body = body
	}

	/// Creates a new `DisqueJob` from an array of `RedisData`.
	public init(redisData: [RedisData]) throws {
		self.id = redisData[1].string!
		self.queue = redisData[3].string!
		self.state = JobState(rawValue: redisData[5].string!)!
		self.timeToLive = redisData[9].int!
		self.createdAt = Date(timeIntervalSince1970: (Double(redisData[11].int!) / 1000000) / 1000)
		self.delay = redisData[13].int!
		self.retryInterval = redisData[15].int!
		self.nextRetryWithin = redisData[25].int! / 1000
		self.nacks = redisData[17].int!
		self.additionalDeliveries = redisData[19].int!
		self.nodesDelivered = redisData[21].array!.map { $0.string! }
		self.nodesConfirmed = redisData[23].array!.map { $0.string! }
		self.body = try redisData[29].data.map { try JSONDecoder().decode(C.self, from: $0) }
	}
}
