dmdprof
=======

This is a DMD compilation time profiler.
It allows profiling and visualizing which parts of the D code take up most of the time compiling.

Example
=======

![](https://dump.thecybershadow.net/3940d9ef43e958cb04dfa441f4af93b2/profile.svg)

Click image above for working tooltips and hyperlinks.

Example taken [from here](https://github.com/dlang/phobos/pull/5916#issuecomment-362896993).

Usage
=====

1. Build a debug DMD, e.g. using `make -f posix.mak BUILD=debug` in [dmd](https://github.com/dlang/dmd)/src.

2. Run the debug DMD you built under GDB, and pass the program to compile and profile:

       $ gdb --args .../dmd/generated/linux/debug/64/dmd -o- your_program.d

   If you use a build tool like rdmd or Dub, you need to first find the dmd invocation it uses, then use that. Try enabling verbose output.

3. Load the `dmdprof.py` GDB script from this repository:

       (gdb) source path/to/dmdprof.py

4. Run the profiler:

       (gdb) python DMDProfiler().profile()

   You can optionally specify a sampling interval:

       (gdb) python DMDProfiler(0.001).profile()

   The sampling interval specifies the duration (in seconds) between samples taken. The default is 0.01, and the lowest possible value is 0, meaning to take samples as quickly as possible.

   Note that currently GDB leaks about 15-30 MB of memory per sample (!), so watch your memory usage to avoid crashing your machine.

   The profiler will save the results to a `profile.json` file.

5. Use [gprof2dot](https://github.com/jrfonseca/gprof2dot/) to generate a GraphViz .dot file, pipe it through the `linkify` program in this repository, and pipe the result into `dot`:

       ./gprof2dot.py -f json path/to/profile.json -n 2 -e 2 | rdmd path/to/linkify.d | dot -Tsvg > profile.svg

   Adjust gprof2dot `-n` and `-e` parameters to taste.

   To generate correct, permanent links in the output file, you can specify Phobos and Druntime versions as Git commit SHA1s or tag names using the `--phobos` and `--druntime` arguments to `linkify`.
