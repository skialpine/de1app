# google_play_store.tcl -- Google Play Store / sideload Android data-root redirect.
#
# Sourced very early by de1app.tcl, right after osx.tcl and before pkgIndex.tcl /
# any package load. Keep this file self-contained and dependency free (core Tcl
# only), since almost nothing else has loaded yet. iOS is handled separately by
# ios.tcl; this file bails out if ios.tcl already claimed the platform (::ios).
#
# A NO-OP on every build except a packaged Android build (Google Play or a
# self-contained sideload APK), identified by a `google_play.flag` / `sideload.flag`
# marker the build script drops into the bundle. An ordinary sideloaded APK with
# no marker does nothing here and runs from its own already-writable tree.
#
# WHY: this MIRRORS osx.tcl (and shares its code). A packaged build ships the
# de1plus tree as read-only assets, so writing into it via [homedir] (log.txt,
# history/, settings.tdb, profiles, self-update, ...) fails. The shared
# ::de1_redirect_data_root (defined in de1app.tcl) copies the WHOLE tree out to a
# writable ~/Documents/Decent on first run and redirects there -- both the DATA
# root (homedir) AND the cwd -- which keeps SELF-UPDATE working.
#
# This is the DELIBERATE difference from iOS: iOS forbids running interpreted code
# from a writable/user-visible location (Apple guideline 2.5.2), so ios.tcl keeps
# code read-only in the bundle and disables self-update. Android/Google Play has
# no such restriction, so it behaves like the macOS app: writable copy + working
# in-app self-update.
#
# ---------------------------------------------------------------------------
# NOT enforceable from Tcl -- the Play build/packaging side must ALSO handle:
#   * Target API level: target a recent Android API (Play requires within ~1yr).
#   * Runtime BLE permissions: BLUETOOTH_SCAN + BLUETOOTH_CONNECT (Android 12+),
#     with android:usesPermissionFlags="neverForLocation"; request at runtime.
#   * Foreground service: long-lived BLE while screen-off needs a foreground
#     service + notification (and the matching FOREGROUND_SERVICE* perms).
#   * Data Safety form: declare the opt-in cloud uploads (visualizer.coffee,
#     log_upload, the Decent account) and Bluetooth use in the Play console.
#   * Privacy policy URL in the listing.
# This file covers only the runtime concern: a writable data/code root so the
# app (and its self-updater) can run from the read-only Play package.
# ---------------------------------------------------------------------------

set _bundle [file normalize [file dirname [info script]]]

# Two Android packaged-build markers share this read-only-package redirect:
#   google_play.flag -- Google Play Store build.
#   sideload.flag    -- self-contained sideload APK (AndroWish-bundled de1app).
set _sideload [file exists [file join $_bundle "sideload.flag"]]
if {!([info exists ::ios] && $::ios) \
        && ([file exists [file join $_bundle "google_play.flag"]] || $_sideload)} {

    if {$_sideload} { set ::sideload_build 1 } else { set ::play_store_build 1 }

    set _firstrun [::de1_redirect_data_root \
        $_bundle [file join $::env(HOME) "Documents" "Decent"] "google_play_store.tcl"]

    # This packaged build ships a self-contained seed (the popular skins + all
    # fonts). Per John: NO "slim/minimal install" toast, and do NOT auto-start the
    # app self-update on launch -- the user triggers updates manually from Settings
    # if/when they want the remaining (decorative) skins. So the only first-run
    # action is to default the update channel to NIGHTLY so first-run users track
    # the latest build. Deferred until the GUI + updater have loaded (poll) so this
    # very-early set is not clobbered when settings.tdb loads; then persisted.
    if {$_firstrun eq "1"} {
        proc ::_slim_first_run_set_nightly {tries} {
            if {[info exists ::de1(current_context)] \
                    && [llength [info commands start_app_update]] > 0 \
                    && [llength [info commands save_settings]] > 0} {
                catch {
                    set ::settings(app_updates_beta_enabled) 2
                    save_settings
                }
            } elseif {$tries > 0} {
                after 2000 [list ::_slim_first_run_set_nightly [expr {$tries - 1}]]
            }
        }
        after 3000 [list ::_slim_first_run_set_nightly 60]
    }
}
