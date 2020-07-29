import ./concepts

type
  StringSocket* = ref object of RootObj
    discard

proc newStringSocket*(): StringSocket =
  new(result)

proc onOpen*(s: StringSocket): Future[void] =
  ## Returns a future that completes when this socket is
  ## ready for use.

proc hasOpened*(s: StringSocket): bool =
  discard

proc close*(s: StringSocket): Future[void] =
  discard

proc startedClosing*(s: StringSocket): bool =
  discard

proc isClosed*(s: StringSocket): bool =
  discard

proc onClose*(s: StringSocket): Future[void] =
  discard

proc send*(s: StringSocket, data: string): Future[void] =
  discard

proc recv*(s: StringSocket, count: int): Future[string] =
  discard

proc attachTo*(s: StringSocket, socket: SocketLike) =
  discard

assert StringSocket is Connectable
assert StringSocket is StreamTransport

