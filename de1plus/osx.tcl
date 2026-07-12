# osx.tcl -- macOS notarized-bundle data-root redirect.
#
# Sourced very early by de1app.tcl, right after ios.tcl and before pkgIndex.tcl
# / any package load. Keep this file self-contained and dependency free (core
# Tcl only), since almost nothing else has loaded yet.
#
# A NO-OP on every build except the signed+notarized macOS .app and the
# make_standalone_osx.sh dev .app -- identified by a `notarized.flag` /
# `standalone.flag` marker the build script drops into the bundle's de1plus tree.
# The ordinary in-place desktop/dev build has no marker, so this file does
# nothing and the app runs from its own (writable) tree exactly as before. iOS is
# handled separately by ios.tcl; this file bails out if ios.tcl claimed ::ios.
#
# The actual copy-to-~/Documents/Decent + build_id refresh + redirect (both the
# DATA root and the cwd) is the shared ::de1_redirect_data_root, defined in
# de1app.tcl and also used by the Android google_play_store.tcl. This file only
# adds the macOS-specific marker detection and the minimal-seed self-update fill.

set _bundle [file normalize [file dirname [info script]]]

# Two markers trigger the writable-copy redirect:
#   notarized.flag  -- the signed+notarized DISTRIBUTION build (ships a MINIMAL
#                      seed, then fills the rest via self-update on first run).
#   standalone.flag -- the make_standalone_osx.sh dev build (ships the WHOLE tree,
#                      so it must NOT self-update -- that would overwrite the dev
#                      code John is testing).
set _minimal [file exists [file join $_bundle "notarized.flag"]]
if {!([info exists ::ios] && $::ios) \
        && ($_minimal || [file exists [file join $_bundle "standalone.flag"]])} {

    set _firstrun [::de1_redirect_data_root \
        $_bundle [file join $::env(HOME) "Documents" "Decent"] "osx.tcl"]

    # Minimal seed: on the FIRST run of the notarized minimal-seed build, pull the
    # rest of the payload (the skins/resolutions pruned from the bundle, etc.) into
    # [homedir] via the self-updater, narrated by three always-foreground borg
    # toasts (arrival -> download started -> download finished). Deferred until the
    # updater + GUI exist (poll); toasts are catch-wrapped so a non-borg wish still
    # does the fill silently. start_app_update blocks (pumping events) and does NOT
    # auto-restart, so "restart to apply" fires once the whole fetch completes.
    if {$_firstrun eq "1" && $_minimal} {
        proc ::_osx_fill_minimal_seed {tries} {
            if {[llength [info commands start_app_update]] > 0 \
                    && [info exists ::de1(current_context)]} {
                catch { borg toast "This OSX version is now in your ~/Documents/Decent" }
                # John: a slim build whose in-app self-update works starts on the
                # NIGHTLY channel on first run -- always, overriding any baked
                # osx_update_channel marker -- so first-run users track the latest
                # build. 2 = nightly. Persisted so it survives past the first launch.
                catch {
                    set ::settings(app_updates_beta_enabled) 2
                    if {[llength [info commands save_settings]] > 0} { save_settings }
                }
                # Let the arrival toast linger, then kick off the background fill.
                after 4000 ::_osx_do_minimal_fill
            } elseif {$tries > 0} {
                after 2000 [list ::_osx_fill_minimal_seed [expr {$tries - 1}]]
            }
        }
        proc ::_osx_do_minimal_fill {} {
            catch { borg toast "Currently running minimal: full app downloading in the background" }
            set _ok 0
            catch { set _ok [start_app_update] }
            if {$_ok == 1} {
                catch { borg toast "Full app downloaded, restart to apply" }
            }
        }
        after 3000 [list ::_osx_fill_minimal_seed 60]
    }
}
