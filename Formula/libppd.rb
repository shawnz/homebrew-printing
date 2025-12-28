class Libppd < Formula
  desc "OpenPrinting libppd - PPD file support library"
  homepage "https://github.com/OpenPrinting/libppd"
  url "https://github.com/OpenPrinting/libppd/releases/download/2.1.1/libppd-2.1.1.tar.xz"
  sha256 "3fa341cc03964046d2bf6b161d80c1b4b2e20609f38d860bcaa11cb70c1285e4"
  license "Apache-2.0"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "gettext" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "shawnz/printing/libcupsfilters"
  depends_on "shawnz/printing/pdfio"
  depends_on "ghostscript"
  depends_on "poppler"

  # macOS fixes:
  # - libgen.h for dirname() - missing from upstream, works on Linux by accident
  # - environ access in shared libraries requires _NSGetEnviron
  patch :p1, <<~DIFF
    --- a/ppd/ppd-collection.cxx
    +++ b/ppd/ppd-collection.cxx
    @@ -17,6 +17,11 @@
     //

     #include <cups/dir.h>
     #include <cups/transcode.h>
    +#include <libgen.h>
    +#ifdef __APPLE__
    +#include <crt_externs.h>
    +#define environ (*_NSGetEnviron())
    +#endif
     #include <ppd/ppd.h>
     #include <ppd/ppdc.h>
     #include <ppd/file-private.h>
  DIFF

  # Fix upstream bug: $uname variable is referenced but never set in configure.ac
  # This causes CUPS_STATEDIR to be set incorrectly on macOS
  # See: foomatic-db-engine/configure.ac line 37 for the intended pattern
  patch :p1, <<~DIFF
    --- a/configure.ac
    +++ b/configure.ac
    @@ -146,6 +146,7 @@
     # Transient run-time state dir of CUPS
     CUPS_STATEDIR=""
     AC_ARG_WITH(cups-rundir, [  --with-cups-rundir           set transient run-time state directory of CUPS],CUPS_STATEDIR="$withval",[
    +        uname=`uname`
             case "$uname" in
                     Darwin*)
                             # Darwin (OS X)
  DIFF

  def install
    system "autoreconf", "-fiv"
    system "./configure", *std_configure_args, "--disable-mutool"
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <ppd/ppd.h>
      int main() {
        return 0;
      }
    C
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lppd", "-o", "test"
    system "./test"
  end
end
