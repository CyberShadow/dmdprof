import gdb
from collections import defaultdict
import time
import os
import os.path
import signal
from threading import Thread
import json
import re


def dmdprof_get_loc(val):
    if (val.type.code == gdb.TYPE_CODE_PTR
        and val.type.target().name is not None
        and val.type.target().name != "void"
    ):
        return dmdprof_get_loc(val.referenced_value())
    if val.type.name is None:
        return None

    # Modules
    try:
        fn = val["srcfile"]["name"]["str"].string()
        return (fn, 0, 0)
    except:
        pass

    # Symbols, statements, declarations, and expressions
    try:
        loc = val["loc"]
        return (loc["filename"].string("utf-8"), int(loc["linnum"]), int(loc["charnum"]))
    except:
        pass

    return None


def dmdprof_get_stack():
    oldloc = ()
    stack = []
    frame = gdb.newest_frame()
    while frame:
        block = frame.block()
        while block:
            if not block.is_global:
                for symbol in block:
                    if symbol.is_argument:
                        loc = dmdprof_get_loc(symbol.value(frame))
                        if loc is not None and loc != oldloc:
                            stack.append(loc)
                            oldloc = loc
                            break # Consider just the first argument with a Loc
            block = block.superblock
        frame = frame.older()
    return tuple(stack)


def dmdprof_print_stack():
    stack = dmdprof_get_stack()
    for loc in stack:
        (filename, line, char) = loc
        locstr = "{}({},{})".format(filename, line, char)
        if line > 0 and os.path.exists(filename):
            linestr = open(filename).readlines()[line-1]
            locstr += ": " + linestr.rstrip('\n')
        print(locstr)


class Executor:
    def __init__(self, cmd):
        self.__cmd = cmd

    def __call__(self):
        gdb.execute(self.__cmd)


class DMDProfiler:
    def __init__(self,
                 period = 0.01,
                 output_filename = "profile.json",
                 quit_on_exit = False):
        self.period = period
        self.output_filename = output_filename
        self.quit_on_exit = quit_on_exit

    def stop_func(self):
        try:
            os.kill(self.pid, signal.SIGINT)
        except ProcessLookupError:
            pass

    def threaded_function(self):
        time.sleep(self.period)
        # gdb.post_event(Executor("interrupt"))
        gdb.post_event(self.stop_func)

    def stop_handler(self, event):
        try:
            self.callchains.append(dmdprof_get_stack())
        except RuntimeError:
            pass

        gdb.post_event(Executor("continue"))

    def cont_handler(self, event):
        (Thread(target = self.threaded_function)).start()

    def exit_handler(self, event):
        gdb.events.cont.disconnect(self.cont_handler)
        gdb.events.stop.disconnect(self.stop_handler)
        gdb.events.exited.disconnect(self.exit_handler)

        print("\nProfiling complete with %d samples." % len(self.callchains))
        self.save_results()
        if self.quit_on_exit:
            gdb.execute("quit")

    def save_results(self):
        """Save results as gprof2dot JSON format."""

        res = {"version":0, "functions":[], "events":[]}
        functions = {}

        for callchain in self.callchains:
            if len(callchain) == 0:
                continue

            funcs = []
            for line in callchain:
                if line in functions:
                    fun_id = functions[line]
                else:
                    fun_id = len(functions)
                    functions[line] = fun_id
                    res["functions"].append({
                        # We don't know the actual function name, so
                        # abuse the module field for some hierarchy
                        "module" : line[0],
                        # "module" : self.abbreviate_file_name(line[0]),
                        "name" : str(line[1]) + ":" + str(line[2])
                    })
                funcs.append(fun_id)

            res["events"].append({
                "callchain" : funcs,
                "cost" : [self.period]
            })
        json.dump(res, open(self.output_filename, 'w'))
        print(self.output_filename + " written.")

    # def abbreviate_file_name(self, fn):
    #     fn = re.sub(r".*/phobos/", "", fn)
    #     fn = re.sub(r".*/druntime/import/", "", fn)
    #     return fn

    def profile(self):
        gdb.execute("set pagination off")
        gdb.execute("start")

        self.pid = gdb.selected_inferior().pid
        self.callchains = []

        gdb.events.cont.connect(self.cont_handler)
        gdb.events.stop.connect(self.stop_handler)
        gdb.events.exited.connect(self.exit_handler)
        gdb.post_event(Executor("continue"))
