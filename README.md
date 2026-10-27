# Simple Odin Data Analysis (SODA)

## Description
SODA is a simple, minimal, data analysis library written in the Odin
programming language. The library is heavily influenced by
[Pandas](https://pandas.pydata.org/) and hopes to provide a similar API
experience in a statically compiled language. The tool is not meant to be a one
to one Pandas replacement. It is primarily a means of learning the Odin
programming language and providing an simple Pandas alternative for a
statically compiled language.

## Features
SODA handles:
- [X] String, int, and f64 data types
- [X] Columns and DataFrames slices
- [X] reading and writing csv files.
- [X] reading and writing parquet files.
- [ ] Drawing scatter plots.
- [ ] Drawing histograms.


## Dependencies
Parquet reading and writing requires
[carquet](https://github.com/Vitruves/carquet). This repository contains a
statically compiled copy of that library for Linux. If you want to use this
library on Windows or MacOs systems you will need to compile carquet on your
system and updated the carqet bindings.
