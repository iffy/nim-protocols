import unittest

import protocols
import protocols/util

assert TestSocket is SocketLike

suite "TestSocket":
  test "concepts":
    var sock = newTestSocket()
    check sock is SocketLike

  test "works":
    var sock = newTestSocket()
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
    var sock = newTestSocket()
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
    var sock = newTestSocket()
    sock.close()
    let s = sock.send("somedata")
    check s.failed
    let r = sock.recv(12)
    check r.failed
    expect ValueError:
      sock.close()
  
  test "connect two test sockets together":
    var client = newTestSocket()
    var server = newTestSocket()
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



