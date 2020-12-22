import options
import strutils

import ./base
import ./concepts

type
  DelimitedTransport*[T:StreamProvider] = ref object
    stream: Option[T]
    buffered: bool
    delimiter: string
    conn*: Connection
    buf: string
    pending: Option[Future[void]]

proc newDelimitedTransport*[T](delimiter = "\n", buffered = false): DelimitedTransport[T] =
  new(result)
  result.buffered = false
  result.conn = newConnection()
  result.delimiter = delimiter

proc sendMessage*(t: DelimitedTransport, msg: string): Future[void] =
  doAssert t.stream.isSome, "DelimitedTransport is not connected to any stream"
  t.stream.get().send(msg & t.delimiter)

proc readMessage*(t: DelimitedTransport): Future[string] {.async.} =
  doAssert t.stream.isSome, "DelimitedTransport is not connected to any stream"
  var stream = t.stream.get()
  var fut = newFuture[void]("DelimitedTransport.readMessage")
  if t.pending.isSome:
    # wait for the last getMessage call to finish
    var last = t.pending.get()
    t.pending = some(fut)
    yield last
  else:
    t.pending = some(fut)
  let sizetoread = if t.buffered: 1 else: 1024
  while t.delimiter notin t.buf:
    let datap = stream.read(sizetoread)
    yield datap
    if datap.failed:
      fut.complete()
      raise datap.readError()
    try:
      t.buf.add datap.read()
    except:
      t.conn.close()
      fut.complete()
      raise
  var parts = t.buf.split(t.delimiter, 1)
  result = parts[0]
  t.buf = parts[1]
  fut.complete()

proc attachTo*[T](t: DelimitedTransport[T], transport: T) =
  ## Set the transport this DelimitedTransport will write to and read from
  t.stream = some(transport)
  t.conn.follow(transport.conn)