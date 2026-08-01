# Simple Odin Data Analysis (SODA)

## Description
SODA is a simple, minimal, data analysis tool in the Odin language. The tool is
heavily influenced by Pandas and hopes to provide a similar api experience in a
statically compiled language. The tool is not meant for production usage, it
does not intend to be a one to one replacement for Pandas. It is primarily a
tool to help learn the Odin language and provide some support for data analysis
in Odin when ever I get tired of Python.

## Features
SODA handles:
- String, int, and f64 data types
- slicing of both columns and dataframes
- complex computation interface

## Feature Roadmap
There is a "shortlist" of features I'd like to add to the library. The features
include the ability to handle dates, missing data, and compressed data formats
--like parquet. There maybe more, but these are the most pressing.  There is no
timeline for feature implementation, but I expect to "need" them in the short
term. So they may come sooner than later. Below is a more complete list of
features I expect to add.

- [ ] date types
- [ ] i32 and f32 types
- [ ] 3D vector types i.e. `[3]f32`
- [ ] query parser
- [ ] write csv file
- [-] read parquet file
- [ ] handle missing data
- [ ] plotting interface (currently the plotting interface is sketch out in
  code, but has been lightly used)
- [ ] plotting backend. (currently the default plotting backend is plplot and
  I'm not sure if this is the backend the package will go with in the future.
- [ ] the ability to share state between executables. Analyzing data in python
  is "nice" primarily because Python is interpreted and state is maintained,
  naturally, between statements. This allows users explore and tweak algorithms
  without needing to reload or reconstruct state.
- [ ] simd optimizations
- [ ] ...
