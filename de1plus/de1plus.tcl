#!/usr/local/bin/tclsh

# No trailing slash: Tcl's zipfs (used when de1app is bundled inside an
# AndroWish APK as read-only assets) rejects `cd` to a path with a trailing
# slash; a real filesystem accepts both, so this is safe everywhere.
cd "[file dirname [info script]]"
source "de1app.tcl"
