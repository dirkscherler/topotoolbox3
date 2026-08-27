cmake_minimum_required(VERSION 3.22)

project(
  mxtopotoolbox
  VERSION 0.0.1
  LANGUAGES C
)

set(MATLAB_ADDITIONAL_VERSIONS
  "R2026a=26.1"
  "R2025b=25.2"
  "R2025a=25.1"
  "R2024b=24.2"
  "R2024a=24.1"
  "R2023b=23.2"
)

set(MATLAB_FIND_DEBUG TRUE)
find_package(Matlab)

include(FetchContent)
FetchContent_Declare(
  topotoolbox
  GIT_REPOSITORY https://github.com/TopoToolbox/libtopotoolbox.git
  GIT_TAG 73d67c4deb8b547f6f26f84fe233d5b16a65ac13
)
FetchContent_MakeAvailable(topotoolbox)

set(TT_MEX_TARGETS
  tt_has_topotoolbox
  tt_fillsinks
  tt_identifyflats
  tt_gwdt_computecosts
  tt_gwdt
  tt_flow_routing_d8_carve
  tt_lowerenv
  tt_hillshade
  tt_hillshade_fused
  tt_graphflood
  tt_gradient8
  tt_excesstopography_fmm2d
  tt_excesstopography_fmm3d
  tt_excesstopography_fsm2d
  tt_streamquad_trapz_f32
  tt_streamquad_trapz_f64
  tt_traverse_down_f32_add_mul
  tt_traverse_down_f64_add_mul
  tt_traverse_down_u8_or_and
  tt_traverse_up_u8_or_and
)

foreach(TT_MEX_TARGET IN LISTS TT_MEX_TARGETS)
  matlab_add_mex(
    NAME ${TT_MEX_TARGET}
    MODULE
    SRC ${TT_MEX_TARGET}.c
    R2018a
    LINK_TO topotoolbox
    NO_IMPLICIT_LINK_TO_MATLAB_LIBRARIES
  )
  # NOTE(wkearn): We have to link the MATLAB libraries ourselves for
  # now.
  #
  # 1. If we implicitly link to the MATLAB libraries, macos looks in
  #    the wrong place for the libMatlabEngine.dylib and fails to load
  #    it. Since we don't use the MATLAB C++ Engine, we can get away
  #    with
  #
  # 2. If we instead use the Matlab::mex and Matlab::mx targets, Linux
  #    will hardcode the paths to the shared libraries. This will fail
  #    when moved to a different machine.
  #
  # The solution is to use the Matlab_MEX_LIBRARY and
  # Matlab_MX_LIBRARY variables provided by FindMatlab. This is what
  # matlab_add_mex does itself and seems to work.
  target_link_libraries(${TT_MEX_TARGET} ${Matlab_MEX_LIBRARY} ${Matlab_MX_LIBRARY})
  if(APPLE)
    target_link_options(${TT_MEX_TARGET} PRIVATE -ld_classic)
  endif()
endforeach()

install(
  TARGETS ${TT_MEX_TARGETS}
  DESTINATION "."
  COMPONENT Runtime
)
