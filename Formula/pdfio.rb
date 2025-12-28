class Pdfio < Formula
  desc "PDFio - PDF read/write library"
  homepage "https://www.msweet.org/pdfio"
  url "https://github.com/michaelrsweet/pdfio/releases/download/v1.6.0/pdfio-1.6.0.tar.gz"
  sha256 "765b90c8e6668749bdc857abda2c55d0d6c2f9824062982bbe987d78ae9208ec"
  license "Apache-2.0"

  depends_on "pkg-config" => :build

  # Uses system zlib

  def install
    system "./configure", *std_configure_args
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <pdfio.h>
      int main() {
        return 0;
      }
    C
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lpdfio", "-o", "test"
    system "./test"
  end
end
