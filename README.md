# libCEED.jl: Julia Interface for libCEED

This package provides both a low-level and high-level interface for libCEED.

## Low-Level Interface

The low-level interface (provided in the `libCEED.C` module) is in one-to-one
correspondence with the C libCEED iterface, and is automatically generated (with
some minor manual modifications) using the Julia package Clang.jl. The script
used to generate bindings is available in `generate_bindings.jl`.

With the low-level interface, the user is responsible for freeing all allocated
memory (calling the appropriate `Ceed*Destroy` functions). This interface is
not type-safe, and calling functions with the wrong arguments can cause libCEED
to crash.

## High-Level Interface

The high-level interface provides a more idiomatic Julia interface to the
libCEED library. Objects allocated using the high-level interface will
automatically be destroyed by the garbage collector, so they use does not need
to manually manage memory.

### Defining user Q-Functions in Julia

libCEED.jl provides the macro `@user_qfunction` to help define user Q-Functions
in Julia. The purpose of the macro is to automate both the extraction of the
"context" struct using the correct type, and the extraction of the input and
output arrays, with the correct dimensions (also allowing for multidimensional
arrays).

Take for example the "build mass" Q-Function, which could be defined
in C by:
```c
CEED_QFUNCTION(f_build_mass)(void *ctx, const CeedInt Q,
                             const CeedScalar *const *in, CeedScalar *const *out) {
  // in[0] is Jacobians with shape [dim, nc=dim, Q]
  // in[1] is quadrature weights, size (Q)
  struct BuildContext *bc = (struct BuildContext *)ctx;
  const CeedScalar *J = in[0], *w = in[1];
  CeedScalar *qdata = out[0];

  switch (bc->dim + 10*bc->space_dim) {
  case 11:
    for (CeedInt i=0; i<Q; i++) {
      qdata[i] = J[i] * w[i];
    }
    break;
  case 22:
    for (CeedInt i=0; i<Q; i++) {
      qdata[i] = (J[i+Q*0]*J[i+Q*3] - J[i+Q*1]*J[i+Q*2]) * w[i];
    }
    break;
  case 33:
    for (CeedInt i=0; i<Q; i++) {
      qdata[i] = (J[i+Q*0]*(J[i+Q*4]*J[i+Q*8] - J[i+Q*5]*J[i+Q*7]) -
                  J[i+Q*1]*(J[i+Q*3]*J[i+Q*8] - J[i+Q*5]*J[i+Q*6]) +
                  J[i+Q*2]*(J[i+Q*3]*J[i+Q*7] - J[i+Q*4]*J[i+Q*6])) * w[i];
    }
    break;
  }
  return 0;
}
```
Notice that there is a certain amount of boilerplate that is required to exact
the `BuildContext` struct (casting the `ctx` pointer), and extracting the input
arrays (`J` and `w`) and output array (`qdata`). Additionally, the arrays are
interpreted as one-dimensional arrays, even though the `J` array represents a
3-tensor.

Using the `@user_qfunction` macro, this same Q-Function can be implemented as
```julia
@user_qfunction(
function f_build_mass(ctx::BuildContext, Q,
                      J::(:in, Q, ctx.dim, ctx.dim), w::(:in, Q),
                      qdata::(:out, Q))
    if ctx.dim == 1
        for i=1:Q
            qdata[i] = J[i]*w[i]
        end
    elseif ctx.dim == 2
        for i=1:Q
            qdata[i] = (J[i,1,1]*J[i,2,2] - J[i,2,1]*J[i,1,2])*w[i];
        end
    elseif ctx.dim == 3
        for i=1:Q
            qdata[i] = (J[i,1,1]*(J[i,2,2]*J[i,3,3] - J[i,3,2]*J[i,2,3]) -
                        J[i,2,1]*(J[i,1,2]*J[i,3,3] - J[i,3,2]*J[i,1,3]) +
                        J[i,3,1]*(J[i,1,2]*J[i,2,3] - J[i,2,2]*J[i,1,3]))*w[i]
        end
    end
    return CeedInt(0)
end)
```
In this example, the context struct is automatically extracted using the type
information provided in the argument list. If the user does not need (or has
not provided) a context struct to the Q-Function, it can be ignored by making
the first argument anonymous (e.g. `::Nothing`).

Additionally, the input and output arguments are listed using a specification
that includes their dimensions. For example, the `J` array appears in the
argument list as `J::(:in, Q, ctx.dim, ctx.dim)`. The tuple
`(:in, Q, ctx.dim, ctx.dim)` is the argument specification, that takes the form
`([:in,:out], dims...)`. The dimensions can reference both the context struct
`ctx` and the number of quadrature points `Q`.

The macro `@user_qfunction` parses the argument list, and automatically
generates the required boilerplate code at the beginning of the function body.
Additionally, `@user_qfunction` automatically calls `@cfunction` to generate a
function pointer that can be used as a C callback function, and binds the result
to a variable of the name of the function. In this example, `f_build_mass` would
be equal to a function pointer that can be passed directly to libCEED.
