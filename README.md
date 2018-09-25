# Disque

[![CircleCI](https://circleci.com/gh/johnbona/disque.svg?style=shield)](https://circleci.com/gh/johnbona/disque)
![Swift](http://img.shields.io/badge/swift-4.1-brightgreen.svg)
![Vapor](http://img.shields.io/badge/vapor-3.0-brightgreen.svg)

A non-blocking, event-driven Swift client for Disque, ~~shamelessly copied~~ built on Vapor's [Redis](https://github.com/vapor/redis) client. [Disque](https://github.com/antirez/disque) is a distributed job queue created by Salvatore Sanfilippo ([@antirez](https://twitter.com/antirez)) "forked" off of Redis.

#### Disque Features
- **Distributed** - Disque clusters are multi-master with each node having the same role so producers and consumers can attach to any node. There is no requirement for producers and consumers of the same queue to be connected to the same node.
- **Fault Tolerant** - Jobs are synchronously replicated to multiple nodes such that when a job is added to a queue, the job is replicated to N nodes before the node returns the job ID to the client. N-1 nodes can fail and the job will still be delivered.
- **Tunable Persistence** - By default, Disque stores jobs in-memory, however, Disque can be configured to persist jobs on disk by [turning on AOF](https://github.com/antirez/disque#disque-and-disk-persistence) (similar to Redis).
- **Customizable Delivery Semantics**: By default, jobs have at-least-once delivery semantics but if the retry time is set to 0, jobs will have at-most-once delivery semantics. For at-least-once delivery, jobs are automatically re-queued until the job is acknowledged by a consumer or until the job expires.
- **Job Priority** - Consumers can acquire jobs from multiple queues from one `GETJOB` command. Disque will search for jobs from the defined queues starting first with the left-most queue simulating job priority.
- **Scheduled/Delayed Jobs** - Jobs can be scheduled/delayed for a set period of time. Delayed jobs are not delivered to consumers until the delay has expired.

## Installation and Setup

**1.** Start a Disque container using Docker or follow Disque's [installation instructions](https://github.com/antirez/disque#setup).

```bash
docker run -d --rm -p 7711:7711 --name disque efrecon/disque:1.0-rc1
```

**2** Add the dependency to Package.swift.

```swift
.package(url: "https://github.com/johnbona/disque", from: "0.1.0")
```

**3.** Register the provider and config in `configure.swift`.

```swift
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services ) throws {
	// ...

	try services.register(DisqueProvider())

	var databases = DatabasesConfig()
	let disqueConfig = DisqueDatabase(config: DisqueClientConfig())

	databases.add(database: disqueConfig, as: .disque)
	services.register(databases)
}
```

**4.** Fetch a connection from the connection pool and use the Disque client.

```swift
return req.withPooledConnection(to: .disque) { disque -> Future<[Job<TestJob>]> in
	return disque.get(count: 1, from: ["test-queue"], as: TestJob.self)
}
```

## Usage

All of Disque's [commands](https://github.com/antirez/disque#main-api) (except for `HELLO`, `QPEEK`, `QSCAN`, `JSCAN`) are implemented in Swift with job bodies conforming to `Codable`.

#### Get a job from the queue

```swift
return req.withPooledConnection(to: .disque) { disque -> Future<[Job<TestJob>]> in
	return disque.get(count: 1, from: ["test-queue"], as: TestJob.self)
}
```

#### Get a job from multiple queues (job priority)

```swift
return req.withPooledConnection(to: .disque) { disque -> Future<[Job<TestJob>]> in
	return disque.get(count: 1, from: ["high-priority", "low-priority"], as: TestJob.self)
}
```

#### Add a job to a queue

```swift
req.withPooledConnection(to: .disque) { disque -> Future<String> in
	return try disque.add(job: TestJob(), to: "test-queue")
}
```

#### Completing (acking) a job

```swift
req.withPooledConnection(to: .disque) { disque -> Future<Int> in
	return try disque.ack(jobIDs: ["D-00000000-000000000000000000000000-0000"])
}
```

## Resources
- [Disque repository and documentation](https://github.com/antirez/disque)
- Original Disque announcement from [@antirez](https://twitter.com/antirez) with architecture details: [Adventures in Message Queues](http://antirez.com/news/88)
- [Join Vapor's Discord channel](https://discord.gg/vapor) for support
- Feel free to reach out on Twitter ([@johnbona](https://twitter.com/johnbona)) with any comments or questions

## License
Disque is released under the MIT License.
