class FoomaticDb < Formula
  desc "OpenPrinting Foomatic printer database"
  homepage "https://github.com/OpenPrinting/foomatic-db"
  url "https://github.com/OpenPrinting/foomatic-db.git",
      revision: "d4774d0c39bcdf970ccb335452f48d9241ec1f71"
  version "20251122"
  license "GPL-2.0-or-later"

  depends_on "autoconf" => :build
  depends_on "automake" => :build

  def install
    system "autoreconf", "-fiv"
    system "./configure", "--prefix=#{prefix}",
                          "--disable-gzip-ppds",
                          "--disable-ppds-to-cups"
    system "make", "install"
  end

  test do
    assert_predicate share/"foomatic/db/source/driver", :exist?
  end
end
