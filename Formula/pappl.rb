class Pappl < Formula
  desc "Printer Application Framework"
  homepage "https://www.msweet.org/pappl"
  url "https://github.com/michaelrsweet/pappl/releases/download/v1.4.9/pappl-1.4.9.tar.gz"
  sha256 "50fec863a28a3c39af639de29d58bf8cefdafa258b66e3c0dfbe2097801dc9db"
  license "Apache-2.0"

  depends_on "pkg-config" => :build
  depends_on "shawnz/printing/pdfio"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "libusb"
  depends_on "openssl@3"

  # Uses system CUPS on macOS (requires 2.2+, macOS has 2.3+)

  # Use SF Symbol for menu bar icon instead of generic application icon
  patch :p1, <<~DIFF
    --- a/pappl/system-status-macos.m
    +++ b/pappl/system-status-macos.m
    @@ -121,7 +121,8 @@
         [ui->mainMenu addItemWithTitle:[NSString stringWithFormat:@"About %@",ui->name] action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];

         // Set the image for the item...
    -    NSImage *image              = [NSApp.applicationIconImage copy];
    +    NSImage *image = [NSImage imageWithSystemSymbolName:@"printer.fill"
    +                               accessibilityDescription:@"Printer"];
         image.size                  = ui->statusItem.button.frame.size;
         ui->statusItem.button.image = image;
  DIFF

  def install
    system "./configure", *std_configure_args
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <pappl/pappl.h>
      int main() {
        return 0;
      }
    C
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lpappl", "-o", "test"
    system "./test"
  end
end
