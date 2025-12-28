class Min12xxw < Formula
  desc "Print driver for Minolta PagePro 1[234]xxW printers"
  homepage "https://salsa.debian.org/printing-team/min12xxw"
  url "https://salsa.debian.org/printing-team/min12xxw.git",
      revision: "5a521d847c15497dd44c7d694a69cfdf6ff17509"
  version "0.0.9-20230114"
  license "GPL-2.0-or-later"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "shawnz/printing/cups-filters"
  depends_on "shawnz/printing/foomatic-db-engine"

  def install
    system "autoreconf", "-fiv"
    system "./configure", *std_configure_args
    system "make"
    system "make", "install"

    # Generate PPD files for all supported printers
    ppd_dir = share/"ppd/min12xxw"
    ppd_dir.mkpath

    printers = %w[
      Minolta-PagePro_1200W
      Minolta-PagePro_1250W
      Minolta-PagePro_1300W
      Minolta-PagePro_1350W
      Minolta-PagePro_1400W
    ]

    foomatic_ppdfile = Formula["shawnz/printing/foomatic-db-engine"].bin/"foomatic-ppdfile"
    printers.each do |printer|
      ppd_file = ppd_dir/"#{printer}.ppd"
      # foomatic-ppdfile outputs to stdout
      system "sh", "-c", "#{foomatic_ppdfile} -p #{printer} -d min12xxw > #{ppd_file}"
    end

    # Generate foomatic-rip command hashes to approve the PPD command lines
    hashes_dir = etc/"foomatic/hashes.d"
    hashes_dir.mkpath
    hashes_file = hashes_dir/"min12xxw.hashes"

    foomatic_hash = Formula["shawnz/printing/cups-filters"].bin/"foomatic-hash"
    Dir["#{ppd_dir}/*.ppd"].each do |ppd|
      system foomatic_hash, "--ppd", ppd, "/dev/null", hashes_file
    end
  end

  def caveats
    <<~EOS
      PPD files have been installed to:
        #{share}/ppd/min12xxw/

      These PPDs are used by ghostscript-printer-app to provide
      printer support for Minolta PagePro 1200W-1400W printers.
    EOS
  end

  test do
    assert_match "min12xxw", shell_output("#{bin}/min12xxw --help 2>&1", 1)
  end
end
