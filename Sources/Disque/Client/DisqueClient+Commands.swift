import Redis

extension DisqueClient {

	// MARK: - Server Commands

	/// Provides info/stats of the connected server.
	///
	/// - Returns: A `Future` containing the server's info/stats.
	public func info() -> Future<String> {
		return redisClient.command("INFO")
			.map { $0.string ?? "" }
	}

	// MARK: - Queue Commands

	/// Returns the number of jobs in a queue. Equivalent to the Disque command `QLEN`.
	///
	/// - Parameter queue: Name of the queue.
	/// - Returns: A `Future` containing the number of jobs in the queue.
	/// - Note: Disque returns a queue length of "0" regardless of whether the queue exists.
	public func length(of queue: String) -> Future<Int> {
		return redisClient.command("QLEN", [RedisData(bulk: queue)])
			.map { $0.int ?? 0 }
	}

	/// Controls the pause state of a queue. Equivalent to the Disque command `PAUSE`.
	///
	/// - Parameters:
	///   - queue: Name of the queue.
	///   - state: Pause state to set the queue to.
	///   - willReplicate: Whether to broadcast the pause state to all nodes in the cluster.
	/// - Returns: A `Future` containing the `QueuePauseState`.
	@discardableResult
	public func pause(
		queue: String,
		state: QueuePauseState,
		willReplicate: Bool = true
	) -> Future<QueuePauseState> {
		var arguments = [RedisData(bulk: queue), RedisData(bulk: state.rawValue)]

		if willReplicate {
			arguments += [RedisData(bulk: "bcast")]
		}

		return redisClient.command("PAUSE", arguments)
			.map { QueuePauseState(rawValue: $0.string!)! }
	}

	/// Provides metrics about a queue. Equivalent to the Disque command `QSTAT`.
	///
	/// - Parameter queue: Name of the queue.
	/// - Returns: A `Future` containing an optional `QueueInfo`.
	/// - Note: Disque automatically evicts queues after some time if they are empty or there are no blocking clients waiting for jobs - even if there are active jobs in the queue. Queues are created again when needed to serve jobs. The non-existence of a queue does not necessarily mean there are no jobs in the queue.
	public func metrics(of queue: String) -> Future<QueueInfo?> {
		return redisClient.command("QSTAT", [RedisData(bulk: queue)])
			.map { data in
				guard let data = data.array else {
					return nil
				}

				return QueueInfo(redisData: data)
			}
	}

	// MARK: - Job Commands

	/// Retrieves a job and its metrics if the job exists and has not been deleted. Equivalent to the Disque command `SHOW`.
	///
	/// - Parameters:
	///   - jobID: Cluster-wide unique identifier of the job.
	///   - type: The type of the value to decode from the job's body.
	/// - Returns: A `Future` containing an optional `JobInfo`.
	public func show<C: Codable>(jobID: String, as type: C.Type) -> Future<JobInfo<C>?> {
		return redisClient.command("SHOW", [RedisData(bulk: jobID)])
			.map { try $0.array.map { try JobInfo(redisData: $0) } }
	}

	/// Obtains jobs from one or more queues (going from left to right if more than one queue is specified). Equivalent to the Disque command `GETJOB`.
	///
	/// - Parameters:
	///   - count: Number of jobs to obtain from the queue(s).
	///   - queues: Names of the queues.
	///   - type: The type of the value to decode from the job's body.
	///   - isBlocking: Whether to block the event loop and wait for a job if the queue is empty. Defaults to `false`.
	///   - timeout: Number of milliseconds to wait for a job before returning. Defaults to 0 milliseconds.
	/// - Returns: A `Future` containing an array of `Job`s.
	/// - Note: Blocking the event loop is generally inadvisable.
	public func get<C: Codable>(
		count: UInt32,
		from queues: [String],
		as type: C.Type,
		isBlocking: Bool = false,
		timeout: UInt32 = 0
	) -> Future<[Job<C>]> {
		var arguments: [RedisData] = []

		if !isBlocking {
			arguments += [RedisData(bulk: "NOHANG")]
		}

		arguments += [
			RedisData(bulk: "TIMEOUT"),
			RedisData(bulk: "\(timeout)"),
			RedisData(bulk: "COUNT"),
			RedisData(bulk: "\(count)"),
			RedisData(bulk: "WITHCOUNTERS"),
			RedisData(bulk: "FROM")
		]
		arguments += queues.map { RedisData(bulk: $0) }

		return redisClient.command("GETJOB", arguments)
			.map { $0.array ?? [] }
			.map { try $0.map { try Job(redisData: $0.array!) } }
	}

