class PapplRetrofit < Formula
  desc "Library for retro-fitting classic CUPS drivers into Printer Applications"
  homepage "https://github.com/OpenPrinting/pappl-retrofit"
  url "https://github.com/OpenPrinting/pappl-retrofit.git",
      revision: "b587478feafd9b51cda54dee65a567cc0437bea4"
  version "1.0b2-20251023"
  license "Apache-2.0"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "gettext" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "shawnz/printing/libcupsfilters"
  depends_on "shawnz/printing/libppd"
  depends_on "shawnz/printing/pappl"

  # macOS does not have reallocarray
  patch :p1, <<~DIFF
    --- a/pappl-retrofit/pappl-retrofit.c
    +++ b/pappl-retrofit/pappl-retrofit.c
    @@ -22,6 +22,15 @@
     #include <pappl-retrofit/pappl-retrofit-private.h>
     #include <pappl-retrofit/libcups2-private.h>

    +#ifdef __APPLE__
    +#include <stdint.h>
    +#include <errno.h>
    +static inline void *reallocarray(void *ptr, size_t nmemb, size_t size) {
    +  if (size && nmemb > SIZE_MAX / size) { errno = ENOMEM; return NULL; }
    +  return realloc(ptr, nmemb * size);
    +}
    +#endif
    +

     //
     // 'prGetSystem() - Accessor function for the "system" entry in the in
  DIFF

  # Heap allocate backend arrays (too large for macOS 512KB thread stack)
  patch :p1, <<~'DIFF'
    --- a/pappl-retrofit/cups-backends.c
    +++ b/pappl-retrofit/cups-backends.c
    @@ -225,10 +225,8 @@ _prCUPSDevList(pappl_device_cb_t cb,
     				// Total backends
     		active_backends = 0;
     				// Active backends
    -  pr_backend_t  backends[MAX_BACKENDS];
    -				// Array of backends
    -  struct pollfd	backend_fds[MAX_BACKENDS];
    -  				// Array for poll()
    +  pr_backend_t  *backends = NULL;
    +  struct pollfd *backend_fds = NULL;
       cups_array_t	*devices = NULL;// Array of devices
       int		i;		// Looping var
       struct sigaction action;	// Actions for POSIX signals
    @@ -267,8 +265,15 @@ _prCUPSDevList(pappl_device_cb_t cb,
       filter_data.logfunc = _prCUPSDevLog;
       filter_data.logdata = &devlog_data;

    +  backends = calloc(MAX_BACKENDS, sizeof(pr_backend_t));
    +  backend_fds = calloc(MAX_BACKENDS, sizeof(struct pollfd));
    +  if (!backends || !backend_fds)
    +  {
    +    free(backends);
    +    free(backend_fds);
    +    return false;
    +  }
       // Initialize backends list and link with global data
    -  memset(backends, 0, sizeof(backends));
       global_data->backend_list = backends;

       // Listen to child signals to get note of backends which have finished or
    @@ -722,6 +727,8 @@ _prCUPSDevList(pappl_device_cb_t cb,
         free(backends[i].name);
       if (devices)
         cupsArrayDelete(devices);
    +  free(backends);
    +  free(backend_fds);

       return (ret);
     }
  DIFF

  # Two Makefile.am fixes (both masked in Snap because /usr/include is in the
  # default compiler search path, but Homebrew's /opt/homebrew/include is not):
  # 1. Header install path doesn't match what pkg-config advertises
  # 2. PAPPL_CFLAGS missing from legacy_printer_app (needs pappl headers)
  patch :p1, <<~DIFF
    --- a/Makefile.am
    +++ b/Makefile.am
    @@ -22,7 +22,7 @@
     # ==================================
     # CUPS Driver legacy support library
     # ==================================
    -pkgpappl_retrofitincludedir = $(includedir)
    +pkgpappl_retrofitincludedir = $(includedir)/pappl-retrofit
     pkgpappl_retrofitinclude_DATA = \\
     	pappl-retrofit/pappl-retrofit.h

    @@ -80,6 +80,7 @@
     	$(CUPS_CFLAGS) \\
     	$(CUPSFILTERS_CFLAGS) \\
     	$(PPD_CFLAGS) \\
    +	$(PAPPL_CFLAGS) \\
     	-I$(srcdir)/pappl-retrofit/
  DIFF

  def install
    system "autoreconf", "-fiv"
    system "./configure", *std_configure_args
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <pappl-retrofit.h>
      int main() {
        return 0;
      }
    C
    flags = shell_output("pkg-config --cflags --libs libpappl-retrofit").chomp.split
    system ENV.cc, "test.c", *flags, "-o", "test"
    system "./test"
  end
end
