import ./concepts
import options

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

proc close*(conn: Connection): Future[void] {.async.} =
  conn.closed_fut.complete()
  if conn.parent.isSome:
    var parent = conn.parent.get()
    if not parent.isClosed():
      await parent.close()

proc onClose*(conn: Connection): Future[void] {.inline.} =
  conn.closed_fut

proc attachTo*(child: Connection, parent: var Connection, followOpen = true, followClose = true) =
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
        asyncCheck child.close()


type
  ## A StringSocket converts an AsyncSocket (or TestSocket)
  ## into a composeable Transport.
  StringSocket*[T:SocketLike] = ref object of RootObj
    conn*: Connection
    child: Option[T]

proc newStringSocket*[T](): StringSocket[T] =
  new(result)
  result.conn = newConnection()
  result.child = none[T]()

# proc onOpen*(s: StringSocket): Future[void] {.inline.} =
#   ## Returns a future that completes when this socket is
#   ## ready for use.
#   s.open_fut

# proc hasOpened*(s: StringSocket): bool {.inline.} =
#   s.open_fut.finished

# proc isClosed*(s: StringSocket): bool {.inline.} =
#   s.closed_fut.finished

# proc close*(s: StringSocket): Future[void] =
#   if s.child.isSome:
#     var child = s.child.get()
#     if not child.isClosed():
#       child.close()
#   s.closed_fut.complete()
#   s.closed_fut

# proc onClose*(s: StringSocket): Future[void] {.inline.} =
#   s.closed_fut


proc send*(s: StringSocket, data: string): Future[void] =
  if s.child.isSome:
    result = s.child.get().send(data)

proc recv*(s: StringSocket, size: int): Future[string] {.async.} =
  if s.child.isSome:
    var child = s.child.get()
    result = await child.recv(size)
    if result == "":
      await s.conn.close()

proc attachTo*[T](s: StringSocket, child: var T) =
  s.child = some(child)
  s.conn.onClose.addCallback proc() =
    if s.child.isSome:
      var child = s.child.get()
      if not child.isClosed():
        child.close()
  s.conn.open()


