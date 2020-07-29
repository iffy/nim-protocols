import ./concepts
import options

type
  ## A StringSocket converts an AsyncSocket (or TestSocket)
  ## into a composeable Transport.
  StringSocket*[T] = ref object of RootObj
    open_fut: Future[void]
    closed_fut: Future[void]
    socket: Option[T]

proc newStringSocket*[T](): StringSocket[T] =
  new(result)
  result.open_fut = newFuture[void]("StringSocket.open_fut")
  result.closed_fut = newFuture[void]("StringSocket.closed_fut")
  result.socket = none[T]()

proc onOpen*(s: StringSocket): Future[void] {.inline.} =
  ## Returns a future that completes when this socket is
  ## ready for use.
  s.open_fut

proc hasOpened*(s: StringSocket): bool {.inline.} =
  s.open_fut.finished

proc isClosed*(s: StringSocket): bool {.inline.} =
  s.closed_fut.finished

proc close*(s: StringSocket): Future[void] =
  if s.socket.isSome:
    var socket = s.socket.get()
    if not socket.isClosed():
      socket.close()
  s.closed_fut.complete()
  s.closed_fut



proc onClose*(s: StringSocket): Future[void] {.inline.} =
  s.closed_fut

proc send*(s: StringSocket, data: string): Future[void] =
  if s.socket.isSome:
    result = s.socket.get().send(data)
  

proc recv*(s: StringSocket, size: int): Future[string] {.async.} =
  if s.socket.isSome:
    result = await s.socket.get().recv(size)
    if result == "":
      await s.close()

proc attachTo*[T](s: StringSocket, socket: T) =
  s.socket = some(socket)
  s.open_fut.complete()

assert StringSocket[AsyncSocket] is Connectable
assert StringSocket[AsyncSocket] is StreamTransport
assert StringSocket[AsyncSocket] is SocketUser
