import times; export times
import os; export os
import random; export random
randomize()

template withtmpdir*(body:untyped):untyped =
  let tmpdir = getTempDir() / ($getTime().toUnix()) & $rand(10000)
  tmpdir.createDir()
  let olddir = getCurrentDir()
  setCurrentDir(tmpdir)
  checkpoint tmpdir
  try:
    body
  finally:
    setCurrentDir(olddir)
