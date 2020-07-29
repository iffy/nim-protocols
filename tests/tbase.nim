import unittest

import protocols
import protocols/base

suite "StringSocket":
  test "concepts":
    let ss = newStringSocket()
    check ss is StreamTransport
    check ss is Connectable
    # check ss is SocketUser

