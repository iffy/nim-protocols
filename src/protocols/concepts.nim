import asyncdispatch
import asyncnet

type
  Connectable* = concept x
    ## A Connectable lets you follow along as it
    ## becomes open (ready) and later closes.
    x.onOpen() is Future[void]
    x.hasOpened() is bool
    x.close()
    x.isClosed() is bool
    x.onClose() is Future[void]
  
  #------------------------------------------------
  # Readables and Writables
  #------------------------------------------------

  StreamReadable* = concept x
    x.read(int) is Future[string]
  StreamWriteable* = concept x
    x.send(string) is Future[void]
  
  MessageReadable* = concept x
    x.readMessage() is Future[string]
  MessageWriteable* = concept x
    x.sendMessage(string) is Future[void]
  
  GenericReadable*[T] = concept x
    x.read() is Future[T]
  GenericWriteable*[T] = concept x
    x.send(T) is Future[void]

  #------------------------------------------------
  # Sockets
  #------------------------------------------------
  SocketProvider* = concept x
    ## Something resembling an AsyncSocket enough
    ## to be used in a StringSocket
    x.send(string) is Future[void]
    x.recv(int) is Future[string]
    x.close()
    x.isClosed() is bool

  SocketConsumer* = concept var x
    x.attachTo(SocketProvider)

  #------------------------------------------------
  # Bidirectional providers and consumers
  #------------------------------------------------
  StreamProvider* = concept x
    ## A StreamProvider sends/receives unframed bytes
    x.conn is Connectable
    x is StreamReadable
    x is StreamWriteable
  
  StreamConsumer* = concept x
    x.attachTo(StreamProvider)
  
  #------------------------------------------------
  
  MessageProvider* = concept x
    x.conn is Connectable
    x is MessageReadable
    x is MessageWriteable
  
  MessageConsumer* = concept x
    x.attachTo(MessageProvider)

  #------------------------------------------------

  GenericProvider*[T] = concept x
    x.conn is Connectable
    x is GenericReadable[T]
    x is GenericWriteable[T]
  
  GenericConsumer*[T] = concept x
    x.attachTo(GenericProvider[T])


template assertConcept*(con: untyped, instance: untyped): untyped =
  ## Check if the given concept is fulfilled by the instance.
  block:
    proc checkConcept(ign: con) = discard
    checkConcept(instance) {.explain.}
