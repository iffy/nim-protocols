import unittest
import osproc

import protocols
import protocols/process
import ./utils

when not defined(windows):
  suite "ProcessStream":
    test "concepts":
      var p = startProcess(findExe"echo", args = ["hi"], options = {})
      var s = newProcessStream(p)
      assertConcept(StreamProvider, s)

    test "works":
      withtmpdir:
        let script = "somefile.nim"
        script.writeFile("""
  import os
  setStdIoUnbuffered()
  stdout.write("hi")
  stderr.write("foo1")
  let line = stdin.readLine()
  stdout.write(line)
  stdout.write("hoop")
  stderr.write("foo2")
        """)
        var p = startProcess(findExe"nim", args = [
          "c", "--verbosity:0", "--hints:off", "--warnings:off",
          "-r", script],
          options = {})
        var s = newProcessStream(p)
        assertConcept(ReadTransport, s.terr)
        assertConcept(ReadTransport, s.tout)
        assertConcept(WriteTransport, s.tin)

        check s.conn.hasOpened
        check not s.conn.isClosed
        
        let e1 = s.terr.read(4)
        let e2 = s.terr.read(4)

        let d1 = s.read(2)
        let d2 = s.read(3)
        let d3 = s.read(4)

        check d2.finished == false
        check d3.finished == false

        let s1 = s.send("foo\n")
        checkpoint "waiting for s1"
        waitFor s1
        discard waitFor d2
        # there's a delay right here that I don't understand
        discard waitFor d3

        checkpoint "checking read values"

        check d1.read() == "hi"
        check d2.read() == "foo"
        check d3.read() == "hoop"
        check e1.read() == "foo1"
        check e2.read() == "foo2"

        sleep(100)
        
        check s.send("something").failed
        check s.read(2).failed
        check s.conn.isClosed
