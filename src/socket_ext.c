#include <stdio.h>
#include <string.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <stdbool.h>
#include <unistd.h>
#include "socket_poll.h"

static void *auxiliar_getgroupudata(lua_State *L, const char *groupname, int objidx);
static int meth_select_ev(lua_State *L)
{
	int tbl;
	lua_newtable(L);
	tbl=lua_gettop(L);
	int i;

	for (i=1; i <=10; i++)
	{
		lua_pushnumber(L,i*2);
		lua_rawseti(L, tbl, i);
	}
	
	return 1;
}

// lua usage: wait_ev(poller_fd, timeout):socket[]
static int method_wait_ev(lua_State *L)
{
	poll_fd efd = luaL_checkint (L,1);
	lua_Number _timeout = luaL_checknumber (L,2);
	int timeout = (_timeout >= 0) ? 1000000*_timeout: -1;
	struct event ev[1024];
	int nevent = sp_wait(efd, ev, sizeof(ev)/sizeof(struct event), timeout);
	int readt, sendt;
	int ireadt=1, isendt=1, i;

	lua_newtable(L);
	readt = lua_gettop(L);
	lua_newtable(L);
	sendt = lua_gettop(L);
	for (i=0; i < nevent; i++) {
		if (ev[i].read) {
			//lua_pushlightuserdata(L, ev[i].s);
			lua_pushinteger(L, ev[i].fd);
			//printf("fd=%d, %p\n", ev[i].fd, ev[i].s);
			lua_rawseti(L, readt, ireadt++);
		} else if (ev[i].write) {
			//lua_pushlightuserdata(L, ev[i].s);
			lua_pushinteger(L, ev[i].fd);
			lua_rawseti(L, sendt, isendt++);
		}
	}
	if (nevent==0)
		lua_pushlstring(L, "timeout", 7);
	else
		lua_pushnil(L);

	return 3;
}

static int method_create_poller(lua_State *L)
{
	poll_fd fd = sp_create();
	lua_pushinteger(L, fd);
	return 1;
}

static int method_release_poller(lua_State *L)
{
	poll_fd fd = luaL_checkint (L,1);
	sp_release(fd);
	lua_pushboolean(L, 1);
	return 1;
}

// lua usage: register_fd(efd, sfd, udata, is_writable)
static int method_register_fd(lua_State *L)
{
	poll_fd efd = luaL_checkint (L, 1);
	int s = luaL_checkint (L, 2);
	void *udata = auxiliar_getgroupudata (L, "tcp{any}", 3);
	udata = NULL;
	int is_writable = lua_toboolean(L, 4);
	sp_nonblocking(s);
	sp_add(efd, s, udata);
	sp_write(efd, s, udata, is_writable);
	lua_pushboolean(L, 1);
	return 1;
}

static int method_unregister_fd(lua_State *L)
{
	poll_fd fd = luaL_checkint (L, 1);
	int s = luaL_checkint (L, 2);
	sp_del(fd, s);
	lua_pushboolean(L, 1);
	return 1;
}

static void *
auxiliar_getgroupudata(lua_State *L, const char *groupname, int objidx) 
{
    if (!lua_getmetatable(L, objidx))
        return NULL;
    lua_pushstring(L, groupname);
    lua_rawget(L, -2);
    if (lua_isnil(L, -1)) {
        lua_pop(L, 2);
        return NULL;
    } else {
        lua_pop(L, 2);
        return lua_touserdata(L, objidx);
    }
}

static int method_test(lua_State *L)
{
	void *udata = auxiliar_getgroupudata (L, "tcp{any}", 1);
	
	printf("%p\n", udata);
	lua_pushlightuserdata(L, udata);
	return 1;

}

static const luaL_reg socket_ext_reg[] = {
	{"create_poller",	method_create_poller},
	{"release_poller",	method_release_poller},
	{"register_fd",   	method_register_fd},
	{"unregister_fd",   method_unregister_fd},
    {"wait_ev",   		method_wait_ev},
    {"test",			method_test},
    {NULL, NULL}
};

//LUALIB_API 
int luaopen_socket_ext (lua_State *L)
{
    luaL_register(L, "select_epoll", socket_ext_reg);
    return 1;
}


