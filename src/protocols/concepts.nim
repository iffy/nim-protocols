import asyncdispatch
import asyncnet

type
  IConnection* = concept x
    ## IConnection lets you follow along as it
    ## becomes open (ready) and later closes.
    x.onOpen() is Future[void]
    x.hasOpened() is bool
    x.close()
    x.isClosed() is bool
    x.onClose() is Future[void]
  
  Connectable* = concept x
    x.conn is IConnection
  
  #------------------------------------------------
  # Readables and Writables
  #------------------------------------------------
  ReadTransport* = concept x
    x.conn is IConnection
    x.read(int) is Future[string]
  WriteTransport* = concept x
    x.conn is IConnection
    x.send(string) is Future[void]
  
  ReadMessageTransport* = concept x
    x.conn is IConnection
    x.readMessage() is Future[string]
  WriteMessageTransport* = concept x
    x.conn is IConnection
    x.sendMessage(string) is Future[void]
  
  ReadGenericTransport*[T] = concept x
    x.conn is IConnection
    x.read() is Future[T]
  WriteGenericTransport*[T] = concept x
    x.conn is IConnection
    x.send(T) is Future[void]

  #------------------------------------------------
  # Bidirectional providers and consumers
  #------------------------------------------------
  StreamProvider* = concept x
    ## A StreamProvider sends/receives unframed bytes
    x is ReadTransport
    x is WriteTransport
  
  StreamConsumer* = concept x
    ## A StreamConsumer knows how to use a StreamProvider
    x.attachTo(StreamProvider)
  
  #------------------------------------------------
  
  MessageProvider* = concept x
    ## A MessageProvider sends/receives messages (delimited/framed/encoded in some way)
    x is ReadMessageTransport
    x is WriteMessageTransport
  
  MessageConsumer* = concept x
    ## A MessageConsumer knows how to use a MessageProvider
    x.attachTo(MessageProvider)

  #------------------------------------------------

  GenericProvider*[T] = concept x
    x is ReadGenericTransport[T]
    x is WriteGenericTransport[T]
  
  GenericConsumer*[T] = concept x
    x.attachTo(GenericProvider[T])


type
  ISocket* = concept x
    ## Something resembling an AsyncSocket
    x.send(string) is Future[void]
    x.recv(int) is Future[string]
    x.close()
    x.isClosed() is bool

  SocketConsumer* = concept var x
    ## Something that knows how to use an ISocket
    x.attachTo(ISocket)

template assertConcept*(con: untyped, instance: untyped): untyped =
  ## Check if the given concept is fulfilled by the instance.
  block:
    proc checkConcept(ign: con) = discard
    checkConcept(instance) {.explain.}
