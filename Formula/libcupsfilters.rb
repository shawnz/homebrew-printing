class Libcupsfilters < Formula
  desc "OpenPrinting libcupsfilters - filter functions for CUPS"
  homepage "https://github.com/OpenPrinting/libcupsfilters"
  url "https://github.com/OpenPrinting/libcupsfilters/releases/download/2.1.1/libcupsfilters-2.1.1.tar.xz"
  sha256 "6c303e36cfde05a6c88fb940c62b6a18e7cdbfb91f077733ebc98f104925ce36"
  license "Apache-2.0"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "gettext" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "dbus"
  depends_on "fontconfig"
  depends_on "ghostscript"
  depends_on "jpeg-turbo"
  depends_on "libexif"
  depends_on "libiconv"
  depends_on "libpng"
  depends_on "libtiff"
  depends_on "little-cms2"
  depends_on "poppler"
  depends_on "qpdf"

  # macOS does not have execvpe - use execvp instead (envp is inherited anyway)
  patch :p1, <<~DIFF
    --- a/cupsfilters/ghostscript.c
    +++ b/cupsfilters/ghostscript.c
    @@ -32,6 +32,10 @@
     #include <signal.h>
     #include <errno.h>

    +#ifdef __APPLE__
    +#define execvpe(file, argv, envp) execvp(file, argv)
    +#endif
    +
     #define PDF_MAX_CHECK_COMMENT_LINES	20

     typedef enum gs_doc_e
  DIFF

  # Fix upstream bug: $uname variable is referenced but never set in configure.ac
  # This causes CUPS_STATEDIR to be set incorrectly on macOS
  # See: foomatic-db-engine/configure.ac line 37 for the intended pattern
  patch :p1, <<~DIFF
    --- a/configure.ac
    +++ b/configure.ac
    @@ -159,6 +159,7 @@
     # Transient run-time state dir of CUPS
     CUPS_STATEDIR=""
     AC_ARG_WITH(cups-rundir, [  --with-cups-rundir           set transient run-time state directory of CUPS],CUPS_STATEDIR="$withval",[
    +        uname=`uname`
             case "$uname" in
                     Darwin*)
                             # Darwin (OS X)
  DIFF

  def install
    # libiconv is needed on macOS (system iconv is not compatible)
    ENV.append "LDFLAGS", "-L#{Formula["libiconv"].opt_lib} -liconv"
    ENV.append "CFLAGS", "-I#{Formula["libiconv"].opt_include}"

    system "autoreconf", "-fiv"
    system "./configure", *std_configure_args, "--disable-mutool"
    system "make"
    # Override CUPS_DATADIR to install to Homebrew prefix instead of system dirs
    system "make", "install", "CUPS_DATADIR=#{share}/cups"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <cupsfilters/filter.h>
      int main() {
        return 0;
      }
    C
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lcupsfilters", "-o", "test"
    system "./test"
  end
end
