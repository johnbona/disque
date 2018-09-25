public enum DisqueError: Error {

	/// Thrown if the response from the server is not the correct type.
	case invalidResponse

	/// Thrown if unable to encode the job.
	case unableToEncode

	/// Thrown if the server does not have the job.
	case unknownJob

	/// Thrown if the queue is paused.
	case queuePaused

	/// Thrown if the delay time is greater than the retry after time.
	case delayGreaterThanTTL

	/// Thrown if half of the job's life has already elapsed.
	case tooLateToPostpone
}
