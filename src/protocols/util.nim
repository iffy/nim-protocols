{.experimental: "codeReordering".}

import ./base
import strutils
import deques
import options

type
  RecvRequest* = tuple
    fut: Future[string]
    size: int

  MemorySocket* = ref object
    ## A MemorySocket can be used in place of a real AsyncSocket in tests.
    ## 
    ## Simulate being the remote side with `put()` and `sent`/`sendCalls`
    ## 
    ## Or connect two together with `connect()`
    sendCalls*: seq[string]
    pending*: string
    pending_recvs: Deque[RecvRequest]
    closed: bool
    remote: Option[MemorySocket]
    remote_closed: bool
  
  MemoryStream* = ref object
    ## A MemoryStream is useful for testing StreamConsumers
    ## 
    ## Simulate being the remote side with `put()` and `sent`/`sendCalls`
    conn*: Connection
    sendCalls*: seq[string]
    pending_data*: string
    pending_reads: Deque[RecvRequest]

proc newMemorySocket*():MemorySocket =
  new(result)
  result.pending_recvs = initDeque[RecvRequest]()
  result.remote = none[MemorySocket]()

proc pump(s: var MemorySocket) =
  ## Send and recv anything pending
  while s.pending_recvs.len > 0:
    var first = s.pending_recvs.peekFirst()
    if s.remote_closed or first.size <= s.pending.len:
      discard s.pending_recvs.popFirst()
      let ret = s.pending.substr(0, first.size-1)
      s.pending = s.pending.substr(first.size)
      first.fut.complete(ret)
    else:
      break

proc send*(s: var MemorySocket, data: string): Future[void] =
  ## Send data through the socket.
  result = newFuture[void]("MemorySocket.send " & data)
  if s.closed:
    result.fail(newException(ValueError, "Cannot `send` on a closed Socket"))
    return
  if s.remote.isSome():
    s.remote.get().put(data)
  else:
    s.sendCalls.add(data)
    s.pump()
  result.complete()

proc recv*(s: var MemorySocket, size: int): Future[string] =
  ## Fetch up to size bytes. If the remote side is closed
  ## this will return ""
  var req:RecvRequest = (
    fut: newFuture[string]("MemorySocket.recv " & $size),
    size: size,
  )
  result = req.fut
  if s.closed:
    result.fail(newException(AssertionError, "Cannot `recv` on a closed socket"))
  else:
    s.pending_recvs.addLast(req)
    s.pump()

proc close*(s: var MemorySocket) =
  ## Close this socket
  if s.closed:
    raise newException(ValueError, "Cannot `close` a socket more than once")
  s.closed = true
  if s.remote.isSome():
    s.remote.get().closeRemote()
  else:
    s.pump()

proc isClosed*(s: MemorySocket): bool {.inline.} =
  s.closed

proc closeRemote*(s: var MemorySocket) =
  ## Simulate the other side being closed
  s.remote_closed = true
  s.pump()

proc sent*(s: MemorySocket): string {.inline.} =
  ## See what has been sent on this socket
  s.sendCalls.join("")

proc clearSent*(s: var MemorySocket) {.inline.} =
  ## Clear what has been sent on this socket
  s.sendCalls.setLen(0)

proc put*(s: var MemorySocket, data: string) =
  ## Put data into this socket for recv calls to receive
  s.pending.add(data)
  s.pump()

proc connect*(a: MemorySocket, b: MemorySocket) =
  ## Connect two sockets together
  a.remote = some(b)
  b.remote = some(a)

proc pump(s: var MemoryStream)

proc newMemoryStream*(): MemoryStream =
  new(result)
  result.conn = newConnection()
  result.conn.open()
  result.pending_reads = initDeque[RecvRequest]()
  var stream = result
  result.conn.onClose().addCallback proc() =
    stream.pump()

proc pump(s: var MemoryStream) =
  ## Fulfil any pending reads that can be.
  while s.pending_reads.len > 0:
    var first = s.pending_reads.peekFirst()
    if s.conn.isClosed or first.size <= s.pending_data.len:
      discard s.pending_reads.popFirst()
      let ret = s.pending_data.substr(0, first.size-1)
      s.pending_data = s.pending_data.substr(first.size)
      first.fut.complete(ret)
    else:
      break

proc send*(s: var MemoryStream, data: string): Future[void] =
  ## Send data to the remote side
  result = newFuture[void]("MemoryStream.send")
  if s.conn.isClosed:
    result.fail(newException(ValueError, "Cannot `send` on a closed connection"))
    return
  s.sendCalls.add(data)
  result.complete()

proc read*(s: var MemoryStream, size: int): Future[string] =
  ## Read data from the remote side
  result = newFuture[string]("MemoryStream.read")
  var req:RecvRequest = (
    fut: newFuture[string]("MemoryStream.read " & $size),
    size: size,
  )
  result = req.fut
  if s.conn.isClosed:
    result.fail(newException(ValueError, "Cannot `read` on a closed connection"))
  else:
    s.pending_reads.addLast(req)
    s.pump()

proc sent*(s: MemoryStream): string {.inline.} =
  ## See what has been sent on this stream so far
  s.sendCalls.join("")

proc clearSent*(s: var MemoryStream) {.inline.} =
  ## Reset what has been sent to this stream so far
  s.sendCalls.setLen(0)

proc put*(s: var MemoryStream, data: string) =
  ## Simulate the remote side putting data into this stream
  s.pending_data.add(data)
  s.pump()
