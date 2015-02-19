.PHONY : all help

all:  socket_ext.so

CFLAGS += -O2
LDFLAGS += -llua5.1

ifdef JIT
	CFLAGS += -I $(LUAJIT_HOME)/include
	LDFLAGS += -L $(LUAJIT_HOME)/lib
else
	CFLAGS += -I /usr/include/lua5.1/
	LDFLAGS += -L /usr/lib/i386-linux-gnu/
endif


OBJS = socket_ext.o

help:
	@echo make [JIT=yes] [help]

clean:
	rm -f *.o *.dll *.so ../*.so

socket_ext.so: $(OBJS)
	$(CC) -o socket_ext.so -shared  $(OBJS) $(LDFLAGS)
	cp socket_ext.so ../

%.o: %.c socket_poll.h socket_epoll.h
	$(CC) $(CFLAGS) -c -o $@ $<