	/// Adds a job to a queue. Equivalent to the Disque command `ADDJOB`.
	///
	/// - Parameters:
	///   - job: The body of the job.
	///   - queue: Name of the queue.
	///   - delay: Number of seconds that should elapse before the job is available for processing. Defaults to 0 seconds.
	///   - retryAfter: Number of seconds after which, if no ACK is received, the job is placed back into the again for delivery. Cannot be greater than or equal to `deleteAfter`. If set to 0, the job will have at-most-once delivery semantics. Defaults to 300 seconds (5 minutes).
	///   - deleteAfter: Number of seconds after which the job is deleted even if it has not been successfully processed. If nil, the maximum possible job life will be calculated and used. Defaults to `nil`.
	///   - timeout: Number of milliseconds to wait before aborting. Defaults to 5000 milliseconds (5 seconds).
	///   - maxLength: Maximum number of jobs the queue may contain otherwise the job is refused. Defaults to `nil`.
	///   - willReplicateAsync: Whether the server will asynchronously replicate the job to other nodes in the cluster. Defaults to `false`.
	/// - Returns: A `Future` containing the ID of the queued job.
	/// - Throws: An error of type `DisqueError`.
	///   - `.unableToEncode`: Thrown if unable to encode the job.
	///   - `.queuePaused`: Thrown if the queue is paused.
	///   - `.delayGreaterThanTTL`: Thrown if the delay time is greater than the retry after time.
	///   - `.invalidResponse`: Thrown if the response from the server is other than type `String`.
	/// - Warning: Disque schedules the deletion of every job queued by summing the current Unix Epoch time (in seconds) and the `deleteAfter` parameter. If this value is above `UInt32.max`, Disque will erroneously schedule the job to be deleted immediately.
	/// - Note: Replicating jobs asynchronously provides better performance at the risk of losing all unreplicated jobs on a server. Use only if at-least-once delivery guarantees are not needed.
	public func add<C: Codable>(
		job: C,
		to queue: String,
		delay: UInt32 = 0,
		retryAfter: UInt32 = 300,
		deleteAfter: UInt32? = nil,
		timeout: UInt32 = 5000,
		maxLength: UInt32? = nil,
		willReplicateAsync: Bool = false
	) throws -> Future<String> {
		guard
			let jobData = try? JSONEncoder().encode(job),
			let jobString = String(data: jobData, encoding: .utf8)
		else {
			throw DisqueError.unableToEncode
		}

		let ttl: UInt32

		if let deleteAfter = deleteAfter {
			ttl = deleteAfter
		}
		else {
			// Longest TTL possible without causing UInt32 integer overflow.
			// Need to subtract command timeout otherwise retrying the ADDJOB command
			// with a TTL + current Unix Epoch time (in seconds) over `UInt32.max` will cause Disque
			// to erroneously set the TTL to 0.
			ttl = UInt32.max - UInt32(Date().timeIntervalSince1970) - timeout
		}

		var arguments: [RedisData] = [
			RedisData(bulk: queue),
			RedisData(bulk: jobString),
			RedisData(bulk: "\(timeout)"),
			RedisData(bulk: "DELAY"),
			RedisData(bulk: "\(delay)"),
			RedisData(bulk: "RETRY"),
			RedisData(bulk: "\(retryAfter)"),
			RedisData(bulk: "TTL"),
			RedisData(bulk: "\(ttl)")
		]

		if let maxLength = maxLength {
			arguments += [RedisData(bulk: "MAXLEN"), RedisData(bulk: "\(maxLength)")]
		}

		if willReplicateAsync {
			arguments += [RedisData(bulk: "ASYNC")]
		}

		return redisClient.command("ADDJOB", arguments)
			.catchMap { error in
				guard let redisError = error as? RedisError else {
					throw error
				}

				switch redisError.reason {
				case "PAUSED Queue paused in input, try later":
					throw DisqueError.queuePaused

				case "ERR The specified DELAY is greater than TTL. Job refused since would never be delivered":
					throw DisqueError.delayGreaterThanTTL

				default:
					throw redisError
				}
			}
			.map { data in
				guard let jobID = data.string else {
					throw DisqueError.invalidResponse
				}

				return jobID
			}
	}

