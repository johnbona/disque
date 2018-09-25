import XCTest

extension JobTests {
    static let __allTests = [
        ("testAckJob", testAckJob),
        ("testAddJob", testAddJob),
        ("testAddJobErrors", testAddJobErrors),
        ("testDeleteJob", testDeleteJob),
        ("testDequeueJob", testDequeueJob),
        ("testEnqueueJob", testEnqueueJob),
        ("testFastAckJob", testFastAckJob),
        ("testGetJob", testGetJob),
        ("testNackJob", testNackJob),
        ("testShowJob", testShowJob),
        ("testWorkingJob", testWorkingJob),
        ("testWorkingJobErrors", testWorkingJobErrors),
    ]
}

extension QueueTests {
    static let __allTests = [
        ("testPauseQueue", testPauseQueue),
        ("testQueueLength", testQueueLength),
        ("testQueueMetrics", testQueueMetrics),
    ]
}

extension ServerTests {
    static let __allTests = [
        ("testServerInfo", testServerInfo),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(JobTests.__allTests),
        testCase(QueueTests.__allTests),
        testCase(ServerTests.__allTests),
    ]
}
#endif
