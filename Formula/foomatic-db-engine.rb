class FoomaticDbEngine < Formula
  desc "OpenPrinting Foomatic PPD generator tools"
  homepage "https://github.com/OpenPrinting/foomatic-db-engine"
  url "https://github.com/OpenPrinting/foomatic-db-engine.git",
      revision: "a2b12271e145fe3fd34c3560d276a57e928296cb"
  version "4.1.0-20240405"
  license "GPL-2.0-or-later"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "ghostscript"
  depends_on "shawnz/printing/foomatic-db"
  uses_from_macos "curl"
  uses_from_macos "perl"

  # Fix build order: lib/Makefile must depend on Defaults.pm so that
  # Defaults.pm exists when Makefile.PL runs and scans for .pm files to install
  patch :p1, <<~DIFF
    --- a/Makefile.in
    +++ b/Makefile.in
    @@ -96,7 +96,7 @@ lib/Foomatic/Defaults.pm: Makefile makeDefaults
     	./makeDefaults $(INPLACE)
     	if [ x$(INPLACE) = x--inplace ] ; then touch .testing-stamp ; fi

    -lib/Makefile: lib/Makefile.PL
    +lib/Makefile: lib/Makefile.PL lib/Foomatic/Defaults.pm
     	( cd lib && $(PERL) Makefile.PL verbose INSTALLDIRS=$(PERL_INSTALLDIRS) )

     man: lib/Foomatic/Defaults.pm
  DIFF

  def install
    # foomatic uses PREFIX (not INSTALL_BASE) which installs to lib/perl5/site_perl
    ENV.prepend_create_path "PERL5LIB", libexec/"lib/perl5/site_perl"

    system "autoreconf", "-fiv"

    # These paths are used at configure time to generate Defaults.pm
    # PERLPREFIX controls where Perl modules get installed
    # LIBDIR is where templates are installed; at runtime FOOMATICDB env var
    # points to the foomatic-db data location
    ENV["PERLPREFIX"] = libexec
    ENV["LIBDIR"] = share/"foomatic"
    ENV["LIB_CUPS"] = "#{lib}/cups"
    ENV["CUPS_PPDS"] = "#{share}/cups/model"
    ENV["CUPS_ETC"] = "#{etc}/cups"

    system "./configure", "--prefix=#{prefix}",
                          "--sysconfdir=#{etc}",
                          "--disable-gscheck"
    system "make"
    system "make", "install"

    # Wrap all bin scripts to set PERL5LIB and FOOMATICDB
    foomatic_db_path = Formula["shawnz/printing/foomatic-db"].opt_share/"foomatic"
    bin.env_script_all_files(libexec/"bin",
                             PERL5LIB: ENV.fetch("PERL5LIB", ""),
                             FOOMATICDB: foomatic_db_path)
  end

  test do
    assert_predicate bin/"foomatic-ppdfile", :exist?
  end
end
