// Test-process wall clock only. Not compiled into or loaded by the application.
#define _GNU_SOURCE
#include <sys/time.h>
#include <dlfcn.h>
#include <stdlib.h>
int gettimeofday(struct timeval *value, void *zone) {
  const char *epoch = getenv("PORTAL_VISUAL_CLOCK_EPOCH");
  if (epoch && value) {
    value->tv_sec = (time_t)strtoll(epoch, 0, 10);
    value->tv_usec = 0;
    return 0;
  }
  int (*original)(struct timeval *, void *) = dlsym(RTLD_NEXT, "gettimeofday");
  return original(value, zone);
}