	/// Attempts to postpone the redelivery of a job by indicating to the server the client is still processing the job. Equivalent to the Disque command `WORKING`.
	///
	/// - Parameter jobID: Cluster-wide unique identifier of the job.
	/// - Returns: A `Future` containing the number of seconds the job is likely postponed.
	/// - Throws: An error of type `DisqueError`.
	///   - `.unknownJob`: Thrown if the server does not have the job.
	///   - `.tooLateToPostpone`: Thrown if half of the job's life has already elapsed.
	///   - `.invalidResponse`: Thrown if the response from the server is other than type `Int`.
	/// - Note: This is a best-effort attempt to postpone redelivery of the job since there is no way to guarantee during failures that another node in a different network partition won't perform delivery of the job.
	@discardableResult
	public func working(jobID: String) -> Future<Int> {
		return redisClient.command("WORKING", [RedisData(bulk: jobID)])
			.catchMap { error in
				guard let redisError = error as? RedisError else {
					throw error
				}

				switch redisError.reason {
				case "NOJOB Job not known in the context of this node.":
					throw DisqueError.unknownJob

				case "TOOLATE Half of job TTL already elapsed, you are no longer allowed to postpone the next delivery.":
					throw DisqueError.tooLateToPostpone

				default:
					throw redisError
				}
			}
			.map { data in
				guard let retryInterval = data.int else {
					throw DisqueError.invalidResponse
				}

				return retryInterval
			}
	}

	/// Acknowledges the successful processing of one or more jobs. Equivalent to the Disque command `ACKJOB` when the `requireReplication` parameter is set to `true` or `FASTACK` when parameter `requireReplication` is set to `false`.
	///
	/// - Parameters:
	///   - jobIDs: Array of cluster-wide unique identifiers of each job.
	///   - requireReplication: Whether the server will replicate the ACK to multiple nodes in the cluster and delete the job once it is unlikely other nodes still have the job as active. Defaults to `true`.
	/// - Returns: A `Future` containing the number of jobs that were removed from the queue.
	/// - Note: Not requiring replication of the ACK is much faster while less reliable. Instead of replicating the ACK to multiple nodes in the cluster, the server will send a best-effort delete job command (`DELJOB`) to all nodes that may have a copy without requiring confirmation of receipt. This may result in the redelivery of completed jobs during failures.
	@discardableResult
	public func ack(jobIDs: [String], requireReplication: Bool = true) -> Future<Int> {
		return redisClient.command(
			requireReplication ? "ACKJOB" : "FASTACK",
			jobIDs.map { RedisData(bulk: $0) }
		)
		.map { $0.int ?? 0 }
	}

	/// Acknowledges the unsuccessful processing of one or more jobs and to place the job back into the queue ASAP. Increments the `nacks` counter instead of the `additionalDeliveries` counter. Equivalent to the Disque command `NACK`.
	///
	/// - Parameter jobIDs: Array of cluster-wide unique identifiers of each job.
	/// - Returns: A `Future` containing the number of jobs that were placed back into the queue.
	@discardableResult
	public func nack(jobIDs: [String]) -> Future<Int> {
		return redisClient.command("NACK", jobIDs.map { RedisData(bulk: $0) })
			.map { $0.int ?? 0 }
	}

	/// Places one or more jobs into the queue if not already queued. Increments the `additionalDeliveries` counter. Equivalent to the Disque command `ENQUEUE`.
	///
	/// - Parameter jobIDs: Array of cluster-wide unique identifiers of each job.
	/// - Returns: A `Future` containing the number of jobs that were placed into the queue.
	@discardableResult
	public func enqueue(jobIDs: [String]) -> Future<Int> {
		return redisClient.command("ENQUEUE", jobIDs.map { RedisData(bulk: $0) })
			.map { $0.int ?? 0 }
	}

	/// Removes one or more jobs from being available in the queue. Equivalent to the Disque command `DEQUEUE`.
	///
	/// - Parameter jobIDs: Array of cluster-wide unique identifiers of each job.
	/// - Returns: A `Future` containing the number of jobs that were removed from being available in the queue.
	/// - Note: Dequeuing a job does not delete it from the queue, only temporarily hides the job from clients until the retry time is elapsed.
	@discardableResult
	public func dequeue(jobIDs: [String]) -> Future<Int> {
		return redisClient.command("DEQUEUE", jobIDs.map { RedisData(bulk: $0) })
			.map { $0.int ?? 0 }
	}

	/// Deletes one or more jobs from a queue (limited to one node, not cluster-wide). Equivalent to the Disque command `DELJOB`.
	///
	/// - Parameter jobIDs: Array of cluster-wide unique identifiers of each job.
	/// - Returns: A `Future` containing the number of jobs that were deleted from the queue.
	/// - Warning: Deleting jobs is limited to a single node as delete job commands are not replicated throughout the cluster. Use `ack` instead for cluster-wide removal of jobs.
	@discardableResult
	public func delete(jobIDs: [String]) -> Future<Int> {
		return redisClient.command("DELJOB", jobIDs.map { RedisData(bulk: $0) })
			.map { $0.int ?? 0 }
	}
}
