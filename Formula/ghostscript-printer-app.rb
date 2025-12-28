class GhostscriptPrinterApp < Formula
  desc "Printer Application for Ghostscript-based drivers"
  homepage "https://github.com/OpenPrinting/ghostscript-printer-app"
  url "https://github.com/OpenPrinting/ghostscript-printer-app.git",
      revision: "9c5ea0f1c9f3187d3b983d079a8a968f2c8bab29"
  version "1.0-20251205"
  license "Apache-2.0"

  depends_on "pkg-config" => :build
  depends_on "shawnz/printing/cups-filters"
  depends_on "shawnz/printing/foomatic-db-engine"
  depends_on "shawnz/printing/libcupsfilters"
  depends_on "shawnz/printing/libppd"
  depends_on "shawnz/printing/pappl"
  depends_on "shawnz/printing/pappl-retrofit"
  depends_on "ghostscript"

  def install
    # Don't override CFLAGS/LDFLAGS - the Makefile uses += to append pkg-config
    # flags, and passing CFLAGS= on command line would override rather than append
    system "make", "CC=#{ENV.cc}",
                   "prefix=#{prefix}",
                   "localstatedir=#{var}",
                   "VERSION=#{version}"
    system "make", "install",
                   "prefix=#{prefix}",
                   "localstatedir=#{var}",
                   "ppddir=#{share}/ppd",
                   "statedir=#{var}/lib/ghostscript-printer-app",
                   "spooldir=#{var}/spool/ghostscript-printer-app",
                   "serverbin=#{lib}/ghostscript-printer-app",
                   "resourcedir=#{share}/ghostscript-printer-app"
  end

  def post_install
    (var/"lib/ghostscript-printer-app").mkpath
    (var/"spool/ghostscript-printer-app").mkpath
    (var/"log").mkpath
  end

  def caveats
    <<~EOS
      To start the printer application service:
        brew services start ghostscript-printer-app

      The web interface will be available at:
        https://localhost:8501

      To add a printer, install a driver formula (e.g., min12xxw) and
      use the web interface or System Settings → Printers & Scanners.

      Logs are written to:
        #{var}/log/ghostscript-printer-app.log
    EOS
  end

  service do
    run [opt_bin/"ghostscript-printer-app", "server",
         "-o", "listen-hostname=localhost",
         "-o", "state-directory=#{var}/lib/ghostscript-printer-app",
         "-o", "spool-directory=#{var}/spool/ghostscript-printer-app",
         "-o", "ppd-directories=#{HOMEBREW_PREFIX}/share/ppd",
         "-o", "filter-directory=#{HOMEBREW_PREFIX}/lib/cups/filter",
         "-o", "backend-directory=/usr/libexec/cups/backend"]
    # foomatic-rip needs PATH to find gs and driver binaries (e.g., min12xxw)
    environment_variables PATH: "#{HOMEBREW_PREFIX}/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    keep_alive true
    working_dir var
    log_path var/"log/ghostscript-printer-app.log"
    error_log_path var/"log/ghostscript-printer-app.log"
  end

  test do
    assert_match "ghostscript-printer-app", shell_output("#{bin}/ghostscript-printer-app --help 2>&1")
  end
end
