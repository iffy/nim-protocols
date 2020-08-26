import options
import asyncdispatch
import asyncnet

export asyncdispatch
export asyncnet

import ./concepts

type
  ## A Connection doesn't handle data -- it just keeps
  ## track of a transports connectedness.
  Connection* = ref object of RootObj
    open_fut: Future[void]
    closed_fut: Future[void]
    parent: Option[Connection]

proc newConnection*(): Connection =
  new(result)
  result.open_fut = newFuture[void]("Connection.open_fut")
  result.closed_fut = newFuture[void]("Connection.closed_fut")
  result.parent = none[Connection]()

proc onOpen*(conn: Connection): Future[void] {.inline.} =
  ## Returns a future that completes when this Connection is
  ## ready for use.
  conn.open_fut

proc hasOpened*(conn: Connection): bool {.inline.} =
  ## True if this Connection has ever been open (so it
  ## remains true even after the Connection is closed)
  conn.open_fut.finished

proc open*(conn: Connection) =
  ## Indicate that this connection is open to send
  ## and receive data.
  conn.open_fut.complete()

proc isClosed*(conn: Connection): bool {.inline.} =
  conn.closed_fut.finished

proc close*(conn: Connection) =
  conn.closed_fut.complete()
  if conn.parent.isSome:
    var parent = conn.parent.get()
    if not parent.isClosed():
      parent.close()

proc onClose*(conn: Connection): Future[void] {.inline.} =
  conn.closed_fut

proc follow*(child: Connection, parent: var Connection, followOpen = true, followClose = true) =
  ## Make a child Connection follow a parent Connection
  ## 
  ## If `followOpen` is true (default), the child will open when the parent does
  ## otherwise, the child will not open when the parent does.
  ##
  ## If `followClose` is true (default), the child will close when the parent closes.
  ## otherwise, the child will not close automatically when the parent closes.
  child.parent = some(parent)
  if followOpen:
    parent.onOpen.addCallback proc() =
      child.open()
  if followClose:
    parent.onClose.addCallback proc() =
      if not child.isClosed:
        child.close()


type
  ## A StreamSocket converts a SocketProvider into a StreamProvider.
  StreamSocket*[T: SocketProvider] = ref object of RootObj
    conn*: Connection
    child: Option[T]

proc newStreamSocket*[T](): StreamSocket[T] =
  new(result)
  result.conn = newConnection()
  result.child = none[T]()

proc send*(s: StreamSocket, data: string): Future[void] =
  if s.child.isSome:
    result = s.child.get().send(data)

proc read*(s: StreamSocket, size: int): Future[string] {.async.} =
  if s.child.isSome:
    var child = s.child.get()
    result = await child.recv(size)
    if result == "":
      s.conn.close()

proc attachTo*[T](s: StreamSocket[T], child: T) =
  s.child = some(child)
  s.conn.onClose.addCallback proc() =
    if s.child.isSome:
      var child = s.child.get()
      if not child.isClosed():
        child.close()
  s.conn.open()


