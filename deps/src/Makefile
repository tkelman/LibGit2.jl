all: check-env default

ifeq (exists, $(shell [ -e Make.user ] && echo exists ))
include Make.user
endif

.PHONY: all clean check-env default

check-env:
ifndef JULIA_ROOT
        $(error Environment variable JULIA_ROOT is not set.)
endif

INC = -I"$(JULIA_ROOT)/usr/include"
FLAGS = -Wall -Wno-strict-aliasing -fno-omit-frame-pointer -fPIC
LIBS =

OBJS = wraplibgit.c.o
LIBS += -lgit2

# Figure out OS and architecture
OS = $(shell uname)
ifeq ($(OS), MINGW32_NT-6.1)
  OS=WINNT
endif

# file extensions
ifeq ($(OS), WINNT)
  SHLIB_EXT = dll
else ifeq ($(OS), Darwin)
  SHLIB_EXT = dylib
else
  SHLIB_EXT = so
endif

default: libwrapgit.$(SHLIB_EXT)

%.c.o: %.c
	$(CC) $< -fPIC -c -o $@ $(INC) $(CFLAGS) $(FLAGS)

libwrapgit.$(SHLIB_EXT): $(OBJS)
	$(CC) $(OBJS) -rdynamic -shared -o $@ -L"$(JULIA_ROOT)/usr/lib" $(LDFLAGS) $(LIBS)

clean:
	rm -f *.o *.$(SHLIB_EXT)
