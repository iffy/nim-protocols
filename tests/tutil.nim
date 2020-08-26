import unittest

import protocols
import protocols/util

suite "MemorySocket":
  test "concepts":
    var sock = newMemorySocket()
    assertConcept(ISocket, sock)

  test "works":
    var sock = newMemorySocket()
    check sock.isClosed() == false

    checkpoint "send 2 pieces of data"
    let s1 = sock.send("da")
    let s2 = sock.send("ta")
    check s1.finished
    check s2.finished
    assert sock.sendCalls.len == 2
    check sock.sendCalls[0] == "da"
    check sock.sendCalls[1] == "ta"
    check sock.sent == "data"

    checkpoint "clearSent"
    sock.clearSent()
    check sock.sendCalls.len == 0
    check sock.sent == ""

    checkpoint "recv before put"
    let p = sock.recv(5)
    sock.put("app")
    check p.finished() == false

    sock.put("le")
    check p.finished() == true
    check p.read() == "apple"

    checkpoint "put before recv"
    sock.put("hello")
    check sock.pending == "hello"
    
    let p2 = sock.recv(2)
    check p2.finished() == true
    check p2.read() == "he"
    check sock.pending == "llo"

    let p3 = sock.recv(3)
    check p3.finished() == true
    check p3.read() == "llo"
    check sock.pending == ""

    checkpoint "close"
    sock.close()
    check sock.isClosed() == true
  
  test "closeRemote before done putting":
    var sock = newMemorySocket()
    let p = sock.recv(5)
    sock.put("app")
    sock.closeRemote()
    check sock.isClosed() == false
    check p.finished() == true
    check p.read() == "app"

    let p2 = sock.recv(10)
    check p2.finished == true
    check p2.read() == ""

  test "send/recv on closed":
    # this mimics what real AsyncSockets do when 
    # you attempt to send/recv after close()
    var sock = newMemorySocket()
    sock.close()
    let s = sock.send("somedata")
    check s.failed
    let r = sock.recv(12)
    check r.failed
    expect ValueError:
      sock.close()
  
  test "connect two test sockets together":
    var client = newMemorySocket()
    var server = newMemorySocket()
    connect(client, server)

    check client.isClosed() == false
    check server.isClosed() == false

    let p_server = server.recv(5)
    asyncCheck client.send("hello")
    asyncCheck server.send("hi")
    let p_client = client.recv(2)

    assert p_server.finished == true
    check p_server.read() == "hello"
    assert p_client.finished == true
    check p_client.read() == "hi"

    server.close()

    check server.isClosed() == true
    check client.isClosed() == false # this is how real sockets behave

    checkpoint "=== sending more data"
    let send_p = client.send("more data")
    check send_p.finished
    check not send_p.failed

    checkpoint "=== receiving more data"
    let readeof = client.recv(20)
    assert readeof.finished
    check readeof.read() == ""
    check client.isClosed() == false


suite "MemoryStream":
  test "concepts":
    var s = newMemoryStream()
    assertConcept(StreamProvider, s)

  test "basic":
    var s = newMemoryStream()
    check s.conn.isClosed == false
    check s.conn.hasOpened == true
    check s.sent == ""
    check s.sendCalls.len == 0

    let s1 = s.send("foo")
    let s2 = s.send("bar")
    check s1.finished
    check s2.finished
    check s.sent == "foobar"
    check s.sendCalls == @["foo", "bar"]

    s.clearSent()
    check s.sent == ""
    check s.sendCalls.len == 0

    let r1 = s.read(5)
    check not r1.finished
    
    s.put("he")
    check not r1.finished

    s.put("llo")
    check r1.finished
    check r1.read() == "hello"

  test "close before done putting":
    var stream = newMemoryStream()
    let p = stream.read(5)
    stream.put("app")
    stream.conn.close()
    check p.finished() == true
    check p.read() == "app"

    let p2 = stream.read(10)
    check p2.failed == true

  test "send/read on closed":
    var stream = newMemoryStream()
    stream.conn.close()
    let s = stream.send("somedata")
    check s.failed
    let r = stream.read(12)
    check r.failed
