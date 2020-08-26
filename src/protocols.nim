## This library provides concepts and implementations for 
## highly composeable network/data protocols.
## 
## For instance, using these concepts, you can build a protocol that 
## will work over any of these connections:
##
## * TCP socket
## * HTTP client (TODO)
## * Websockets (TODO)
## * a Unix domain socket (TODO)
## * process stdin/stdout
## 
## Protocols may be chained together as well (e.g. to add encryption).
## 
## See `protocols/concepts <./protocols/concepts.html>`_ for the various
## concepts.
##
## For instance, the included ``util/MemorySocket`` is a ``SocketProvider`` that acts like an ``AsnycSocket``, but reads/writes from memory rather than over the network.  Any ``SocketConsumer`` can use a ``SocketProvider``.
## 
## The ``netstring/NetstringTransport`` is both a ``StreamConsumer`` and a ``MessageProvider``. Attach it to any ``StreamProvider`` and attach any ``MessageConsumer`` to it.
## 
## Lifecycle
## ---------
## 
## Protocols have a common lifecycle as defined by 
## ``concept.Connectable``.  In summary, the lifecycle is:
##  
## 1. Created
## 2. Open and ready to send/receive data
## 3. Closed
##
## 
import ./protocols/concepts
export concepts
import ./protocols/base
export base
