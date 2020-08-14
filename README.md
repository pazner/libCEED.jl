# libCEED.jl: Julia Interface for libCEED

This package provides both a low-level and high-level interface for libCEED.


## Low-Level Interface

The low-level interface (provided in the `libCEED.C` module) is in one-to-one
correspondence with the C libCEED iterface, and is automatically generated (with
some minor manual modifications) using the Julia package Clang.jl. The script
used to generate bindings is available in `generate_bindings.jl`.

With the low-level interface, the user is responsible for freeing all allocated
memory (calling the appropriate `Ceed*Destroy` functions).

## High-Level Interface

The high-level interface provides a more idiomatic Julia interface to the
libCEED library. Objects allocated using the high-level interface will
automatically be destroyed by the garbage collector, so they use does not need
to manually manage memory.
