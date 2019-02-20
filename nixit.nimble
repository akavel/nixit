# Package

version       = "0.1.0"
author        = "Mateusz Czapliński"
description   = "NixIT file changes checker"
license       = "Apache-2.0"
srcDir        = "."
bin           = @["nixit"]


# Dependencies

requires "nim >= 0.19.4"
requires "patty 0.3.3"
requires "gara 0.2.0"
