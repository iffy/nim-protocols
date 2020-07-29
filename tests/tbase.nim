import unittest

import protocols
import protocols/base
import protocols/util

assert Connection is Connectable
assert StringSocket[AsyncSocket] is StreamTransport

proc `====`(message:string) {.inline.} =
  checkpoint "==== " & message

suite "StringSocket":
  test "concepts":
    var ss = newStringSocket[AsyncSocket]()
    check ss is StreamTransport
    # check ss is SocketUser
    check ss.conn is Connectable
  
  test "lifecycle":
    ==== "init"
    var ss = newStringSocket[TestSocket]()
    check ss.conn.hasOpened == false
    check ss.conn.isClosed == false
    let openp = ss.conn.onOpen()
    let onclosep = ss.conn.onClose()
    check openp.finished == false
    check onclosep.finished == false

    ==== "attach"
    var sock = newTestSocket()
    ss.attachTo(sock)
    check ss.conn.hasOpened
    check openp.finished

    ==== "send"
    let sendp = ss.send("somedata")
    check sendp.finished
    check sock.sent == "somedata"

    ==== "recv"
    let recvp = ss.recv(5)
    check recvp.finished == false
    sock.put("apples")
    check recvp.finished
    check recvp.read() == "apple"
    check sock.pending == "s"

    ==== "close"
    let closep = ss.conn.close()
    check ss.conn.isClosed
    check closep.finished
    check onclosep.finished
  
  test "detect close on eof":
    var sock = newTestSocket()
    var ss = newStringSocket[TestSocket]()
    ss.attachTo(sock)
    let closep = ss.conn.onClose()
    check closep.finished == false

    sock.closeRemote()
    check closep.finished == false
    check ss.conn.isClosed == false

    let recvp = ss.recv(5)
    check recvp.finished
    check recvp.read() == ""
    check closep.finished
    check ss.conn.isClosed
  
  test "send/recv after close":
    var sock = newTestSocket()
    var ss = newStringSocket[TestSocket]()
    ss.attachTo(sock)
    let closep = ss.conn.close()
    check closep.finished

    check ss.send("something").failed
    check ss.recv(5).failed

suite "Connection":

  test "basic":
    var conn = newConnection()
    check conn.onOpen.finished == false
    check conn.hasOpened == false
    check conn.isClosed == false
    check conn.onClose.finished == false

    conn.open()
    check conn.onOpen.finished
    check conn.hasOpened

    check conn.close().finished
    check conn.isClosed
    check conn.onClose.finished

  test "attachTo":
    var parent = newConnection()
    var child = newConnection()
    child.attachTo(parent)
    check not child.hasOpened
    check not parent.hasOpened
    check not child.isClosed
    check not parent.isClosed
  
  test "child opens when parent opens":
    var parent = newConnection()
    var child = newConnection()
    child.attachTo(parent)

    parent.open()
    check child.hasOpened
    check parent.hasOpened
  
  test "child closes when parent closes":
    var parent = newConnection()
    var child = newConnection()
    child.attachTo(parent)

    parent.open()
    asyncCheck parent.close()
    check child.isClosed
    check parent.isClosed
  
  test "parent closes when child closes":
    var parent = newConnection()
    var child = newConnection()
    child.attachTo(parent)

    parent.open()
    asyncCheck child.close()
    check child.isClosed
    check parent.isClosed
  
  test "child ignores parent open":
    var parent = newConnection()
    var child = newConnection()
    child.attachTo(parent, followOpen = false)

    parent.open()
    check parent.hasOpened
    check not child.hasOpened
  
  test "child ignores parent close":
    var parent = newConnection()
    var child = newConnection()
    child.attachTo(parent, followClose = false)

    parent.open()
    asyncCheck parent.close()
    check parent.isClosed
    check not child.isClosed

  test "attaching to already-open parent":
    var parent = newConnection()
    var child = newConnection()
    parent.open()
    child.attachTo(parent)
    check child.hasOpened

  test "attaching to already-open parent when not following":
    var parent = newConnection()
    var child = newConnection()
    parent.open()
    child.attachTo(parent, followOpen = false)
    check not child.hasOpened
