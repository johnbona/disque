import Redis

public enum QueuePauseState: String {

	/// Queue is not paused.
	case none

	/// Queue is not accepting jobs.
	case `in`

	/// Queue is not providing jobs.
	case out

	/// Queue is accepting or providing jobs.
	case all
}

/// Struct returned by Disque when getting info about a queue (`QSTAT`).
public struct QueueInfo {

	/// Name of the queue.
	let name: String

	/// Number of jobs in the queue.
	let length: Int

	/// Number of seconds since the queue was created.
	let age: Int

	/// Number of seconds since the queue was last accessed.
	let idle: Int

	/// Number of blocking clients.
	let blocked: Int

	/// Nodes the server is importing jobs from.
	let importFrom: [String]

	/// Rough estimate of the queue's current import rate in jobs/sec from other nodes in the cluster.
	let importRate: Int

	/// Number of jobs added to the queue.
	let jobsIn: Int

	/// Number of jobs removed from the queue.
	let jobsOut: Int

	/// Paused state of the queue.
	let pauseState: QueuePauseState

	/// Creates a new `QueueInfo`.
	public init(
		name: String,
		length: Int,
		age: Int,
		idle: Int,
		blocked: Int,
		importFrom: [String],
		importRate: Int,
		jobsIn: Int,
		jobsOut: Int,
		pauseState: QueuePauseState
	) {
		self.name = name
		self.length = length
		self.age = age
		self.idle = idle
		self.blocked = blocked
		self.importFrom = importFrom
		self.importRate = importRate
		self.jobsIn = jobsIn
		self.jobsOut = jobsOut
		self.pauseState = pauseState
	}

	/// Creates a new `QueueInfo` from an array of `RedisData`.
	public init(redisData: [RedisData]) {
		self.name = redisData[1].string!
		self.length = redisData[3].int!
		self.age = redisData[5].int!
		self.idle = redisData[7].int!
		self.blocked = redisData[9].int!
		self.importFrom = redisData[11].array!.map { $0.string! }
		self.importRate = redisData[13].int!
		self.jobsIn = redisData[15].int!
		self.jobsOut = redisData[17].int!
		self.pauseState = QueuePauseState(rawValue: redisData[19].string!)!
	}
}
