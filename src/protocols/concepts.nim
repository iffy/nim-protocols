## This module defines concepts that let you build interchangeable,
## highly composable protocols.  For instance, you can build a
## message-oriented protocol for business logic, then connect that
## protocol over a TCP socket, or an HTTP client, or WebSockets,
## or a Unix domain socket.
## 
## Or you can chain together protocols to add encryption or
## flow control.
## 
## Protocols have 2 sides:
## 
## 1. The side you send to/receive from (called Transports below)
## 2. The side it sends to/receives from (called XUsers below)
## 
## Transports have a common lifecycle as defined by `Connectable`.
## In summary, the lifecycle is:
## 
## - Transport is created
## - Transport is open and ready to send/receive data
## - Transport is closing
## - Transport is closed
## 
import asyncdispatch
import asyncnet

export asyncdispatch
export asyncnet

type
  ## A Connectable lets you follow along as it
  ## becomes open (ready) and later closes.
  Connectable* = concept x
    x.onOpen() is Future[void]
    x.hasOpened() is bool
    x.close() is Future[void]
    x.isClosed() is bool
    x.onClose() is Future[void]
  
  SocketLike* = concept x
    x.send(string) is Future[void]
    x.recv(int) is Future[string]
    x.close()
    x.isClosed() is bool

  SocketUser* = concept x
    # TODO: Really, I'd like this to be
    #   x.attachTo(SocketLike)
    # but that doesn't seem to work
    x.attachTo(AsyncSocket)

  #------------------------------------------------

  ## A StreamTransport sends/receives unframed bytes
  StreamTransport* = concept x
    x is Connectable
    x.send(string) is Future[void]
    x.recv(int) is Future[string]
  
  StreamUser* = concept x
    x.attachTo(StreamTransport)
  
  #------------------------------------------------
  
  MessageTransport* = concept x
    x is Connectable
    x.sendMessage(string) is Future[void]
    x.recvMessage() is Future[string]
  
  MessageUser* = concept x
    x.attachTo(MessageTransport)

  #------------------------------------------------

  GenericTransport*[T] = concept x
    x is Connectable
    x.send(T) is Future[void]
    x.recv() is Future[T]
  
  GenericUser*[T] = concept x
    x.attachTo(T)

assert AsyncSocket is SocketLike
