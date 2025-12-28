class CupsFilters < Formula
  desc "OpenPrinting CUPS filters and backends"
  homepage "https://github.com/OpenPrinting/cups-filters"
  url "https://github.com/OpenPrinting/cups-filters.git",
      revision: "956283c74a34ae924266a2a63f8e5f529a1abd06"
  version "2.0.1-20251120"
  license "Apache-2.0"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "gettext" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "shawnz/printing/libcupsfilters"
  depends_on "shawnz/printing/libppd"
  depends_on "fontconfig"
  depends_on "ghostscript"
  depends_on "poppler"
  depends_on "qpdf"

  # foomatic-rip hash paths are derived from datadir/sysconfdir at build time,
  # but Homebrew uses versioned Cellar paths. Override to use stable prefix paths
  # so hashes written by driver formulas (like min12xxw) are found across upgrades.
  patch :p1, <<~DIFF
    --- a/Makefile.am
    +++ b/Makefile.am
    @@ -287,8 +287,8 @@ libfoomatic_util_la_SOURCES = \\
     	filter/foomatic-rip/process.h
     libfoomatic_util_la_CFLAGS = \\
    -	-DSYS_HASH_PATH='"$(datadir)/foomatic/hashes.d"' \\
    -	-DUSR_HASH_PATH='"$(sysconfdir)/foomatic/hashes.d"' \\
    +	-DSYS_HASH_PATH='"/opt/homebrew/share/foomatic/hashes.d"' \\
    +	-DUSR_HASH_PATH='"/opt/homebrew/etc/foomatic/hashes.d"' \\
     	$(CUPS_CFLAGS)
     libfoomatic_util_la_LIBADD = \\
     	$(CUPS_LIBS)
  DIFF

  # Homebrew installs as user, not root. Disable root ownership check for hash files.
  # TODO: Reconsider this security tradeoff later.
  patch :p1, <<~DIFF
    --- a/filter/foomatic-rip/util.c
    +++ b/filter/foomatic-rip/util.c
    @@ -1597,7 +1597,6 @@ load_system_hashes(cups_array_t **hashes) // O - Array of existing hashes
           // Ignore any unsafe files - dirs, symlinks, hidden files, non-root writable files...

           if (!strncmp(dent->filename, "../", 3) ||
    -	  dent->fileinfo.st_uid ||
     	  (dent->fileinfo.st_mode & S_IWGRP) ||
     	  (dent->fileinfo.st_mode & S_ISUID) ||
     	  (dent->fileinfo.st_mode & S_IWOTH))
  DIFF

  def install
    # IOKit/CoreFoundation needed for serial backend on macOS
    ENV.append "LDFLAGS", "-framework IOKit -framework CoreFoundation"

    system "autoreconf", "-fiv"
    system "./configure", *std_configure_args, "--disable-mutool"
    system "make"
    # Override CUPS paths to install to Homebrew prefix instead of system dirs
    system "make", "install",
           "CUPS_SERVERBIN=#{lib}/cups",
           "CUPS_DATADIR=#{share}/cups"
  end

  test do
    assert_predicate lib/"cups/filter/foomatic-rip", :exist?
  end
end
