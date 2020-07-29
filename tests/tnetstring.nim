import unittest

import protocols
import protocols/concepts
import protocols/netstring
import protocols/util

test "nsencode":
  check nsencode("apple") == "5:apple,"
  check nsencode("") == "0:,"
  check nsencode("banana\x00,") == "8:banana\x00,,"

test "nsencode newline":
  check nsencode("apple", '\n') == "5:apple\n"
  check nsencode("", '\n') == "0:\n"
  check nsencode("banana\x00\n", '\n') == "8:banana\x00\n\n"

suite "NetstringDecoder":

  test "netstring in, message out":
    var ns = newNetstringDecoder()
    ns.consume("5:apple,")
    check ns.len == 1
    ns.consume("7:bana")
    check ns.len == 1
    ns.consume("na\x00,3:foo,3:bar")
    check ns.len == 3
    ns.consume(",")
    check ns.len == 4
    check ns.nextMessage() == "apple"
    check ns.nextMessage() == "banana\x00"
    check ns.nextMessage() == "foo"
    check ns.nextMessage() == "bar"
  
  test "newline delimiter":
    var ns = newNetstringDecoder('\n')
    ns.consume("5:apple\n")
    check ns.len == 1
    ns.consume("7:bana")
    check ns.len == 1
    ns.consume("na\x00\n3:foo\n3:bar")
    check ns.len == 3
    ns.consume("\n")
    check ns.len == 4
    check ns.nextMessage() == "apple"
    check ns.nextMessage() == "banana\x00"
    check ns.nextMessage() == "foo"
    check ns.nextMessage() == "bar"

  test "empty string":
    var ns = newNetstringDecoder()
    ns.consume("0:,")
    check ns.nextMessage() == ""
  
  test "can't start with 0":
    var ns = newNetstringDecoder()
    expect(Exception):
      ns.consume("01:,")
  
  test "can't include non-numerics":
    var ns = newNetstringDecoder()
    expect(Exception):
      ns.consume("1a:,")
  
  test ": required":
    var ns = newNetstringDecoder()
    expect(Exception):
      ns.consume("1f,")
  
  test ", required":
    var ns = newNetstringDecoder()
    expect(Exception):
      ns.consume("1:a2:ab,")
  
  test "len required":
    var ns = newNetstringDecoder()
    expect(Exception):
      ns.consume(":s,")

  test "max message length":
    var ns = newNetstringDecoder()
    
    ns.maxlen = 4
    ns.consume("4:fooa,")
    expect(Exception):
      ns.consume("5:")
    ns.reset()

    ns.maxlen = 10000
    expect(Exception):
      ns.consume("100000")

suite "NetstringTransport":

  # test "concepts":
  #   check NetstringTransport is MessageTransport
  #   check NetstringTransport is StreamUser

  test "recvMessage":
    var sock = newTestSocket()
    var ss = newStringSocket[TestSocket]()
    ss.attachTo(sock)
    var nss = newNetstringTransport[StringSocket[TestSocket]]()
    nss.attachTo(ss)

    var msg1 = nss.recvMessage()
    var msg2 = nss.recvMessage()
    var msg3 = nss.recvMessage()
    check msg1.finished == false
    check msg2.finished == false
    check msg3.finished == false

    sock.put("3:cat,")
    assert msg1.finished
    check msg1.read() == "cat"
    check msg2.finished == false
    
    sock.put("2:a")
    check msg2.finished == false
    
    sock.put("b,3:cow")
    assert msg2.finished
    check msg2.read() == "ab"
    check msg3.finished == false
    
    sock.put(",")
    assert msg3.finished
    check msg3.read() == "cow"

  test "sendMessage":
    var sock = newTestSocket()
    var ss = newStringSocket[TestSocket]()
    ss.attachTo(sock)
    var nss = newNetstringTransport[StringSocket[TestSocket]]()
    nss.attachTo(ss)

    asyncCheck nss.sendMessage("hello")
    asyncCheck nss.sendMessage("cat")
    check sock.sent == "5:hello,3:cat,"

  test "0-length":
    var sock = newTestSocket()
    var ss = newStringSocket[TestSocket]()
    ss.attachTo(sock)
    var nss = newNetstringTransport[StringSocket[TestSocket]]()
    nss.attachTo(ss)

    var msg1 = nss.recvMessage()
    var msg2 = nss.recvMessage()
    sock.put("0:,0:,")
    assert msg1.finished
    assert msg2.finished
    check msg1.read == ""
    check msg2.read == ""
  
  test "connected":
    var sock = newTestSocket()
    var ss = newStringSocket[TestSocket]()
    ss.attachTo(sock)
    var nss = newNetstringTransport[StringSocket[TestSocket]]()
    nss.attachTo(ss)
    check nss.conn.hasOpened
  
  test "disconnected":
    var sock = newTestSocket()
    var ss = newStringSocket[TestSocket]()
    ss.attachTo(sock)
    var nss = newNetstringTransport[StringSocket[TestSocket]]()
    nss.attachTo(ss)
    var msg1 = nss.recvMessage()
    var msg2 = nss.recvMessage()
    var msg3 = nss.recvMessage()
    check nss.conn.onClose.finished == false
    sock.closeRemote()
    check nss.conn.onClose.finished
    check msg1.failed
    check msg2.failed
    check msg3.failed
  
  test "invalid message":
    var sock = newTestSocket()
    var ss = newStringSocket[TestSocket]()
    ss.attachTo(sock)
    var nss = newNetstringTransport[StringSocket[TestSocket]]()
    nss.attachTo(ss)
    var msg1 = nss.recvMessage()
    sock.put("garbage ")
    check nss.conn.onClose.finished
    check msg1.failed
