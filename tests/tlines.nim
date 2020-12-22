import unittest

import protocols
import protocols/memory
import protocols/lines

suite "DelimitedTransport":

  test "concepts":
    var s = newDelimitedTransport[MemoryStream]()
    # assertConcept(MessageProvider, s)
    # assertConcept(StreamConsumer, s)

  test "readMessage":
    var ss = newMemoryStream(buffered = false)
    var dt = newDelimitedTransport[MemoryStream](":")
    dt.attachTo(ss)

    var msg1 = dt.readMessage()
    var msg2 = dt.readMessage()
    check msg1.finished == false
    check msg2.finished == false

    ss.put("cat:how")
    check msg1.finished == true
    check msg1.read() == "cat"
    check msg2.finished == false

    ss.put("dy:")
    check msg2.finished
    check msg2.read() == "howdy"

    ss.put("stuff:")
    var msg3 = dt.readMessage()
    check msg3.finished
    check msg3.read() == "stuff"
  
  test "sendMessage":
    var ss = newMemoryStream(buffered = false)
    var dt = newDelimitedTransport[MemoryStream](":")
    dt.attachTo(ss)

    asyncCheck dt.sendMessage("hi")
    asyncCheck dt.sendMessage("")
    asyncCheck dt.sendMessage("abcdefghijklmnop")
    check ss.sent == "hi::abcdefghijklmnop:"

  test "connected":
    var ss = newMemoryStream()
    var dt = newDelimitedTransport[MemoryStream]()
    dt.attachTo(ss)
    check dt.conn.hasOpened
  
  test "disconnected":
    var ss = newMemoryStream()
    var dt = newDelimitedTransport[MemoryStream]()
    dt.attachTo(ss)

    var msg1 = dt.readMessage()
    check dt.conn.onClose.finished == false
    dt.conn.close()
    check dt.conn.onClose.finished
    check msg1.failed
