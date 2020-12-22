import unittest

import protocols
import protocols/base
import protocols/memory

proc `====`(message:string) {.inline.} =
  checkpoint "==== " & message

suite "StreamSocket":
  test "concepts":
    var ss = newStreamSocket[AsyncSocket]()
    assertConcept(StreamProvider, ss)
    assertConcept(SocketConsumer, ss)
  
  test "lifecycle":
    ==== "init"
    var ss = newStreamSocket[MemorySocket]()
    check ss.conn.hasOpened == false
    check ss.conn.isClosed == false
    let openp = ss.conn.onOpen()
    let onclosep = ss.conn.onClose()
    check openp.finished == false
    check onclosep.finished == false

    ==== "attach"
    var sock = newMemorySocket()
    ss.attachTo(sock)
    check ss.conn.hasOpened
    check openp.finished

    ==== "send"
    let sendp = ss.send("somedata")
    check sendp.finished
    check sock.sent == "somedata"

    ==== "read"
    let readp = ss.read(5)
    check readp.finished == false
    sock.put("apples")
    check readp.finished
    check readp.read() == "apple"
    check sock.pending == "s"

    ==== "close"
    ss.conn.close()
    check ss.conn.isClosed
    check onclosep.finished
  
  test "detect close on eof":
    var sock = newMemorySocket()
    var ss = newStreamSocket[MemorySocket]()
    ss.attachTo(sock)
    let closep = ss.conn.onClose()
    check closep.finished == false

    sock.closeRemote()
    check closep.finished == false
    check ss.conn.isClosed == false

    let readp = ss.read(5)
    check readp.finished
    check readp.read() == ""
    check closep.finished
    check ss.conn.isClosed
  
  test "send/read after close":
    var sock = newMemorySocket()
    var ss = newStreamSocket[MemorySocket]()
    ss.attachTo(sock)
    ss.conn.close()

    check ss.send("something").failed
    check ss.read(5).failed

suite "Connection":

  test "basic":
    var conn = newConnection()
    assertConcept(IConnection, conn)
    check conn.onOpen.finished == false
    check conn.hasOpened == false
    check conn.isClosed == false
    check conn.onClose.finished == false

    conn.open()
    check conn.onOpen.finished
    check conn.hasOpened

    conn.close()
    check conn.isClosed
    check conn.onClose.finished
  
  test "onClose isClosed in callback":
    proc stuff() =
      var conn = newConnection()
      conn.open()

      conn.onClose.addCallback proc() {.gcsafe.} =
        assert conn.isClosed() == true
      conn.close()
      check conn.isClosed() == true
    stuff()

  test "attachTo":
    var parent = newConnection()
    var child = newConnection()
    child.follow(parent)
    check not child.hasOpened
    check not parent.hasOpened
    check not child.isClosed
    check not parent.isClosed
  
  test "child opens when parent opens":
    var parent = newConnection()
    var child = newConnection()
    child.follow(parent)

    parent.open()
    check child.hasOpened
    check parent.hasOpened
  
  test "child closes when parent closes":
    var parent = newConnection()
    var child = newConnection()
    child.follow(parent)

    parent.open()
    parent.close()
    check child.isClosed
    check parent.isClosed
  
  test "parent closes when child closes":
    var parent = newConnection()
    var child = newConnection()
    child.follow(parent)

    parent.open()
    child.close()
    check child.isClosed
    check parent.isClosed
  
  test "child ignores parent open":
    var parent = newConnection()
    var child = newConnection()
    child.follow(parent, followOpen = false)

    parent.open()
    check parent.hasOpened
    check not child.hasOpened
  
  test "child ignores parent close":
    var parent = newConnection()
    var child = newConnection()
    child.follow(parent, followClose = false)

    parent.open()
    parent.close()
    check parent.isClosed
    check not child.isClosed

  test "attaching to already-open parent":
    var parent = newConnection()
    var child = newConnection()
    parent.open()
    child.follow(parent)
    check child.hasOpened

  test "attaching to already-open parent when not following":
    var parent = newConnection()
    var child = newConnection()
    parent.open()
    child.follow(parent, followOpen = false)
    check not child.hasOpened
