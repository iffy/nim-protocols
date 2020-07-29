import unittest

import protocols
import protocols/base
import protocols/util

proc `====`(message:string) {.inline.} =
  checkpoint "==== " & message

suite "StringSocket":
  test "concepts":
    var ss = newStringSocket[AsyncSocket]()
    check ss is StreamTransport
    check ss is Connectable
    check ss is SocketUser
  
  test "lifecycle":
    ==== "init"
    var ss = newStringSocket[TestSocket]()
    check ss.hasOpened == false
    check ss.isClosed == false
    let openp = ss.onOpen()
    let onclosep = ss.onClose()
    check openp.finished == false
    check onclosep.finished == false

    ==== "attach"
    var sock = newTestSocket()
    ss.attachTo(sock)
    check ss.hasOpened
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
    let closep = ss.close()
    check ss.isClosed
    check closep.finished
    check onclosep.finished
  
  test "detect close on eof":
    var sock = newTestSocket()
    var ss = newStringSocket[TestSocket]()
    ss.attachTo(sock)
    let closep = ss.onClose()
    check closep.finished == false

    sock.closeRemote()
    check closep.finished == false
    check ss.isClosed == false

    let recvp = ss.recv(5)
    check recvp.finished
    check recvp.read() == ""
    check closep.finished
    check ss.isClosed
  
  test "send/recv after close":
    var sock = newTestSocket()
    var ss = newStringSocket[TestSocket]()
    ss.attachTo(sock)
    let closep = ss.close()
    check closep.finished

    check ss.send("something").failed
    check ss.recv(5).failed


