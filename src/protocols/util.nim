{.experimental: "codeReordering".}

import ./concepts
import strutils
import deques
import options

type
  RecvRequest* = tuple
    fut: Future[string]
    size: int

  ## A TestSocket can be used in place of a real AsyncSocket
  ## in tests.
  ## 
  ## Simulate being the remote side with `put()` and `sent`/`sendCalls`
  ## 
  ## Or connect two together with `connect()`
  TestSocket* = ref object
    sendCalls*: seq[string]
    pending*: string
    pending_recvs: Deque[RecvRequest]
    closed: bool
    remote: Option[TestSocket]
    remote_closed: bool

proc newTestSocket*():TestSocket =
  new(result)
  result.pending_recvs = initDeque[RecvRequest]()
  result.remote = none[TestSocket]()

proc pump(s: var TestSocket) =
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

proc send*(s: var TestSocket, data: string): Future[void] =
  ## Send data through the socket.
  result = newFuture[void]("TestSocket.send " & data)
  if s.closed:
    result.fail(newException(ValueError, "Cannot `send` on a closed Socket"))
    return
  if s.remote.isSome():
    s.remote.get().put(data)
  else:
    s.sendCalls.add(data)
    s.pump()
  result.complete()

proc recv*(s: var TestSocket, size: int): Future[string] =
  ## Fetch up to size bytes. If the remote side is closed
  ## this will return ""
  var req:RecvRequest = (
    fut: newFuture[string]("TestSocket.recv " & $size),
    size: size,
  )
  result = req.fut
  if s.closed:
    result.fail(newException(AssertionError, "Cannot `recv` on a closed socket"))
  else:
    s.pending_recvs.addLast(req)
    s.pump()

proc close*(s: var TestSocket) =
  ## Close this socket
  if s.closed:
    raise newException(ValueError, "Cannot `close` a socket more than once")
  s.closed = true
  if s.remote.isSome():
    s.remote.get().closeRemote()
  else:
    s.pump()

proc isClosed*(s: TestSocket): bool {.inline.} =
  s.closed

proc closeRemote*(s: var TestSocket) =
  ## Simulate the other side being closed
  s.remote_closed = true
  s.pump()

proc sent*(s: TestSocket): string {.inline.} =
  ## See what has been sent on this socket
  s.sendCalls.join("")

proc clearSent*(s: var TestSocket) {.inline.} =
  ## Clear what has been sent on this socket
  s.sendCalls.setLen(0)

proc put*(s: var TestSocket, data: string) =
  ## Put data into this socket for recv calls to receive
  s.pending.add(data)
  s.pump()

proc connect*(a: TestSocket, b: TestSocket) =
  ## Connect two sockets together
  a.remote = some(b)
  b.remote = some(a)
