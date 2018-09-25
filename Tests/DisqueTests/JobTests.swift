@testable import Disque
import XCTest

final class JobTests: XCTestCase {
	func testShowJob() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		// If job doesn't exist, show job should return nil.

		var jobInfo = try disque.show(
			jobID: "D-00000000-000000000000000000000000-0000",
			as: TestJob.self
		)
		.wait()

		XCTAssertNil(jobInfo)

		// If job does exist, show job should return the job info.

		let jobID = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		jobInfo = try disque.show(jobID: jobID, as: TestJob.self).wait()

		XCTAssertNotNil(jobInfo)
		XCTAssertEqual(jobInfo!.queue, "\(#function)")
		XCTAssertEqual(jobInfo!.state, .queued)
		XCTAssertEqual(
			jobInfo!.createdAt.timeIntervalSinceReferenceDate,
			Date().timeIntervalSinceReferenceDate,
			accuracy: 0.1
		)
		XCTAssertEqual(jobInfo!.timeToLive, 5)
		XCTAssertEqual(jobInfo!.delay, 0)
		XCTAssertEqual(jobInfo!.retryInterval, 300)
		XCTAssertEqual(Float(jobInfo!.nextRetryWithin), 300, accuracy: 1)
		XCTAssertEqual(jobInfo!.nacks, 0)
		XCTAssertEqual(jobInfo!.additionalDeliveries, 0)
		XCTAssertEqual(jobInfo!.nodesDelivered.count, 1)
		XCTAssertEqual(jobInfo!.nodesConfirmed.count, 0)
		XCTAssertEqual(jobInfo!.body, TestJob())
	}

	func testGetJob() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		// If there are no jobs in the queue, get jobs should return no jobs.

		var jobs = try disque.get(count: 1, from: ["\(#function)"], as: TestJob.self).wait()

		XCTAssertEqual(jobs.count, 0)

		// If there are jobs in the queue, get jobs should return the number of jobs specified.

		let jobID1 = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		let jobID2 = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		jobs = try disque.get(count: 1, from: ["\(#function)"], as: TestJob.self).wait()

		XCTAssertEqual(jobs.count, 1)
		XCTAssertEqual(jobs[0].queue, "\(#function)")
		XCTAssertEqual(jobs[0].nacks, 0)
		XCTAssertEqual(jobs[0].additionalDeliveries, 0)
		XCTAssertEqual(jobs[0].body, TestJob())

		_ = try disque.enqueue(jobIDs: [jobID1, jobID2]).wait()
		jobs = try disque.get(count: 2, from: ["\(#function)"], as: TestJob.self).wait()

		XCTAssertEqual(jobs.count, 2)
	}

	func testAddJob() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		let jobID = try disque.add(
			job: TestJob(),
			to: "\(#function)",
			delay: 1,
			retryAfter: 5,
			deleteAfter: 5
		)
		.wait()
		let job = try disque.show(jobID: jobID, as: TestJob.self).wait()

		XCTAssertNotNil(job)
		XCTAssertEqual(job!.queue, "\(#function)")
		XCTAssertEqual(job!.state, .active)
		XCTAssertEqual(
			job!.createdAt.timeIntervalSinceReferenceDate,
			Date().timeIntervalSinceReferenceDate,
			accuracy: 0.1
		)
		XCTAssertEqual(job!.timeToLive, 5)
		XCTAssertEqual(job!.delay, 1)
		XCTAssertEqual(job!.retryInterval, 5)
		XCTAssertEqual(Float(job!.nextRetryWithin), 0, accuracy: 1)
		XCTAssertEqual(job!.nacks, 0)
		XCTAssertEqual(job!.additionalDeliveries, 0)
		XCTAssertEqual(job!.nodesDelivered.count, 1)
		XCTAssertEqual(job!.nodesConfirmed.count, 0)
		XCTAssertEqual(job!.body, TestJob())
	}

	func testAddJobErrors() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		// If unable to encode the job, should throw an error.

		XCTAssertThrowsError(
			try disque.add(job: "String", to: "\(#function)").wait()
		) { error in
			XCTAssertEqual(error as? DisqueError, .unableToEncode)
		}

		_ = try disque.pause(queue: "\(#function)", state: .all).wait()

		// If the queue is paused, should throw an error.

		XCTAssertThrowsError(
			try disque.add(
				job: TestJob(),
				to: "\(#function)"
			)
			.wait()
		) { error in
			XCTAssertEqual(error as? DisqueError, .queuePaused)
		}

		_ = try disque.pause(queue: "\(#function)", state: .none).wait()

		// If the delay time is greater than the retry time, should throw an error.

		XCTAssertThrowsError(
			try disque.add(
				job: TestJob(),
				to: "\(#function)",
				delay: 2,
				deleteAfter: 1
			)
			.wait()
		) { error in
			XCTAssertEqual(error as? DisqueError, .delayGreaterThanTTL)
		}
	}

	func testWorkingJob() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		let jobID = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		let postponedFor = try disque.working(jobID: jobID).wait()

		XCTAssertEqual(postponedFor, 300)
	}

	func testWorkingJobErrors() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		// If the server does not have the job, should throw an error.

		XCTAssertThrowsError(
			try disque.working(jobID: "D-00000000-000000000000000000000000-0000").wait()
		) { error in
			XCTAssertEqual(error as? DisqueError, .unknownJob)
		}

		// If half of the job's life has been elapsed, should throw an error.

		let jobID = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 2).wait()

		sleep(1)

		XCTAssertThrowsError(
			try disque.working(jobID: jobID).wait()
		) { error in
			XCTAssertEqual(error as? DisqueError, .tooLateToPostpone)
		}
	}

	func testAckJob() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		// If job doesn't exist, ack job should return 0.

		var ackCount = try disque.ack(jobIDs: ["D-00000000-000000000000000000000000-0000"]).wait()

		XCTAssertEqual(ackCount, 0)

		// If the job does exist, ack job should return the number of jobs specified.

		var jobID1 = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		ackCount = try disque.ack(jobIDs: [jobID1]).wait()

		XCTAssertEqual(ackCount, 1)

		jobID1 = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		let jobID2 = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		ackCount = try disque.ack(jobIDs: [jobID1, jobID2]).wait()

		XCTAssertEqual(ackCount, 2)
	}

	func testFastAckJob() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		// If job doesn't exist, fastack job should return 0.

		var ackCount = try disque.ack(
			jobIDs: ["D-00000000-000000000000000000000000-0000"],
			requireReplication: false
		)
		.wait()

		XCTAssertEqual(ackCount, 0)

		// If the job does exist, fastack job should return the number of jobs specified.

		var jobID1 = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		ackCount = try disque.ack(jobIDs: [jobID1], requireReplication: false).wait()

		XCTAssertEqual(ackCount, 1)

		jobID1 = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		let jobID2 = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		ackCount = try disque.ack(jobIDs: [jobID1, jobID2], requireReplication: false).wait()

		XCTAssertEqual(ackCount, 2)
	}

	func testNackJob() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		// If job doesn't exist, nack job should return 0.

		var nackCount = try disque.nack(jobIDs: ["D-00000000-000000000000000000000000-0000"]).wait()

		XCTAssertEqual(nackCount, 0)

		// If the job does exist, nack job should return the number of jobs specified.

		let jobID1 = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		_ = try disque.get(count: 1, from: ["\(#function)"], as: TestJob.self).wait()
		nackCount = try disque.nack(jobIDs: [jobID1]).wait()

		XCTAssertEqual(nackCount, 1)

		var job = try disque.show(jobID: jobID1, as: TestJob.self).wait()

		XCTAssertNotNil(job)
		XCTAssertEqual(job!.nacks, 1)

		let jobID2 = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		_ = try disque.get(count: 2, from: ["\(#function)"], as: TestJob.self).wait()
		nackCount = try disque.nack(jobIDs: [jobID1, jobID2]).wait()

		XCTAssertEqual(nackCount, 2)

		job = try disque.show(jobID: jobID1, as: TestJob.self).wait()

		XCTAssertNotNil(job)
		XCTAssertEqual(job!.nacks, 2)
	}

	func testEnqueueJob() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		// If job doesn't exist, enqueue job should return 0.

		var enqueueCount = try disque.enqueue(jobIDs: ["D-00000000-000000000000000000000000-0000"]).wait()

		XCTAssertEqual(enqueueCount, 0)

		// If the job does exist, enqueue job should return the number of jobs specified.

		let jobID1 = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		_ = try disque.get(count: 1, from: ["\(#function)"], as: TestJob.self).wait()
		enqueueCount = try disque.enqueue(jobIDs: [jobID1]).wait()

		XCTAssertEqual(enqueueCount, 1)

		var job = try disque.show(jobID: jobID1, as: TestJob.self).wait()

		XCTAssertNotNil(job)
		XCTAssertEqual(job!.additionalDeliveries, 1)

		let jobID2 = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		_ = try disque.get(count: 2, from: ["\(#function)"], as: TestJob.self).wait()
		enqueueCount = try disque.enqueue(jobIDs: [jobID1, jobID2]).wait()

		XCTAssertEqual(enqueueCount, 2)

		job = try disque.show(jobID: jobID1, as: TestJob.self).wait()

		XCTAssertNotNil(job)
		XCTAssertEqual(job!.additionalDeliveries, 2)
	}

	func testDequeueJob() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		// If job doesn't exist, dequeue job should return 0.

		var dequeueCount = try disque.dequeue(jobIDs: ["D-00000000-000000000000000000000000-0000"]).wait()

		XCTAssertEqual(dequeueCount, 0)

		// If the job does exist, dequeue job should return the number of jobs specified.

		let jobID = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		dequeueCount = try disque.dequeue(jobIDs: [jobID]).wait()

		XCTAssertEqual(dequeueCount, 1)

		let job = try disque.show(jobID: jobID, as: TestJob.self).wait()

		XCTAssertNotNil(job)
		XCTAssertEqual(job!.state, .active)
	}

	func testDeleteJob() throws {
		let disque = try DisqueClient.makeTest()

		defer { disque.close() }

		// If job doesn't exist, delete job should return 0.

		var deleteCount = try disque.delete(jobIDs: ["D-00000000-000000000000000000000000-0000"]).wait()

		XCTAssertEqual(deleteCount, 0)

		// If the job does exist, delete job should return the number of jobs specified.

		let jobID = try disque.add(job: TestJob(), to: "\(#function)", deleteAfter: 5).wait()
		deleteCount = try disque.delete(jobIDs: [jobID]).wait()

		XCTAssertEqual(deleteCount, 1)

		let job = try disque.show(jobID: jobID, as: TestJob.self).wait()

		XCTAssertNil(job)
	}
}
