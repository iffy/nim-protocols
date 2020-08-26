# Package

version       = "0.1.0"
author        = "Matt Haggard"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"



# Dependencies

requires "nim >= 1.0.6"

task docs, "Build the docs":
  exec "nim doc2 --project --outdir:docs src/protocols.nim"
    