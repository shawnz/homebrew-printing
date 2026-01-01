# Homebrew Printing Formulas

This repository contains Homebrew formulas for running legacy printer drivers on modern macOS using the [PAPPL](https://www.msweet.org/pappl/) printer application framework.

## Motivation

These formulas were created to get my wife's Konica Minolta PagePro 1400W laser printer working on modern macOS (Sequoia 15.x, Tahoe 26.x). This is challenging because:

- The `min12xxw` driver hasn't been updated since 2007
- Apple has deprecated traditional CUPS drivers and PPD files ([apple/cups#5270](https://github.com/apple/cups/issues/5270), [#5271](https://github.com/apple/cups/issues/5271))
- The printing stack has shifted toward "driverless" IPP Everywhere printers
- CUPS sandboxing blocks `foomatic-rip` from spawning external processes (Ghostscript, driver binaries), requiring `Sandboxing Relaxed` in `/etc/cups/cups-files.conf` as a workaround
- Even if we wanted to place binaries in sandbox-friendly paths, System Integrity Protection prevents modifications to `/usr/libexec/cups`

This tap packages the OpenPrinting [ghostscript-printer-app](https://github.com/OpenPrinting/ghostscript-printer-app), which wraps legacy Ghostscript-based drivers in a modern IPP printer application. The printer appears as a network printer to macOS, avoiding the deprecated driver path entirely.

## Installation

```bash
# Add this tap
brew tap shawnz/printing

# Install the printer application and your driver
brew install shawnz/printing/ghostscript-printer-app
brew install shawnz/printing/min12xxw  # or another driver formula

# Start the service for this session only (stops when you log out)
brew services run shawnz/printing/ghostscript-printer-app

# Or, to start at login automatically
brew services start shawnz/printing/ghostscript-printer-app
```

## Adding Your Printer

1. **Open the web interface**: Click the printer icon in your menu bar, or navigate to https://localhost:8501

2. **Add your printer** in the ghostscript-printer-app web interface:
   - Click "Add Printer"
   - Select your printer's connection (USB or network)
   - Choose the appropriate driver/PPD

3. **Add to macOS**: Go to System Settings → Printers & Scanners → Add Printer
   - Your printer should appear as a Bonjour network printer
   - Select it and add

## What's Included

| Formula | Description |
|---------|-------------|
| `ghostscript-printer-app` | PAPPL-based printer application for Ghostscript/foomatic drivers |
| `min12xxw` | Driver for Minolta PagePro 1200W/1300W/1350W/1400W printers |
| `cups-filters` | OpenPrinting CUPS filters (foomatic-rip, etc.) |
| `libcupsfilters` | Filter function library |
| `libppd` | PPD file support library |
| `pappl-retrofit` | Retrofits classic CUPS drivers into PAPPL applications |
| `pappl` | Printer Application Framework |
| `pdfio` | PDF read/write library |
| `foomatic-db` | Foomatic printer database |
| `foomatic-db-engine` | Foomatic database engine |

## Caveats and Design Decisions

### Upstream Bugs (Masked on Linux)

These are bugs that happen to work on Linux but are still incorrect.

- **`$uname` variable never set in configure.ac** (libppd, libcupsfilters)

  Both libraries reference `$uname` in a `case` statement to detect macOS, but never set the variable. This causes `CUPS_STATEDIR` to be set incorrectly. We patch this by adding `` uname=`uname` `` before the case statement, matching the pattern used in `foomatic-db-engine`.

- **Missing `#include <libgen.h>` for `dirname()`** (libppd)

  Works on Linux by accident due to header pollution from other includes, but fails to compile on macOS.

- **Header files installed to wrong path** (pappl-retrofit)

  The pkg-config file references `${includedir}/pappl-retrofit` but headers were installed directly to `${includedir}`. Works on Linux because `/usr/local/include` is in the default search path, but Homebrew's `/opt/homebrew/include/pappl-retrofit` is not.

- **Missing `PAPPL_CFLAGS` in build** (pappl-retrofit)

  The `legacy_printer_app` target includes PAPPL headers but didn't add `$(PAPPL_CFLAGS)` to its compiler flags. Works on Linux where `/usr/include` is searched by default, but fails on Homebrew where PAPPL headers are in `/opt/homebrew/include`.

### macOS Portability (Worth Fixing Upstream)

These aren't bugs per se, but prevent building on macOS and would benefit from upstream fixes.

- **Missing `execvpe()` on macOS** (libcupsfilters)

  `execvpe()` is a glibc extension not available on macOS. We patch `ghostscript.c` to use `execvp()` instead, which works because the environment is inherited anyway. See [OpenPrinting/libcupsfilters#60](https://github.com/OpenPrinting/libcupsfilters/issues/60).

- **`environ` not accessible in shared libraries** (libppd)

  On macOS, shared libraries must use `_NSGetEnviron()` instead of `extern char **environ`.

- **Stack overflow when listing backends** (pappl-retrofit)

  The `backends[]` and `backend_fds[]` arrays in `cups-backends.c` are allocated on the stack (~800KB total), but macOS thread stack is only 512KB (vs 8MB on Linux). We patch this to use heap allocation.

- **Missing `reallocarray()` on macOS** (pappl-retrofit)

  `reallocarray()` is a BSD/glibc function not available on macOS. We add a compatibility shim.

- **Serial backend missing macOS frameworks** (cups-filters)

  The serial backend uses IOKit and CoreFoundation APIs but doesn't link against these frameworks.

### Homebrew-Specific Compromises

- **CUPS directory configuration**

  CUPS uses several directory variables that serve different purposes at build time vs runtime:

  *Installation paths* (overridden to use Homebrew prefix):
  - `CUPS_SERVERBIN` and `CUPS_DATADIR` are used by Makefiles to determine where to install filters, backends, banners, charsets, etc.
  - Upstream defaults would install to `/usr/libexec/cups` and `/usr/share/cups`, which would clobber system resources and fail due to SIP
  - We override these at `make install` time to redirect files to the Homebrew prefix

  *Runtime paths* (configured via ghostscript-printer-app options):
  - `filter-directory` → Homebrew's `lib/cups/filter` (our foomatic-rip)
  - `ppd-directories` → Homebrew's `share/ppd` (our generated PPDs)
  - `backend-directory` → System's `/usr/libexec/cups/backend` (we leverage macOS's existing usb/socket backends rather than replicating them)

  *Compiled-in paths* (point to system CUPS):
  - `CUPS_STATEDIR` → `/private/etc/cups` (runtime state, shared with system CUPS)
  - `CUPS_SERVERROOT` → `/private/etc/cups` (configuration lookups)

- **Disabled root ownership check for PPD hash files** (cups-filters)

  foomatic-rip validates that PPD command-line hash files are owned by root as a security measure. Since Homebrew installs files as the current user, we patch out this check. This is a security tradeoff: it means a compromised user account could potentially modify hash files to allow arbitrary commands in PPDs.

- **PATH injection for foomatic-rip**

  The `foomatic-rip` filter shells out to `gs` and driver binaries. We inject `/opt/homebrew/bin` into PATH via the service definition to ensure these are found.

- **SF Symbol for menu bar icon** (pappl)

  PAPPL uses `[NSApp.applicationIconImage copy]` for the menu bar icon, which shows a generic folder icon for command-line applications without a bundle. Packaging as a proper `.app` bundle would fix this but adds complexity (Info.plist, code signing, service definition changes). Instead, we patch PAPPL to use the SF Symbol `printer.fill`. If we add more printer apps to this repo in the future, we may want a more flexible solution (e.g., parameterizing the icon in PAPPL).

- **Listening on localhost only**

  The printer application binds to `localhost:8501` by default. This is a security measure—exposing it to the network would allow anyone to print. Modify the service if you need network access.

## Project Structure

```
homebrew-printing/
├── Formula/
│   ├── ghostscript-printer-app.rb  # Main printer application
│   ├── min12xxw.rb                 # Minolta PagePro driver
│   ├── cups-filters.rb             # foomatic-rip and filters
│   ├── libcupsfilters.rb           # Filter library
│   ├── libppd.rb                   # PPD support library
│   ├── pappl-retrofit.rb           # CUPS→PAPPL adapter
│   ├── pappl.rb                    # Printer application framework
│   ├── pdfio.rb                    # PDF library
│   ├── foomatic-db.rb              # Printer database
│   └── foomatic-db-engine.rb       # Database tools
├── LICENSE
└── README.md
```

## Debugging

View the application log:
```bash
tail -f /opt/homebrew/var/log/ghostscript-printer-app.log
```

Run the server directly with debug logging:
```bash
ghostscript-printer-app server \
  -o log-level=debug \
  -o listen-hostname=localhost \
  -o state-directory=/opt/homebrew/var/lib/ghostscript-printer-app \
  -o spool-directory=/opt/homebrew/var/spool/ghostscript-printer-app \
  -o ppd-directories=/opt/homebrew/share/ppd \
  -o filter-directory=/opt/homebrew/lib/cups/filter \
  -o backend-directory=/usr/libexec/cups/backend
```

Test foomatic-rip directly:
```bash
PPD=/opt/homebrew/share/ppd/your-printer.ppd \
/opt/homebrew/lib/cups/filter/foomatic-rip 1 user title 1 "" < test.pdf > output.prn
```

Check the web interface at https://localhost:8501 for job status and errors.

## Made with Claude Code

This entire project—including the Homebrew formulas, patches, debugging, and this README—was developed collaboratively with [Claude Code](https://claude.ai/code), Anthropic's AI coding assistant.

The development process involved:
- Tracing through the OpenPrinting codebase to understand the filter pipeline
- Debugging macOS-specific compilation issues (missing functions, header differences)
- Identifying upstream bugs by cross-referencing multiple OpenPrinting projects
- Iteratively testing the print pipeline from PDF input to printer output

## License

The formulas in this repository are provided under the MIT license. The upstream projects have their own licenses:
- PAPPL, pappl-retrofit, libcupsfilters, libppd, cups-filters: Apache-2.0
- min12xxw: GPL-2.0
- Ghostscript: AGPL-3.0
- foomatic-db, foomatic-db-engine: GPL-2.0

## Acknowledgments

- [OpenPrinting](https://openprinting.github.io/) for maintaining the Linux/Unix printing infrastructure
- [Till Kamppeter](https://github.com/tillkamppeter) for the printer application framework
- [Michael Sweet](https://www.msweet.org/) for PAPPL and decades of CUPS development
- The min12xxw authors for reverse-engineering the Minolta printer protocol
