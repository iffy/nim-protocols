import asyncdispatch
import asyncfile
import osproc
import nativesockets

import ./base

type
  FileReadTransport* = ref object of RootObj
    conn*: Connection
    afile: AsyncFile
  
  FileWriteTransport* = ref object of RootObj
    conn*: Connection
    afile: AsyncFile

  ProcessStream* = ref object of RootObj
    conn*: Connection
    p: Process
    terr*: FileReadTransport
    tout*: FileReadTransport
    tin*: FileWriteTransport

proc setNonBlocking(fh: FileHandle) {.inline.} =
  setBlocking(fh.AsyncFD.SocketHandle, false)

#--------------------------------------------------------------------
# Transports
#--------------------------------------------------------------------
proc newFileReadTransport*(fh: FileHandle, conn: Connection): FileReadTransport=
  new(result)
  result.conn = conn
  result.afile = newAsyncFile(fh.AsyncFD)
  fh.setNonBlocking()

proc read*(t: FileReadTransport, size: int): Future[string] =
  if t.conn.isClosed:
    result = newFuture[string]()
    result.fail(newException(ValueError, "Failed reading data from closed file"))
  else:
    result = t.afile.read(size)

proc newFileWriteTransport*(fh: FileHandle, conn: Connection): FileWriteTransport =
  new(result)
  result.conn = conn
  result.afile = newAsyncFile(fh.AsyncFD)
  fh.setNonBlocking()

proc send*(t: FileWriteTransport, data: string): Future[void] =
  if t.conn.isClosed:
    result = newFuture[void]()
    result.fail(newException(ValueError, "Failed writing data to closed file"))
  else:
    result = t.afile.write(data)

#--------------------------------------------------------------------
# ProcessStream
#--------------------------------------------------------------------

proc newProcessStream*(p: Process): ProcessStream =
  new(result)
  result.conn = newConnection()
  result.p = p
  let
    ih = p.inputHandle()
    oh = p.outputHandle()
    eh = p.errorHandle()
  result.terr = newFileReadTransport(eh, result.conn)
  result.tout = newFileReadTransport(oh, result.conn)
  result.tin = newFileWriteTransport(ih, result.conn)
  result.conn.open()

proc closeIfNotRunning(stream: ProcessStream) {.inline.} =
  if not stream.conn.isClosed and not stream.p.running:
    stream.conn.close()

proc send*(stream: ProcessStream, data: string): Future[void] =
  stream.closeIfNotRunning()
  stream.tin.send(data)
  
proc read*(stream: ProcessStream, size: int): Future[string] =
  stream.closeIfNotRunning()
  stream.tout.read(size)
  