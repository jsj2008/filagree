UNAME := $(shell uname -s)

CC=gcc
DBGFLAG=#-DDEBUG
CFLAGS=-Wall -Os -std=gnu99 -I -fPIC -fms-extensions -DFG_MAIN -DNO_UI $(DBGFLAG)
LDFLAGS=-lm -lpthread
LD_LIBRARY_PATH=.
SOURCES=vm.c struct.c serial.c compile.c util.c sys.c variable.c interpret.c node.c file.c
OBJECTS=$(SOURCES:.c=.o)
FRAMEWORKS=-framework Cocoa -framework OpenGL -framework OpenAL

all: $(OBJECTS) hal_osx.o
	$(CC) $(OBJECTS) hal_osx.o $(FRAMEWORKS) -o filagree $(LDFLAGS)
	strip filagree

.c.o:
	$(CC) -c $(CFLAGS) $< -o $@

.m.o:
	$(CC) -c $(CFLAGS) $< -o $@

Javagree.class: Javagree.java
	javac Javagree.java

javagree: $(OBJECTS) Javagree.class hal_stub.o
	javah -jni Javagree
	cc -c -fPIC $(DBGFLAG) -I/System/Library/Frameworks/JavaVM.framework/Headers javagree.c -o libjavagree.o
	libtool -dynamic -lSystem $(OBJECTS) hal_stub.o libjavagree.o -o libjavagree.dylib -macosx_version_min 10.8

clean:
	rm -f *.o *.class *.dylib filagree javagree
