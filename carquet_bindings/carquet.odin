/**
 * @file carquet.h
 * @brief Carquet - High-Performance Pure C Parquet Library
 * @version 0.6.0
 *
 * @copyright Copyright (c) 2025. All rights reserved.
 * @license MIT License
 *
 * Carquet is a minimal-dependency pure C11 library for reading
 * and writing Apache Parquet files. It features automatic SIMD optimization
 * for maximum performance across x86-64 (SSE4.2, AVX2, AVX-512) and ARM
 * (NEON, SVE) architectures.
 *
 * @section features Key Features
 *
 * - **Minimal Dependencies**: Pure C11 with optional zstd/zlib for compression
 * - **SIMD Optimized**: Automatic CPU feature detection and optimal code dispatch
 * - **Complete Parquet Support**: All physical types, encodings, and compression codecs
 * - **Production Ready**: CRC32 verification, statistics, predicate pushdown
 * - **Memory Efficient**: Streaming API, column projection, memory-mapped I/O
 * - **Thread Safe**: Concurrent reads supported, atomic initialization
 *
 * @section quickstart Quick Start
 *
 * @subsection reading Reading a Parquet File
 * @code{.c}
 * #include <carquet/carquet.h>
 *
 * carquet_error_t err = CARQUET_ERROR_INIT;
 *
 * // Open file
 * carquet_reader_t* reader = carquet_reader_open("data.parquet", NULL, &err);
 * if (!reader) {
 *     fprintf(stderr, "Error: %s\n", err.message);
 *     return 1;
 * }
 *
 * // Get metadata
 * int64_t num_rows = carquet_reader_num_rows(reader);
 * int32_t num_cols = carquet_reader_num_columns(reader);
 *
 * // Read column data using batch reader
 * carquet_batch_reader_config_t config;
 * carquet_batch_reader_config_init(&config);
 * config.batch_size = 10000;
 *
 * carquet_batch_reader_t* batch_reader = carquet_batch_reader_create(reader, &config, &err);
 * carquet_row_batch_t* batch = NULL;
 *
 * while (carquet_batch_reader_next(batch_reader, &batch) == CARQUET_OK && batch) {
 *     const void* data;
 *     const uint8_t* nulls;
 *     int64_t count;
 *     carquet_row_batch_column(batch, 0, &data, &nulls, &count);
 *     // Process data...
 *     carquet_row_batch_free(batch);
 *     batch = NULL;
 * }
 *
 * carquet_batch_reader_free(batch_reader);
 * carquet_reader_close(reader);
 * @endcode
 *
 * @subsection writing Writing a Parquet File
 * @code{.c}
 * #include <carquet/carquet.h>
 *
 * carquet_error_t err = CARQUET_ERROR_INIT;
 *
 * // Create schema
 * carquet_schema_t* schema = carquet_schema_create(&err);
 * carquet_schema_add_column(schema, "id", CARQUET_PHYSICAL_INT64,
 *                           NULL, CARQUET_REPETITION_REQUIRED, 0);
 * carquet_schema_add_column(schema, "value", CARQUET_PHYSICAL_DOUBLE,
 *                           NULL, CARQUET_REPETITION_REQUIRED, 0);
 *
 * // Create writer with compression
 * carquet_writer_options_t opts;
 * carquet_writer_options_init(&opts);
 * opts.compression = CARQUET_COMPRESSION_ZSTD;
 *
 * carquet_writer_t* writer = carquet_writer_create("output.parquet", schema, &opts, &err);
 *
 * // Write data
 * int64_t ids[] = {1, 2, 3, 4, 5};
 * double values[] = {1.1, 2.2, 3.3, 4.4, 5.5};
 *
 * carquet_writer_write_batch(writer, 0, ids, 5, NULL, NULL);
 * carquet_writer_write_batch(writer, 1, values, 5, NULL, NULL);
 *
 * carquet_writer_close(writer);
 * carquet_schema_free(schema);
 * @endcode
 *
 * @section threading Thread Safety
 *
 * - Library initialization (carquet_init) is thread-safe and uses atomic operations
 * - Multiple readers can read the same file concurrently
 * - A single reader/writer instance must not be shared across threads without synchronization
 * - Schema objects are immutable after creation and can be shared
 *
 * @section memory Memory Management
 *
 * - All returned pointers remain valid until their parent object is freed
 * - Batch data pointers are valid only until the next
 *   carquet_batch_reader_next() call on the same reader, or until the
 *   batch reader is freed (whichever comes first). Batch buffers are
 *   pooled and reused; copy any data you need to retain across batches.
 * - Schema pointers from readers are valid until the reader is closed
 * - Use carquet_set_allocator() to provide custom memory allocation
 *
 * @see https://parquet.apache.org/docs/ Apache Parquet Documentation
 * @see https://github.com/apache/parquet-format Parquet Format Specification
 */
package carquet_bindings
// NOTE: These are all linux requirements. If you wish to run on windows this
// must be updated.
foreign import carquet {
	"libcarquet.a",
	"system:zstd",
	"system:lz4",
	"system:z",
	"system:m",
	"system:gomp",
	"system:pthread",
}

import "core:c"
import "core:os"

FILE :: os.File

/* ============================================================================
* Version Information
* ============================================================================
*
* Carquet follows Semantic Versioning (https://semver.org/).
*
* - MAJOR: Incompatible API changes
* - MINOR: Backwards-compatible functionality additions
* - PATCH: Backwards-compatible bug fixes
*/

/** @brief Major version number */
CARQUET_VERSION_MAJOR :: 0

/** @brief Minor version number */
CARQUET_VERSION_MINOR :: 7

/** @brief Patch version number */
CARQUET_VERSION_PATCH :: 0

/** @brief Version string in "MAJOR.MINOR.PATCH" format */
CARQUET_VERSION_STRING :: "0.7.0"

/** @brief Numeric version for compile-time comparisons: (MAJOR * 10000 + MINOR * 100 + PATCH) */
CARQUET_VERSION_NUMBER :: (CARQUET_VERSION_MAJOR*10000+CARQUET_VERSION_MINOR*100+CARQUET_VERSION_PATCH)

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Get the library version as a string.
	*
	* Returns the version string in "MAJOR.MINOR.PATCH" format.
	* This is useful for runtime version checking and logging.
	*
	* @return Version string (statically allocated, never NULL)
	*
	* @note Thread-safe: Yes
	*
	* @code{.c}
	* printf("Using Carquet version %s\n", carquet_version());
	* @endcode
	*/
	carquet_version :: proc() -> cstring ---

	/**
	* @brief Get individual version components.
	*
	* Retrieves the major, minor, and patch version numbers separately.
	* Useful for runtime compatibility checks.
	*
	* @param[out] major Major version number (may be NULL)
	* @param[out] minor Minor version number (may be NULL)
	* @param[out] patch Patch version number (may be NULL)
	*
	* @note Thread-safe: Yes
	*
	* @code{.c}
	* int major, minor, patch;
	* carquet_version_components(&major, &minor, &patch);
	* if (major != CARQUET_VERSION_MAJOR) {
	*     fprintf(stderr, "Warning: Header/library version mismatch\n");
	* }
	* @endcode
	*/
	carquet_version_components :: proc(major: ^i32, minor: ^i32, patch: ^i32) ---

	/**
	* @brief Initialize the Carquet library.
	*
	* Performs CPU feature detection and sets up optimal SIMD dispatch tables.
	* This function is automatically called on first use of any Carquet function,
	* but can be called explicitly for deterministic initialization timing.
	*
	* Calling this function multiple times is safe and has no effect after the
	* first successful initialization.
	*
	* @return CARQUET_OK on success, error code on failure
	*
	* @note Thread-safe: Yes (uses atomic initialization)
	* @note Idempotent: Yes (safe to call multiple times)
	*
	* @code{.c}
	* // Optional: explicit initialization at program start
	* carquet_status_t status = carquet_init();
	* if (status != CARQUET_OK) {
	*     fprintf(stderr, "Failed to initialize Carquet: %s\n",
	*             carquet_status_string(status));
	*     return 1;
	* }
	* @endcode
	*/
	carquet_init :: proc() -> carquet_status_t ---

	/**
	* @brief Release library-level resources.
	*
	* Frees cached compression contexts held by the calling thread and resets
	* library state.  On POSIX systems with OpenMP, worker-thread contexts are
	* freed automatically when those threads exit; this function handles the
	* main thread and the non-OpenMP (global) case.
	*
	* Safe to call multiple times.  After cleanup, carquet_init() may be called
	* again if the library is needed once more.
	*
	* @note Call from the main thread before program exit for a clean valgrind
	*       report.
	*/
	carquet_cleanup :: proc() ---
}

/**
* @brief CPU feature information detected at runtime.
*
* This structure contains the results of CPU feature detection,
* used to select optimal SIMD implementations.
*/
carquet_cpu_info :: struct {
	/* x86-64 features */
	has_sse2:       bool, /**< SSE2 support (baseline for x86-64) */
	has_sse41:      bool, /**< SSE4.1 support */
	has_sse42:      bool, /**< SSE4.2 support (includes POPCNT, CRC32) */
	has_avx:        bool, /**< AVX support */
	has_avx2:       bool, /**< AVX2 support */
	has_avx512f:    bool, /**< AVX-512 Foundation */
	has_avx512bw:   bool, /**< AVX-512 Byte/Word instructions */
	has_avx512vl:   bool, /**< AVX-512 Vector Length extensions */
	has_avx512vbmi: bool, /**< AVX-512 Vector Byte Manipulation */

	/* ARM features */
	has_neon:          bool, /**< ARM NEON support */
	has_sve:           bool, /**< ARM SVE support */
	sve_vector_length: i32,  /**< SVE vector length in bits (0 if not available) */
}

/**
* @brief CPU feature information detected at runtime.
*
* This structure contains the results of CPU feature detection,
* used to select optimal SIMD implementations.
*/
carquet_cpu_info_t :: carquet_cpu_info

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Get detected CPU features.
	*
	* Returns information about CPU features detected during library initialization.
	* This is useful for diagnostics and understanding which SIMD optimizations
	* are being used.
	*
	* @return Pointer to CPU info structure (statically allocated, never NULL)
	*
	* @note Thread-safe: Yes
	* @note The returned pointer remains valid for the lifetime of the program.
	*
	* @code{.c}
	* const carquet_cpu_info_t* cpu = carquet_get_cpu_info();
	* printf("SIMD features:\n");
	* printf("  AVX2: %s\n", cpu->has_avx2 ? "yes" : "no");
	* printf("  NEON: %s\n", cpu->has_neon ? "yes" : "no");
	* @endcode
	*/
	carquet_get_cpu_info :: proc() -> ^carquet_cpu_info_t ---
}

/**
* @brief Custom memory allocator interface.
*
* Users can provide custom memory allocation functions for all Carquet
* operations. This is useful for:
*
* - Memory tracking and debugging
* - Custom memory pools
* - Integration with game engines or other frameworks
*
* All three function pointers must be provided (non-NULL) when setting
* a custom allocator.
*/
carquet_allocator :: struct {
	/**
	* @brief Allocate memory.
	* @param size Number of bytes to allocate
	* @param ctx User context pointer
	* @return Pointer to allocated memory, or NULL on failure
	*/
	malloc: proc "c" (size: c.size_t, ctx: rawptr) -> rawptr,

	/**
	* @brief Reallocate memory.
	* @param ptr Pointer to existing allocation (may be NULL)
	* @param size New size in bytes
	* @param ctx User context pointer
	* @return Pointer to reallocated memory, or NULL on failure
	*/
	realloc: proc "c" (ptr: rawptr, size: c.size_t, ctx: rawptr) -> rawptr,

	/**
	* @brief Free memory.
	* @param ptr Pointer to free (may be NULL)
	* @param ctx User context pointer
	*/
	free: proc "c" (ptr: rawptr, ctx: rawptr),

	/** @brief User context passed to all allocation functions */
	ctx: rawptr,
}

/**
* @brief Custom memory allocator interface.
*
* Users can provide custom memory allocation functions for all Carquet
* operations. This is useful for:
*
* - Memory tracking and debugging
* - Custom memory pools
* - Integration with game engines or other frameworks
*
* All three function pointers must be provided (non-NULL) when setting
* a custom allocator.
*/
carquet_allocator_t :: carquet_allocator

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Set the global memory allocator.
	*
	* Must be called before any other Carquet function that allocates memory.
	* If not called, the standard C library allocator is used.
	*
	* @param[in] allocator Custom allocator (NULL to reset to default)
	*
	* @warning Not thread-safe. Must be called before any concurrent Carquet usage.
	* @warning All function pointers in the allocator must be non-NULL.
	*
	* @code{.c}
	* carquet_allocator_t my_alloc = {
	*     .malloc = my_malloc,
	*     .realloc = my_realloc,
	*     .free = my_free,
	*     .ctx = my_context
	* };
	* carquet_set_allocator(&my_alloc);
	* @endcode
	*/
	carquet_set_allocator :: proc(allocator: ^carquet_allocator_t) ---

	/**
	* @brief Get the current memory allocator.
	*
	* @return Pointer to current allocator configuration
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_get_allocator :: proc() -> ^carquet_allocator_t ---
}

/**
* @brief Pluggable compress/decompress implementation for one codec slot.
*
* All three function pointers are required; passing a struct with any of them
* NULL to @ref carquet_register_codec returns CARQUET_ERROR_INVALID_ARGUMENT.
* @ref user_data is forwarded back into every callback unchanged and is meant
* for codec-side state (allocator pools, level overrides, etc.).
*/
carquet_custom_codec :: struct {
	/**
	* @brief Compress @p src_size bytes from @p src into @p dst.
	*
	* @p dst is already sized to `compress_bound(src_size, user_data)`.
	* On success, set @p *out_size to the bytes actually written and return
	* `CARQUET_OK`. @p level mirrors `carquet_writer_options_t.compression_level`
	* (0 means "codec default"); the codec is free to ignore it.
	*/
	compress: proc "c" (src: ^u8, src_size: c.size_t, dst: ^u8, dst_capacity: c.size_t, out_size: ^c.size_t, level: i32, user_data: rawptr) -> carquet_status_t,

	/**
	* @brief Decompress @p src_size bytes from @p src into @p dst.
	*
	* @p dst_capacity is the exact uncompressed size declared in the page
	* header; the codec must produce exactly that many bytes or return an
	* error. Set @p *out_size to the bytes written on success.
	*/
	decompress: proc "c" (src: ^u8, src_size: c.size_t, dst: ^u8, dst_capacity: c.size_t, out_size: ^c.size_t, user_data: rawptr) -> carquet_status_t,

	/**
	* @brief Worst-case compressed-output size for @p src_size bytes.
	*
	* The writer allocates this many bytes for the destination buffer before
	* calling @ref compress, so the bound must hold for any input of that
	* size or the writer will fail to compress legitimate pages.
	*/
	compress_bound: proc "c" (src_size: c.size_t, user_data: rawptr) -> c.size_t,

	/** @brief Opaque pointer passed back into every callback. */
	user_data: rawptr,
}

/**
* @brief Pluggable compress/decompress implementation for one codec slot.
*
* All three function pointers are required; passing a struct with any of them
* NULL to @ref carquet_register_codec returns CARQUET_ERROR_INVALID_ARGUMENT.
* @ref user_data is forwarded back into every callback unchanged and is meant
* for codec-side state (allocator pools, level overrides, etc.).
*/
carquet_custom_codec_t :: carquet_custom_codec

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Register or unregister a custom codec implementation.
	*
	* The registered codec takes priority over any built-in implementation for
	* the given codec slot, so this can also be used to swap a built-in for an
	* alternative implementation. Pass @p impl == NULL to clear the slot and
	* restore the built-in (or leave the slot unsupported if no built-in
	* exists). Registering against `CARQUET_COMPRESSION_UNCOMPRESSED` is
	* rejected, since that path has a no-copy fast lane that must not be
	* intercepted.
	*
	* @param[in] codec Codec slot to bind to.
	* @param[in] impl  Implementation, or NULL to unregister.
	* @return CARQUET_OK on success;
	*         CARQUET_ERROR_INVALID_ARGUMENT if @p codec is out of range, equals
	*         `UNCOMPRESSED`, or @p impl has a NULL function pointer.
	*
	* @note Thread-safety: Not safe to call concurrently with reader/writer
	*       compression activity on the same codec slot.
	*/
	carquet_register_codec :: proc(codec: carquet_compression_t, impl: ^carquet_custom_codec_t) -> carquet_status_t ---
}

/** @brief Schema definition for a Parquet file */
carquet_schema_t :: carquet_schema
carquet_schema   :: struct {}

/** @brief Individual node within a schema (column or group) */
carquet_schema_node_t :: carquet_schema_node
carquet_schema_node   :: struct {}

/** @brief File reader handle */
carquet_reader_t :: carquet_reader
carquet_reader   :: struct {}
carquet_writer   :: struct {}

/** @brief File writer handle */
carquet_writer_t      :: carquet_writer
carquet_column_reader :: struct {}

/** @brief Column reader for streaming column data */
carquet_column_reader_t :: carquet_column_reader

/** @brief Column writer for streaming column data */
carquet_column_writer_t :: carquet_column_writer
carquet_column_writer   :: struct {}

/** @brief Row group metadata handle */
carquet_row_group_t :: carquet_row_group
carquet_row_group   :: struct {}

/** @brief Bloom filter for membership testing */
carquet_bloom_filter_t :: carquet_bloom_filter
carquet_bloom_filter   :: struct {}
carquet_column_index   :: struct {}

/** @brief Column index (per-page min/max statistics) */
carquet_column_index_t :: carquet_column_index

/** @brief Reusable thread pool for parallel reading */
carquet_thread_pool_t :: carquet_worker_pool
carquet_worker_pool   :: struct {}
carquet_offset_index  :: struct {}

/** @brief Offset index (per-page file locations) */
carquet_offset_index_t :: carquet_offset_index
carquet_row_batch      :: struct {}

/** @brief Row batch for batch reading */
carquet_row_batch_t  :: carquet_row_batch
carquet_batch_reader :: struct {}

/** @brief Batch reader for efficient columnar reading */
carquet_batch_reader_t :: carquet_batch_reader

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Create a new empty schema.
	*
	* Creates a schema builder that can be populated with columns and groups.
	* The schema must be freed with carquet_schema_free() when no longer needed.
	*
	* @param[out] error Error information (may be NULL)
	* @return New schema handle, or NULL on error
	*
	* @note Thread-safe: Yes
	*
	* @code{.c}
	* carquet_error_t err = CARQUET_ERROR_INIT;
	* carquet_schema_t* schema = carquet_schema_create(&err);
	* if (!schema) {
	*     fprintf(stderr, "Failed to create schema: %s\n", err.message);
	* }
	* @endcode
	*/
	carquet_schema_create :: proc(error: ^carquet_error_t) -> ^carquet_schema_t ---

	/**
	* @brief Free a schema and all associated resources.
	*
	* @param[in] schema Schema to free (may be NULL)
	*
	* @note Thread-safe: Yes (for different schema instances)
	* @note Safe to call with NULL (no-op)
	*/
	carquet_schema_free :: proc(schema: ^carquet_schema_t) ---

	/**
	* @brief Add a primitive (leaf) column to the schema.
	*
	* Adds a column that stores actual data values. For nested schemas, specify
	* the parent group index; for flat schemas, use 0 for root-level columns.
	*
	* @param[in,out] schema Target schema
	* @param[in] name Column name (must be unique within parent)
	* @param[in] physical_type Physical storage type
	* @param[in] logical_type Logical type annotation (may be NULL)
	* @param[in] repetition Field repetition level
	* @param[in] type_length Byte length for FIXED_LEN_BYTE_ARRAY (0 otherwise)
	* @param[in] parent_index Parent group index (0 for root level, or index from add_group)
	* @return CARQUET_OK on success, error code on failure
	*
	* @note Thread-safe: No (schema is mutable during construction)
	*
	* @par Physical Types
	* - CARQUET_PHYSICAL_BOOLEAN: 1-bit boolean
	* - CARQUET_PHYSICAL_INT32: 32-bit signed integer
	* - CARQUET_PHYSICAL_INT64: 64-bit signed integer
	* - CARQUET_PHYSICAL_FLOAT: 32-bit IEEE 754 float
	* - CARQUET_PHYSICAL_DOUBLE: 64-bit IEEE 754 double
	* - CARQUET_PHYSICAL_BYTE_ARRAY: Variable-length byte sequence
	* - CARQUET_PHYSICAL_FIXED_LEN_BYTE_ARRAY: Fixed-length byte sequence
	*
	* @code{.c}
	* // Required INT64 column at root
	* carquet_schema_add_column(schema, "id", CARQUET_PHYSICAL_INT64,
	*                           NULL, CARQUET_REPETITION_REQUIRED, 0, 0);
	*
	* // Optional string column at root
	* carquet_schema_add_column(schema, "name", CARQUET_PHYSICAL_BYTE_ARRAY,
	*                           NULL, CARQUET_REPETITION_OPTIONAL, 0, 0);
	*
	* // Fixed-length UUID column at root
	* carquet_schema_add_column(schema, "uuid", CARQUET_PHYSICAL_FIXED_LEN_BYTE_ARRAY,
	*                           NULL, CARQUET_REPETITION_REQUIRED, 16, 0);
	* @endcode
	*/
	carquet_schema_add_column :: proc(schema: ^carquet_schema_t, name: cstring, physical_type: carquet_physical_type_t, logical_type: ^carquet_logical_type_t, repetition: carquet_field_repetition_t, type_length: i32, parent_index: i32) -> carquet_status_t ---

	/**
	* @brief Add a group (struct) to the schema for nested structures.
	*
	* Groups are containers for other columns or groups, enabling nested schemas.
	* Use the returned index as the parent_index when adding child elements.
	*
	* @param[in,out] schema Target schema
	* @param[in] name Group name
	* @param[in] repetition Field repetition level
	* @param[in] parent_index Parent group index (0 for root level)
	* @return Index of new group (>= 0), or -1 on error
	*
	* @note Thread-safe: No
	*
	* @code{.c}
	* // Create nested schema: { address: { street: string, city: string } }
	* int32_t address_idx = carquet_schema_add_group(schema, "address",
	*                                                 CARQUET_REPETITION_OPTIONAL, 0);
	* carquet_schema_add_column(schema, "street", CARQUET_PHYSICAL_BYTE_ARRAY,
	*                           NULL, CARQUET_REPETITION_REQUIRED, 0, address_idx);
	* carquet_schema_add_column(schema, "city", CARQUET_PHYSICAL_BYTE_ARRAY,
	*                           NULL, CARQUET_REPETITION_REQUIRED, 0, address_idx);
	* @endcode
	*/
	carquet_schema_add_group :: proc(schema: ^carquet_schema_t, name: cstring, repetition: carquet_field_repetition_t, parent_index: i32) -> i32 ---

	/**
	* @brief Add an unshredded VARIANT group to the schema.
	*
	* Creates the standard Parquet unshredded VARIANT structure:
	* @code
	*   <name> (<variant_repetition>, VARIANT(1)) {
	*     required binary metadata;
	*     required binary value;
	*   }
	* @endcode
	*
	* @param[in,out] schema Target schema
	* @param[in] name Variant column name
	* @param[in] variant_repetition Repetition of the variant itself
	* @param[in] parent_index Parent group index (0 for root)
	* @return Group index of the variant container, or -1 on error
	*/
	carquet_schema_add_variant :: proc(schema: ^carquet_schema_t, name: cstring, variant_repetition: carquet_field_repetition_t, parent_index: i32) -> i32 ---

	/**
	* @brief Attach Arrow-style per-field metadata (e.g. a variable label) to a
	*        schema element.
	*
	* Records a key/value pair that mirrors Arrow's `Field.custom_metadata`. This
	* is the standard, reader-agnostic place for variable labels/descriptions:
	* when @ref carquet_writer_options_t::write_arrow_schema is enabled, the pairs
	* are emitted into the file-level `ARROW:schema` footer blob, and any
	* Arrow-compatible reader (PyArrow, Parquet viewers) surfaces them
	* automatically as field metadata. It is *not* written to
	* `ColumnMetaData.key_value_metadata` (which is per-row-group and wrong for
	* file-level, schema-level annotations).
	*
	* Calling it again with the same @p key on the same element replaces the value;
	* distinct keys accumulate. Only flat (top-level) fields are emitted, matching
	* the `ARROW:schema` writer.
	*
	* @param[in,out] schema        Target schema
	* @param[in] element_index     Schema element index (as returned by
	*                              @ref carquet_schema_add_group /
	*                              @ref carquet_schema_add_variant, or
	*                              `carquet_schema_num_elements() - 1` for the
	*                              column just added). Index 0 (root) is rejected.
	* @param[in] key               Metadata key (e.g. "Label"); copied. Non-NULL.
	* @param[in] value             Metadata value; copied. May be NULL.
	* @return CARQUET_OK, or CARQUET_ERROR_INVALID_ARGUMENT / _OUT_OF_MEMORY.
	*
	* @note Thread-safe: No (schema is mutable during construction)
	*
	* @code{.c}
	* carquet_schema_add_column(schema, "Sex", CARQUET_PHYSICAL_INT32,
	*                           NULL, CARQUET_REPETITION_REQUIRED, 0, 0);
	* carquet_schema_set_field_metadata(
	*     schema, carquet_schema_num_elements(schema) - 1,
	*     "Label", "Sex of Respondent");
	* @endcode
	*/
	carquet_schema_set_field_metadata :: proc(schema: ^carquet_schema_t, element_index: i32, key: cstring, value: cstring) -> carquet_status_t ---

	/**
	* @brief Get the number of leaf columns in the schema.
	*
	* Returns the count of primitive columns (not including groups).
	* This corresponds to the number of column chunks in each row group.
	*
	* @param[in] schema Schema to query
	* @return Number of leaf columns
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_schema_num_columns :: proc(schema: ^carquet_schema_t) -> i32 ---

	/**
	* @brief Get the total number of schema elements (columns + groups).
	*
	* @param[in] schema Schema to query
	* @return Total number of schema elements
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_schema_num_elements :: proc(schema: ^carquet_schema_t) -> i32 ---

	/**
	* @brief Get a schema element by index.
	*
	* @param[in] schema Schema to query
	* @param[in] index Element index (0 to num_elements - 1)
	* @return Schema node, or NULL if index is invalid
	*
	* @note Thread-safe: Yes (read-only)
	* @note The returned pointer is valid until the schema is freed.
	*/
	carquet_schema_get_element :: proc(schema: ^carquet_schema_t, index: i32) -> ^carquet_schema_node_t ---

	/**
	* @brief Find a column by name.
	*
	* Searches for a column with the given name. For nested schemas, use
	* dot-separated paths (e.g., "address.street").
	*
	* @param[in] schema Schema to search
	* @param[in] name Column name or path
	* @return Column index (>= 0), or -1 if not found
	*
	* @note Thread-safe: Yes (read-only)
	*
	* @code{.c}
	* int32_t idx = carquet_schema_find_column(schema, "address.city");
	* if (idx >= 0) {
	*     printf("Found column at index %d\n", idx);
	* }
	* @endcode
	*/
	carquet_schema_find_column :: proc(schema: ^carquet_schema_t, name: cstring) -> i32 ---

	/**
	* @brief Get the accumulated maximum definition level for a leaf column.
	*
	* Returns the total definition level accounting for all optional/repeated
	* ancestors in the schema tree. This is the value needed for encoding and
	* decoding definition levels in Parquet pages.
	*
	* @param[in] schema Schema to query
	* @param[in] leaf_index Leaf column index (0 to num_columns - 1)
	* @return Maximum definition level, or -1 if index is invalid
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_schema_max_def_level :: proc(schema: ^carquet_schema_t, leaf_index: i32) -> i16 ---

	/**
	* @brief Get the accumulated maximum repetition level for a leaf column.
	*
	* Returns the total repetition level accounting for all repeated ancestors
	* in the schema tree.
	*
	* @param[in] schema Schema to query
	* @param[in] leaf_index Leaf column index (0 to num_columns - 1)
	* @return Maximum repetition level, or -1 if index is invalid
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_schema_max_rep_level :: proc(schema: ^carquet_schema_t, leaf_index: i32) -> i16 ---

	/**
	* @brief Get the name of a leaf column by index.
	*
	* @param[in] schema Schema to query
	* @param[in] leaf_index Leaf column index (0 to num_columns - 1)
	* @return Column name, or NULL if index is invalid
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_schema_column_name :: proc(schema: ^carquet_schema_t, leaf_index: i32) -> cstring ---

	/**
	* @brief Get the physical type of a leaf column by index.
	*
	* @param[in] schema Schema to query
	* @param[in] leaf_index Leaf column index (0 to num_columns - 1)
	* @return Physical type
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_schema_column_type :: proc(schema: ^carquet_schema_t, leaf_index: i32) -> carquet_physical_type_t ---

	/**
	* @brief Get the full schema path for a leaf column.
	*
	* Returns the hierarchical path from root to leaf (excluding the root
	* "schema" element). For flat schemas, this is just the column name.
	* For nested schemas, this includes group names.
	*
	* Example: For column "city" under group "address", path is ["address", "city"].
	*
	* @param[in] schema Schema to query
	* @param[in] leaf_index Leaf column index (0 to num_columns - 1)
	* @param[out] path_out Array to receive path component pointers
	* @param[in] max_depth Maximum number of components to return
	* @return Number of path components written, or 0 on error
	*
	* @note Thread-safe: Yes (read-only)
	* @note Returned pointers are valid until the schema is freed.
	*/
	carquet_schema_column_path :: proc(schema: ^carquet_schema_t, leaf_index: i32, path_out: ^cstring, max_depth: i32) -> i32 ---

	/**
	* @brief Add a LIST column to the schema using the standard 3-level encoding.
	*
	* Creates the standard Parquet LIST structure:
	* @code
	*   <name> (<list_repetition>, LIST) {
	*     list (REPEATED) {
	*       element (OPTIONAL, <element_type>)
	*     }
	*   }
	* @endcode
	*
	* @param[in] schema Schema to modify
	* @param[in] name List column name
	* @param[in] element_type Physical type of list elements
	* @param[in] element_logical_type Logical type of elements (may be NULL)
	* @param[in] list_repetition Repetition of the list itself (OPTIONAL or REQUIRED)
	* @param[in] type_length Type length for FIXED_LEN_BYTE_ARRAY elements (0 otherwise)
	* @param[in] parent_index Parent group index (0 for root)
	* @return Group index of the list container, or -1 on error
	*/
	carquet_schema_add_list :: proc(schema: ^carquet_schema_t, name: cstring, element_type: carquet_physical_type_t, element_logical_type: ^carquet_logical_type_t, list_repetition: carquet_field_repetition_t, type_length: i32, parent_index: i32) -> i32 ---

	/**
	* @brief Add a MAP column to the schema using the standard encoding.
	*
	* Creates the standard Parquet MAP structure:
	* @code
	*   <name> (<map_repetition>, MAP) {
	*     key_value (REPEATED) {
	*       key (REQUIRED, <key_type>)
	*       value (OPTIONAL, <value_type>)
	*     }
	*   }
	* @endcode
	*
	* @param[in] schema Schema to modify
	* @param[in] name Map column name
	* @param[in] key_type Physical type of map keys
	* @param[in] key_logical_type Logical type of keys (may be NULL)
	* @param[in] key_type_length Type length for FIXED_LEN keys (0 otherwise)
	* @param[in] value_type Physical type of map values
	* @param[in] value_logical_type Logical type of values (may be NULL)
	* @param[in] value_type_length Type length for FIXED_LEN values (0 otherwise)
	* @param[in] map_repetition Repetition of the map itself (OPTIONAL or REQUIRED)
	* @param[in] parent_index Parent group index (0 for root)
	* @return Group index of the map container, or -1 on error
	*/
	carquet_schema_add_map :: proc(schema: ^carquet_schema_t, name: cstring, key_type: carquet_physical_type_t, key_logical_type: ^carquet_logical_type_t, key_type_length: i32, value_type: carquet_physical_type_t, value_logical_type: ^carquet_logical_type_t, value_type_length: i32, map_repetition: carquet_field_repetition_t, parent_index: i32) -> i32 ---

	/**
	* @brief Add a LIST container whose element is an arbitrary nested subtree.
	*
	* Creates the outer LIST-annotated group and the inner REPEATED `list` group,
	* and returns the index of that inner group. The caller adds exactly one child
	* to it — the element — which may itself be a leaf column
	* (@ref carquet_schema_add_column), a struct (@ref carquet_schema_add_group),
	* or another nested list/map. This is the composable form of
	* @ref carquet_schema_add_list and is what enables `LIST<LIST<...>>`,
	* `LIST<STRUCT<...>>`, and other arbitrarily deep repetition.
	*
	* @code
	*   int32_t inner = carquet_schema_add_list_group(schema, "matrix",
	*       CARQUET_REPETITION_OPTIONAL, 0);          // list<list<int32>>
	*   int32_t inner2 = carquet_schema_add_list_group(schema, "element",
	*       CARQUET_REPETITION_OPTIONAL, inner);
	*   carquet_schema_add_column(schema, "element", CARQUET_PHYSICAL_INT32, NULL,
	*       CARQUET_REPETITION_OPTIONAL, 0, inner2);
	* @endcode
	*
	* @param[in] schema Schema to modify
	* @param[in] name List column name (outer group)
	* @param[in] list_repetition Repetition of the list itself (OPTIONAL or REQUIRED)
	* @param[in] parent_index Parent group index (0 for root)
	* @return Index of the inner REPEATED `list` group (add the element to it), or
	*         -1 on error.
	*/
	carquet_schema_add_list_group :: proc(schema: ^carquet_schema_t, name: cstring, list_repetition: carquet_field_repetition_t, parent_index: i32) -> i32 ---

	/**
	* @brief Add a MAP container whose key/value are arbitrary nested subtrees.
	*
	* Creates the outer MAP-annotated group and the inner REPEATED `key_value`
	* group, and returns the index of that inner group. The caller adds exactly
	* two children to it: `key` (must be REQUIRED per the Parquet spec) and
	* `value` (any repetition). Either may be a leaf or a nested subtree, enabling
	* `MAP<K, LIST<V>>`, `MAP<K, STRUCT<...>>`, and so on.
	*
	* @param[in] schema Schema to modify
	* @param[in] name Map column name (outer group)
	* @param[in] map_repetition Repetition of the map itself (OPTIONAL or REQUIRED)
	* @param[in] parent_index Parent group index (0 for root)
	* @return Index of the inner REPEATED `key_value` group (add key + value to
	*         it), or -1 on error.
	*/
	carquet_schema_add_map_group :: proc(schema: ^carquet_schema_t, name: cstring, map_repetition: carquet_field_repetition_t, parent_index: i32) -> i32 ---

	/**
	* @brief Count logical rows from repetition levels.
	*
	* For repeated fields, the number of logical rows is the count of entries
	* where rep_level == 0 (indicating a new top-level record).
	*
	* If rep_levels is NULL, returns num_values (flat column).
	*
	* @param[in] rep_levels Repetition levels array (may be NULL)
	* @param[in] num_values Total number of values
	* @return Number of logical rows
	*/
	carquet_count_rows :: proc(rep_levels: ^i16, num_values: i64) -> i64 ---

	/**
	* @brief Compute list offsets from repetition levels.
	*
	* Produces an Arrow-style offsets array where offsets[i] is the start
	* index of list i, and offsets[num_lists] = num_values.
	*
	* @param[in] rep_levels Repetition levels array
	* @param[in] num_values Total number of values
	* @param[in] list_rep_level The repetition level that indicates a new list
	*                           element (typically 1 for top-level lists)
	* @param[out] offsets_out Output offsets array (must have space for num_lists + 1)
	* @param[in] max_offsets Maximum entries in offsets_out
	* @return Number of lists found
	*
	* @code{.c}
	* // Read a list<int32> column
	* int32_t values[100];
	* int16_t rep_levels[100];
	* int64_t count = carquet_column_read_batch(col, values, 100, NULL, rep_levels);
	*
	* // Reconstruct list boundaries
	* int64_t offsets[50];
	* int64_t num_lists = carquet_list_offsets(rep_levels, count, 1, offsets, 50);
	*
	* // Access list i: values[offsets[i]] .. values[offsets[i+1]-1]
	* for (int64_t i = 0; i < num_lists; i++) {
	*     printf("List %lld: %lld elements\n", i, offsets[i+1] - offsets[i]);
	* }
	* @endcode
	*/
	carquet_list_offsets :: proc(rep_levels: ^i16, num_values: i64, list_rep_level: i16, offsets_out: ^i64, max_offsets: i64) -> i64 ---

	/**
	* @brief Get the name of a schema node.
	*
	* @param[in] node Schema node to query
	* @return Node name (never NULL)
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_schema_node_name :: proc(node: ^carquet_schema_node_t) -> cstring ---

	/**
	* @brief Check if a schema node is a leaf (column) or group.
	*
	* @param[in] node Schema node to query
	* @return true if the node is a leaf column, false if it's a group
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_schema_node_is_leaf :: proc(node: ^carquet_schema_node_t) -> bool ---

	/**
	* @brief Get the physical type of a leaf node.
	*
	* @param[in] node Schema node (must be a leaf)
	* @return Physical type
	*
	* @note Thread-safe: Yes (read-only)
	* @warning Behavior is undefined if called on a group node.
	*/
	carquet_schema_node_physical_type :: proc(node: ^carquet_schema_node_t) -> carquet_physical_type_t ---

	/**
	* @brief Get the logical type annotation of a node.
	*
	* @param[in] node Schema node to query
	* @return Logical type, or NULL if none
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_schema_node_logical_type :: proc(node: ^carquet_schema_node_t) -> ^carquet_logical_type_t ---

	/**
	* @brief Get the repetition level of a node.
	*
	* @param[in] node Schema node to query
	* @return Field repetition (REQUIRED, OPTIONAL, or REPEATED)
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_schema_node_repetition :: proc(node: ^carquet_schema_node_t) -> carquet_field_repetition_t ---

	/**
	* @brief Get the maximum definition level for a column.
	*
	* The definition level indicates how many optional/repeated ancestors
	* are defined for a value. Used for reconstructing nested structures.
	*
	* @param[in] node Schema node (must be a leaf)
	* @return Maximum definition level
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_schema_node_max_def_level :: proc(node: ^carquet_schema_node_t) -> i16 ---

	/**
	* @brief Get the maximum repetition level for a column.
	*
	* The repetition level indicates which repeated ancestor started a new
	* list element. Used for reconstructing nested repeated structures.
	*
	* @param[in] node Schema node (must be a leaf)
	* @return Maximum repetition level
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_schema_node_max_rep_level :: proc(node: ^carquet_schema_node_t) -> i16 ---

	/**
	* @brief Get the type length for a FIXED_LEN_BYTE_ARRAY column.
	*
	* Returns the fixed byte length of each value. This is needed to allocate
	* correctly sized buffers for carquet_column_read_batch().
	*
	* @param[in] node Schema node (must be a leaf)
	* @return Type length in bytes, or 0 if not a FIXED_LEN_BYTE_ARRAY
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_schema_node_type_length :: proc(node: ^carquet_schema_node_t) -> i32 ---
}

/**
* @brief Configuration options for file reading.
*/
carquet_reader_options :: struct {
	/**
	* @brief Use memory-mapped I/O.
	*
	* When enabled, the file is memory-mapped rather than read into buffers.
	* This can improve performance for large files by letting the OS handle
	* paging and caching.
	*
	* Default: false
	*/
	use_mmap: bool,

	/**
	* @brief Verify page checksums (CRC32).
	*
	* When enabled, CRC32 checksums are verified for each data page.
	* This adds overhead but ensures data integrity.
	*
	* Default: true
	*/
	verify_checksums: bool,

	/**
	* @brief Read buffer size in bytes.
	*
	* Size of internal buffers for reading file data. Larger buffers
	* can improve throughput at the cost of memory usage.
	*
	* Default: 65536 (64 KB)
	*/
	buffer_size: c.size_t,

	/**
	* @brief Number of threads for parallel decompression.
	*
	* Set to 0 for automatic detection (uses number of CPU cores).
	* Set to 1 to disable parallel decompression.
	*
	* Default: 0 (auto)
	*/
	num_threads: i32,
}

/**
* @brief Configuration options for file reading.
*/
carquet_reader_options_t :: carquet_reader_options

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Initialize reader options with default values.
	*
	* @param[out] options Options structure to initialize
	*
	* @note Thread-safe: Yes
	*/
	carquet_reader_options_init :: proc(options: ^carquet_reader_options_t) ---

	/**
	* @brief Open a Parquet file for reading.
	*
	* Opens the specified file and reads its metadata. The file must be a valid
	* Parquet file with the "PAR1" magic bytes at the beginning and end.
	*
	* @param[in] path File path (must be null-terminated)
	* @param[in] options Reader options (may be NULL for defaults)
	* @param[out] error Error information (may be NULL)
	* @return Reader handle, or NULL on error
	*
	* @note Thread-safe: Yes
	* @note The returned reader must be closed with carquet_reader_close().
	*
	* @code{.c}
	* carquet_error_t err = CARQUET_ERROR_INIT;
	* carquet_reader_t* reader = carquet_reader_open("data.parquet", NULL, &err);
	* if (!reader) {
	*     char buf[512];
	*     carquet_error_format(&err, buf, sizeof(buf));
	*     fprintf(stderr, "Failed to open file: %s\n", buf);
	*     return 1;
	* }
	* // Use reader...
	* carquet_reader_close(reader);
	* @endcode
	*/
	carquet_reader_open :: proc(path: cstring, options: ^carquet_reader_options_t, error: ^carquet_error_t) -> ^carquet_reader_t ---

	/**
	* @brief Open a Parquet file from a FILE handle.
	*
	* The FILE handle must be opened in binary read mode ("rb") and positioned
	* at the beginning of the Parquet data. The handle must remain valid and
	* must not be modified while the reader is in use.
	*
	* @param[in] file FILE handle (must be opened in binary read mode)
	* @param[in] options Reader options (may be NULL)
	* @param[out] error Error information (may be NULL)
	* @return Reader handle, or NULL on error
	*
	* @note Thread-safe: Yes
	* @note The caller retains ownership of the FILE handle and must close it
	*       after closing the reader.
	*/
	carquet_reader_open_file :: proc(file: ^FILE, options: ^carquet_reader_options_t, error: ^carquet_error_t) -> ^carquet_reader_t ---

	/**
	* @brief Open a Parquet file from a memory buffer.
	*
	* Reads Parquet data directly from memory. This is useful for:
	* - Embedded resources
	* - Network-received data
	* - Memory-mapped files from external sources
	*
	* @param[in] buffer Pointer to Parquet data
	* @param[in] size Size of buffer in bytes
	* @param[in] options Reader options (may be NULL)
	* @param[out] error Error information (may be NULL)
	* @return Reader handle, or NULL on error
	*
	* @note Thread-safe: Yes
	* @warning The buffer must remain valid and unmodified while the reader is in use.
	*
	* @code{.c}
	* // Read from embedded resource
	* extern const unsigned char parquet_data[];
	* extern const size_t parquet_data_size;
	*
	* carquet_reader_t* reader = carquet_reader_open_buffer(
	*     parquet_data, parquet_data_size, NULL, NULL);
	* @endcode
	*/
	carquet_reader_open_buffer :: proc(buffer: rawptr, size: c.size_t, options: ^carquet_reader_options_t, error: ^carquet_error_t) -> ^carquet_reader_t ---

	/**
	* @brief Close a reader and release all resources.
	*
	* Closes the file (if opened by carquet_reader_open) and frees all memory
	* associated with the reader. After calling this function, the reader
	* handle is invalid and must not be used.
	*
	* @param[in] reader Reader to close (may be NULL)
	*
	* @note Thread-safe: Yes (for different reader instances)
	* @note Safe to call with NULL (no-op)
	*/
	carquet_reader_close :: proc(reader: ^carquet_reader_t) ---

	/**
	* @brief Get the file schema.
	*
	* Returns the schema describing the structure of the Parquet file.
	* The returned pointer is valid until the reader is closed.
	*
	* @param[in] reader File reader
	* @return Schema handle (never NULL for valid reader)
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_reader_schema :: proc(reader: ^carquet_reader_t) -> ^carquet_schema_t ---

	/**
	* @brief Get the total number of rows in the file.
	*
	* @param[in] reader File reader
	* @return Total row count across all row groups
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_reader_num_rows :: proc(reader: ^carquet_reader_t) -> i64 ---

	/**
	* @brief Get the number of row groups in the file.
	*
	* Row groups are independent units of data that can be read in parallel.
	* Each row group contains a subset of the total rows.
	*
	* @param[in] reader File reader
	* @return Number of row groups
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_reader_num_row_groups :: proc(reader: ^carquet_reader_t) -> i32 ---

	/**
	* @brief Get the number of columns in the file.
	*
	* @param[in] reader File reader
	* @return Number of leaf columns
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_reader_num_columns :: proc(reader: ^carquet_reader_t) -> i32 ---

	/**
	* @brief Check if reader is using memory-mapped I/O.
	*
	* When mmap is enabled, the reader can provide zero-copy access to data
	* for uncompressed columns with PLAIN encoding.
	*
	* @param[in] reader File reader
	* @return true if mmap is active, false otherwise
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_reader_is_mmap :: proc(reader: ^carquet_reader_t) -> bool ---

	/**
	* @brief Check if zero-copy reading is possible for a column.
	*
	* Zero-copy requires:
	* - Memory-mapped I/O enabled
	* - Uncompressed data (no compression codec)
	* - PLAIN encoding
	* - Fixed-size physical type (INT32, INT64, FLOAT, DOUBLE, INT96, FIXED_LEN_BYTE_ARRAY)
	* - No definition levels (REQUIRED column)
	*
	* @param[in] reader File reader
	* @param[in] row_group_index Row group index
	* @param[in] column_index Column index
	* @return true if zero-copy is possible, false otherwise
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_reader_can_zero_copy :: proc(reader: ^carquet_reader_t, row_group_index: i32, column_index: i32) -> bool ---
}

/**
* @brief Metadata for a row group.
*/
carquet_row_group_metadata :: struct {
	num_rows:              i64, /**< Number of rows in this row group */
	total_byte_size:       i64, /**< Total uncompressed size in bytes */
	total_compressed_size: i64, /**< Total compressed size in bytes */
}

/**
* @brief Metadata for a row group.
*/
carquet_row_group_metadata_t :: carquet_row_group_metadata

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Get metadata for a specific row group.
	*
	* @param[in] reader File reader
	* @param[in] row_group_index Row group index (0 to num_row_groups - 1)
	* @param[out] metadata Output metadata structure
	* @return CARQUET_OK on success, error code on failure
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_reader_row_group_metadata :: proc(reader: ^carquet_reader_t, row_group_index: i32, metadata: ^carquet_row_group_metadata_t) -> carquet_status_t ---

	/**
	* @brief Pre-buffer column data for I/O coalescing.
	*
	* For the fread path, pre-reads all requested column chunks from a row group
	* in a single coalesced I/O operation. Adjacent or nearby column ranges are
	* merged to reduce the number of fseek/fread calls. Subsequent column reads
	* from this row group will serve data from the pre-buffered cache instead of
	* issuing individual reads.
	*
	* For mmap readers, this is a no-op (the OS handles page coalescing).
	*
	* This is most beneficial for:
	* - Network/cloud storage (S3, GCS) where each I/O has high latency
	* - Reading many columns from the same row group
	* - HDD storage where sequential reads are much faster than random seeks
	*
	* @param[in] reader File reader
	* @param[in] row_group_index Row group to pre-buffer
	* @param[in] column_indices Array of column indices to pre-buffer
	* @param[in] num_columns Number of columns (0 = all columns)
	* @param[out] error Error information (may be NULL)
	* @return CARQUET_OK on success
	*
	* @note Thread-safe: No (modifies internal reader state)
	*
	* @code{.c}
	* // Pre-buffer columns 0, 2, 5 from row group 0
	* int32_t cols[] = {0, 2, 5};
	* carquet_reader_prebuffer(reader, 0, cols, 3, &err);
	*
	* // Subsequent column reads will use the pre-buffered data
	* carquet_column_reader_t* c0 = carquet_reader_get_column(reader, 0, 0, &err);
	* @endcode
	*/
	carquet_reader_prebuffer :: proc(reader: ^carquet_reader_t, row_group_index: i32, column_indices: ^i32, num_columns: i32, error: ^carquet_error_t) -> carquet_status_t ---

	/**
	* @brief Release pre-buffered data.
	*
	* Frees the memory used by carquet_reader_prebuffer(). Called automatically
	* when the reader is closed.
	*
	* @param[in] reader File reader
	*/
	carquet_reader_release_prebuffer :: proc(reader: ^carquet_reader_t) ---

	/**
	* @brief Get a column reader for a specific row group and column.
	*
	* Creates a reader for streaming values from a single column within a
	* single row group. The column reader must be freed with
	* carquet_column_reader_free() when no longer needed.
	*
	* @param[in] reader File reader
	* @param[in] row_group_index Row group index
	* @param[in] column_index Column index
	* @param[out] error Error information (may be NULL)
	* @return Column reader, or NULL on error
	*
	* @note Thread-safe: Yes (multiple column readers can be used concurrently)
	*
	* @code{.c}
	* carquet_column_reader_t* col = carquet_reader_get_column(reader, 0, 0, &err);
	* if (col) {
	*     int64_t values[1024];
	*     int64_t count;
	*     while ((count = carquet_column_read_batch(col, values, 1024, NULL, NULL)) > 0) {
	*         // Process values...
	*     }
	*     carquet_column_reader_free(col);
	* }
	* @endcode
	*/
	carquet_reader_get_column :: proc(reader: ^carquet_reader_t, row_group_index: i32, column_index: i32, error: ^carquet_error_t) -> ^carquet_column_reader_t ---

	/**
	* @brief Read a batch of values from a column.
	*
	* Reads up to max_values from the column into the output buffer. For nullable
	* columns, definition levels indicate which values are null. For repeated
	* columns, repetition levels indicate list boundaries.
	*
	* @param[in] reader Column reader
	* @param[out] values Output buffer for values (sized for physical type)
	* @param[in] max_values Maximum number of values to read
	* @param[out] def_levels Definition levels buffer (may be NULL if not needed)
	* @param[out] rep_levels Repetition levels buffer (may be NULL if not needed)
	* @return Number of values read (0 at end of column), or negative on error
	*
	* @note Thread-safe: No (single column reader is not thread-safe)
	*
	* @note This function collapses every failure mode onto the single sentinel
	* value -1 and cannot report a page-read failure that truncates a batch after
	* some values have already been read (it returns the partial count, which is
	* indistinguishable from a clean short read at end-of-column). When the caller
	* needs to tell these cases apart, use carquet_column_read_batch_ex(), which
	* reports a distinct status code and message through a carquet_error_t.
	*
	* @par Value Buffer Sizing
	* The values buffer must be sized appropriately for the column's physical type:
	* - BOOLEAN: uint8_t (1 byte per value)
	* - INT32: int32_t (4 bytes per value)
	* - INT64: int64_t (8 bytes per value)
	* - FLOAT: float (4 bytes per value)
	* - DOUBLE: double (8 bytes per value)
	* - BYTE_ARRAY: carquet_byte_array_t (pointer + length)
	* - FIXED_LEN_BYTE_ARRAY: uint8_t[type_length]
	*/
	carquet_column_read_batch :: proc(reader: ^carquet_column_reader_t, values: rawptr, max_values: i64, def_levels: ^i16, rep_levels: ^i16) -> i64 ---

	/**
	* @brief Read a batch of values from a column with detailed error reporting.
	*
	* Behaves exactly like carquet_column_read_batch() but reports a distinct
	* status code (and human-readable message) for each failure condition through
	* the optional @p error out-parameter, which is consistent with the
	* carquet_error_t convention used elsewhere in the API.
	*
	* @param[in]  reader     Column reader
	* @param[out] values     Output buffer for values (sized for physical type)
	* @param[in]  max_values Maximum number of values to read
	* @param[out] def_levels Definition levels buffer (may be NULL if not needed)
	* @param[out] rep_levels Repetition levels buffer (may be NULL if not needed)
	* @param[out] error      Error information (may be NULL). Cleared on entry and
	*                        set only when a failure occurs.
	* @return Number of values read, or -1 if no values could be read because of an
	*         error. See the return/error contract below.
	*
	* @par Return / error contract
	* The return value and @p error together distinguish four caller-visible cases:
	* - <b>ret &gt;= 0 and error unset</b> — clean read. A value smaller than
	*   @p max_values simply means the end of the column was reached.
	* - <b>ret &gt; 0 and error set</b> — <em>partial</em> read: the returned values
	*   are valid, but a page-read failure truncated the batch before @p max_values
	*   (or end-of-column) was reached. The remaining values were NOT read. The
	*   caller can salvage the returned data and still detect the failure.
	* - <b>ret == -1 and error set</b> — hard failure with nothing read. The
	*   @p error code identifies the cause:
	*   - #CARQUET_ERROR_INVALID_ARGUMENT — @p max_values &lt; 0
	*   - #CARQUET_ERROR_TYPE_MISMATCH    — the column's physical type is unknown
	*   - #CARQUET_ERROR_OUT_OF_MEMORY    — scratch definition-level allocation failed
	*   - any page/decode/I-O status      — propagated verbatim from the failing page read
	*
	* @note Callers that pass NULL for @p error get the same -1 / partial-count
	* behavior as carquet_column_read_batch(); the extra information is simply
	* discarded.
	*
	* @note Thread-safe: No (single column reader is not thread-safe)
	*
	* @see carquet_column_read_batch() for the value-buffer sizing rules.
	*/
	carquet_column_read_batch_ex :: proc(reader: ^carquet_column_reader_t, values: rawptr, max_values: i64, def_levels: ^i16, rep_levels: ^i16, error: ^carquet_error_t) -> i64 ---

	/**
	* @brief Skip values in a column without reading them.
	*
	* Efficiently skips over values in the column stream. This is faster than
	* reading and discarding values.
	*
	* @param[in] reader Column reader
	* @param[in] num_values Number of values to skip
	* @return Number of values actually skipped
	*
	* @note Thread-safe: No
	*/
	carquet_column_skip :: proc(reader: ^carquet_column_reader_t, num_values: i64) -> i64 ---

	/**
	* @brief Check if there are more values to read.
	*
	* @param[in] reader Column reader
	* @return true if more values are available
	*
	* @note Thread-safe: No
	*/
	carquet_column_has_next :: proc(reader: ^carquet_column_reader_t) -> bool ---

	/**
	* @brief Get the number of remaining values in the column.
	*
	* @param[in] reader Column reader
	* @return Number of values remaining
	*
	* @note Thread-safe: No
	*/
	carquet_column_remaining :: proc(reader: ^carquet_column_reader_t) -> i64 ---

	/**
	* @brief Free a column reader.
	*
	* @param[in] reader Column reader to free (may be NULL)
	*
	* @note Thread-safe: Yes (for different reader instances)
	*/
	carquet_column_reader_free :: proc(reader: ^carquet_column_reader_t) ---
}

/**
* @brief Row group filter callback for predicate pushdown.
*
* Called for each row group before reading. Return true to read the row group,
* false to skip it entirely. Use carquet_reader_row_group_matches() or
* carquet_reader_column_statistics() inside this callback to make filtering
* decisions based on column statistics.
*
* @param[in] reader File reader (for querying statistics)
* @param[in] row_group_index Row group being considered
* @param[in] user_data User-provided context pointer
* @return true to read this row group, false to skip it
*
* @code{.c}
* bool filter_large_ids(const carquet_reader_t* reader,
*                       int32_t row_group_index, void* ctx) {
*     int64_t threshold = *(int64_t*)ctx;
*     bool might_match = true;
*     carquet_reader_row_group_matches(reader, row_group_index, 0,
*         CARQUET_COMPARE_GT, &threshold, sizeof(threshold), &might_match);
*     return might_match;
* }
* @endcode
*/
carquet_row_group_filter_fn :: proc "c" (reader: ^carquet_reader_t, row_group_index: i32, user_data: rawptr) -> bool

/**
* @brief Batch reader configuration.
*/
carquet_batch_reader_config :: struct {
	/**
	* @brief Number of rows per batch.
	*
	* Larger batches reduce overhead but use more memory.
	*
	* Default: 65536 (64K rows)
	*/
	batch_size: i32,

	/**
	* @brief Number of threads for parallel column reading.
	*
	* Set to 0 for automatic detection, 1 to disable parallelism.
	*
	* Default: 0 (auto)
	*/
	num_threads: i32,

	/**
	* @brief Use memory-mapped I/O.
	*
	* Default: false
	*/
	use_mmap: bool,

	/**
	* @brief Column projection by index.
	*
	* Array of column indices to read. If NULL, all columns are read.
	* Takes precedence over column_names if both are specified.
	*/
	column_indices: ^i32,

	/**
	* @brief Number of columns in column_indices array.
	*/
	num_columns: i32,

	/**
	* @brief Column projection by name.
	*
	* Array of column names to read. If NULL, all columns are read.
	* Ignored if column_indices is specified.
	*/
	column_names: ^cstring,

	/**
	* @brief Number of column names.
	*/
	num_column_names: i32,

	/**
	* @brief Row group filter for predicate pushdown.
	*
	* When set, called for each row group before reading. Row groups where
	* the filter returns false are skipped entirely (no I/O or decompression).
	* This enables efficient predicate pushdown using column statistics.
	*
	* Default: NULL (read all row groups)
	*/
	row_group_filter: carquet_row_group_filter_fn,

	/**
	* @brief User data passed to row_group_filter callback.
	*
	* Default: NULL
	*/
	row_group_filter_ctx: rawptr,

	/**
	* @brief Preserve dictionary encoding instead of materializing values.
	*
	* When true, dictionary-encoded columns return raw indices (uint32_t*)
	* instead of materialized values. Use carquet_row_batch_column_dictionary()
	* to retrieve indices and dictionary data. This avoids the scatter-gather
	* cost and can yield 10-50x speedups on string-heavy columns.
	*
	* Default: false
	*/
	preserve_dictionaries: bool,

	/**
	* @brief External thread pool for parallel decompression.
	*
	* When non-NULL, the batch reader borrows this pool instead of creating
	* and destroying its own threads per reader. This avoids pthread
	* create/join overhead (~1-2ms) on every read. Create with
	* carquet_thread_pool_create() and reuse across multiple batch readers.
	*
	* The caller retains ownership and must call carquet_thread_pool_destroy()
	* after all batch readers using it have been freed.
	*
	* Default: NULL (batch reader creates its own pool)
	*/
	thread_pool: ^carquet_thread_pool_t,
}

/**
* @brief Batch reader configuration.
*/
carquet_batch_reader_config_t :: carquet_batch_reader_config

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Initialize batch reader configuration with defaults.
	*
	* @param[out] config Configuration to initialize
	*
	* @note Thread-safe: Yes
	*/
	carquet_batch_reader_config_init :: proc(config: ^carquet_batch_reader_config_t) ---

	/**
	* @brief Create a reusable thread pool for parallel reading.
	*
	* Pass the returned pool to carquet_batch_reader_config_t::thread_pool
	* to avoid thread create/join overhead on every batch reader.
	*
	* @param[in] num_threads Number of worker threads (0 = auto-detect)
	* @return Thread pool, or NULL on failure
	*
	* @note Thread-safe: Yes (the pool itself serializes internally)
	*/
	carquet_thread_pool_create :: proc(num_threads: i32) -> ^carquet_thread_pool_t ---

	/**
	* @brief Destroy a thread pool.
	*
	* All batch readers using this pool must be freed first.
	*
	* @param[in] pool Thread pool to destroy (may be NULL)
	*/
	carquet_thread_pool_destroy :: proc(pool: ^carquet_thread_pool_t) ---

	/**
	* @brief Create a batch reader for efficient columnar reading.
	*
	* Creates a batch reader that iterates over the file in row batches.
	* Use column projection to read only the columns you need.
	*
	* @param[in] reader File reader
	* @param[in] config Batch reader configuration (may be NULL for defaults)
	* @param[out] error Error information (may be NULL)
	* @return Batch reader, or NULL on error
	*
	* @note Thread-safe: Yes
	*
	* @code{.c}
	* carquet_batch_reader_config_t config;
	* carquet_batch_reader_config_init(&config);
	*
	* // Project only two columns
	* const char* cols[] = {"id", "timestamp"};
	* config.column_names = cols;
	* config.num_column_names = 2;
	*
	* carquet_batch_reader_t* batch_reader = carquet_batch_reader_create(
	*     reader, &config, &err);
	* @endcode
	*/
	carquet_batch_reader_create :: proc(reader: ^carquet_reader_t, config: ^carquet_batch_reader_config_t, error: ^carquet_error_t) -> ^carquet_batch_reader_t ---

	/**
	* @brief Read the next batch of rows.
	*
	* Reads the next batch of rows from the file. The batch must be freed
	* with carquet_row_batch_free() when done.
	*
	* @param[in] batch_reader Batch reader
	* @param[out] batch Output batch (set to NULL when no more data)
	* @return CARQUET_OK on success, CARQUET_ERROR_END_OF_DATA when finished
	*
	* @note Thread-safe: No
	*
	* @warning Streaming lifetime: the returned batch (and all data, null
	*          bitmap, and dictionary pointers obtained from it) is owned by
	*          the batch reader and is invalidated by the next call to
	*          carquet_batch_reader_next() on the same reader, and by
	*          carquet_batch_reader_free(). The batch reader pools and reuses
	*          batch buffers, so do not retain a batch across next() calls;
	*          copy out any values you need to keep. carquet_row_batch_free()
	*          ends your use of the current batch but does not extend its
	*          lifetime past the next next() call.
	*
	* @code{.c}
	* carquet_row_batch_t* batch = NULL;
	* while (carquet_batch_reader_next(batch_reader, &batch) == CARQUET_OK && batch) {
	*     // Process batch...
	*     carquet_row_batch_free(batch);
	*     batch = NULL;
	* }
	* @endcode
	*/
	carquet_batch_reader_next :: proc(batch_reader: ^carquet_batch_reader_t, batch: ^^carquet_row_batch_t) -> carquet_status_t ---

	/**
	* @brief Free a batch reader.
	*
	* @param[in] batch_reader Batch reader to free (may be NULL)
	*
	* @note Thread-safe: Yes (for different instances)
	*/
	carquet_batch_reader_free :: proc(batch_reader: ^carquet_batch_reader_t) ---

	/**
	* @brief Get the number of rows in a batch.
	*
	* @param[in] batch Row batch
	* @return Number of rows
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_row_batch_num_rows :: proc(batch: ^carquet_row_batch_t) -> i64 ---

	/**
	* @brief Get the number of columns in a batch.
	*
	* This is the number of projected columns, not the total file columns.
	*
	* @param[in] batch Row batch
	* @return Number of columns in the batch
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_row_batch_num_columns :: proc(batch: ^carquet_row_batch_t) -> i32 ---

	/**
	* @brief Get column data from a batch.
	*
	* Returns pointers to the raw column data within the batch. The pointers
	* remain valid only until the next carquet_batch_reader_next() call on the
	* owning reader (or until the batch reader is freed); see that function's
	* streaming-lifetime warning. Copy the data to retain it across batches.
	*
	* @param[in] batch Row batch
	* @param[in] column_index Column index within the batch (0 to num_columns-1)
	* @param[out] data Pointer to column data (type depends on physical type)
	* @param[out] null_bitmap Null bitmap (1 bit per value, set = not null) or NULL
	* @param[out] num_values Number of values in the column
	* @return CARQUET_OK on success, or CARQUET_ERROR_INVALID_ARGUMENT if the
	*         column is dictionary-preserved (preserve_dictionaries enabled and the
	*         column kept its dictionary): its data is uint32_t indices, not values,
	*         so it must be read via carquet_row_batch_column_dictionary() instead.
	*
	* @note Thread-safe: Yes (read-only)
	*
	* @par Null Bitmap Format
	* The null bitmap uses 1 bit per value, with bit i set if value i is NOT null.
	* Use the following to check if value i is null:
	* @code{.c}
	* bool is_null = null_bitmap && !(null_bitmap[i / 8] & (1 << (i % 8)));
	* @endcode
	*/
	carquet_row_batch_column :: proc(batch: ^carquet_row_batch_t, column_index: i32, data: ^rawptr, null_bitmap: ^^u8, num_values: ^i64) -> carquet_status_t ---

	/**
	* @brief Get dictionary-preserved column data from a batch.
	*
	* When preserve_dictionaries is enabled in the batch reader config,
	* dictionary-encoded columns store raw indices instead of materialized values.
	* This function retrieves the indices and dictionary data for zero-copy access.
	*
	* @warning The returned index, null bitmap, and dictionary pointers follow
	*          the same streaming lifetime as carquet_batch_reader_next(): they
	*          are invalidated by the next next() call on the owning reader (the
	*          dictionary view in particular is reset when the row-group reader
	*          advances). Copy out anything you need to keep across batches.
	*
	* @param[in] batch Row batch
	* @param[in] column_index Column index within the batch
	* @param[out] indices Pointer to uint32_t index array (one per non-null value)
	* @param[out] null_bitmap Null bitmap or NULL
	* @param[out] num_values Number of values (rows)
	* @param[out] dictionary_data Raw dictionary bytes
	* @param[out] dictionary_count Number of entries in the dictionary
	* @param[out] dictionary_offsets Offset table for BYTE_ARRAY dictionaries (NULL for fixed-width)
	* @return CARQUET_OK on success, CARQUET_ERROR_INVALID_ARGUMENT if column is not dictionary-preserved
	*
	* @note For BYTE_ARRAY dictionaries, use the offset table for O(1) value lookup:
	* @code{.c}
	* uint32_t offset = dictionary_offsets[index];
	* const uint8_t* entry = dictionary_data + offset;
	* uint32_t len = *(uint32_t*)entry;  // little-endian length prefix
	* const uint8_t* value = entry + 4;
	* @endcode
	*/
	carquet_row_batch_column_dictionary :: proc(batch: ^carquet_row_batch_t, column_index: i32, indices: ^^u32, null_bitmap: ^^u8, num_values: ^i64, dictionary_data: ^^u8, dictionary_count: ^i32, dictionary_offsets: ^^u32) -> carquet_status_t ---

	/**
	* @brief Access a repeated (LIST / MAP-leaf) column as an Arrow List<T>.
	*
	* When a projected column is repeated (`max_rep_level == 1`), the batch reader
	* reconstructs it into Arrow's list layout: a flattened child (element) array
	* plus an offsets buffer that delimits each logical row's slice of that child
	* array. Such a column is rejected by @ref carquet_row_batch_column (which
	* would silently drop the list structure) and must be read here instead.
	*
	* For row `i` (0 <= i < *num_lists), its elements are
	* `values[(*offsets)[i]] .. values[(*offsets)[i+1] - 1]`, and element `k` is
	* null iff `value_validity` is non-NULL and bit `k` is clear
	* (`!(value_validity[k/8] & (1 << (k%8)))`). The list itself (row `i`) is null
	* iff `list_validity` is non-NULL and bit `i` is clear.
	*
	* The batch reader reads repeated columns a whole row group at a time, so one
	* batch corresponds to one row group for such projections. Only single-level
	* lists are supported; deeper nesting (`max_rep_level > 1`) makes
	* @ref carquet_batch_reader_next return `CARQUET_ERROR_NOT_IMPLEMENTED`.
	*
	* @param[in] batch Row batch.
	* @param[in] column_index Projected column index.
	* @param[out] offsets Arrow list offsets, `*num_lists + 1` int32 entries.
	* @param[out] num_lists Number of logical rows (lists) in the batch.
	* @param[out] values Flattened child value array (physical type of the leaf).
	* @param[out] value_validity Child validity bitmap (LSB-first, present bit set),
	*                            or NULL when no element is null.
	* @param[out] num_values Number of child elements (== `(*offsets)[*num_lists]`).
	* @param[out] list_validity List-level validity bitmap, or NULL when no list is
	*                           null (may be passed as NULL to ignore).
	* @return CARQUET_OK, or CARQUET_ERROR_INVALID_ARGUMENT if the column is not a
	*         reconstructed list column.
	*
	* @note All returned pointers belong to the batch; see
	*       @ref carquet_row_batch_free for lifetime.
	*/
	carquet_row_batch_column_list :: proc(batch: ^carquet_row_batch_t, column_index: i32, offsets: ^^i32, num_lists: ^i64, values: ^rawptr, value_validity: ^^u8, num_values: ^i64, list_validity: ^^u8) -> carquet_status_t ---

	/**
	* @brief Free a row batch.
	*
	* Call this when finished with a batch returned by
	* carquet_batch_reader_next(). Batches from a batch reader are pooled: the
	* underlying buffers are owned and recycled by the reader, so this call
	* releases your hold on the current batch but does not extend the lifetime
	* of its data past the next carquet_batch_reader_next() call. For
	* independently allocated batches it frees the owned data.
	*
	* @param[in] batch Batch to free (may be NULL)
	*
	* @note Thread-safe: Yes (for different instances)
	*/
	carquet_row_batch_free :: proc(batch: ^carquet_row_batch_t) ---
}

/**
* @brief Column statistics for a row group.
*/
carquet_column_statistics :: struct {
	has_min_max:        bool,   /**< Min/max values are available */
	has_null_count:     bool,   /**< Null count is available */
	has_distinct_count: bool,   /**< Distinct count is available */
	null_count:         i64,    /**< Number of null values */
	distinct_count:     i64,    /**< Distinct value count; exact (non-null) when
                                     carquet wrote it from a dictionary column */
	num_values:         i64,    /**< Total number of values (including nulls) */
	min_value:          rawptr, /**< Minimum value (type depends on column) */
	max_value:          rawptr, /**< Maximum value (type depends on column) */
	min_value_size:     i32,    /**< Size of min_value in bytes */
	max_value_size:     i32,    /**< Size of max_value in bytes */
}

/**
* @brief Column statistics for a row group.
*/
carquet_column_statistics_t :: carquet_column_statistics

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Get statistics for a column in a row group.
	*
	* @param[in] reader File reader
	* @param[in] row_group_index Row group index
	* @param[in] column_index Column index
	* @param[out] stats Output statistics
	* @return CARQUET_OK on success
	*
	* @note Thread-safe: Yes (read-only)
	* @note Statistics may not be available for all columns/row groups.
	*       Check the has_* flags before using values.
	*/
	carquet_reader_column_statistics :: proc(reader: ^carquet_reader_t, row_group_index: i32, column_index: i32, stats: ^carquet_column_statistics_t) -> carquet_status_t ---
}

/**
* @brief Comparison operators for predicate pushdown.
*/
carquet_compare_op :: enum u32 {
	EQ = 0, /**< Equal (==) */
	NE = 1, /**< Not equal (!=) */
	LT = 2, /**< Less than (<) */
	LE = 3, /**< Less than or equal (<=) */
	GT = 4, /**< Greater than (>) */
	GE = 5, /**< Greater than or equal (>=) */
}

/**
* @brief Comparison operators for predicate pushdown.
*/
carquet_compare_op_t :: carquet_compare_op

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Check if a row group might contain values matching a predicate.
	*
	* Uses min/max statistics to determine if a row group can be safely skipped.
	* A return of might_match=true does not guarantee matches exist, only that
	* they cannot be ruled out based on statistics.
	*
	* @param[in] reader File reader
	* @param[in] row_group_index Row group index
	* @param[in] column_index Column index
	* @param[in] op Comparison operator
	* @param[in] value Value to compare against
	* @param[in] value_size Size of value in bytes
	* @param[out] might_match Set to true if row group might contain matches
	* @return CARQUET_OK on success
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_reader_row_group_matches :: proc(reader: ^carquet_reader_t, row_group_index: i32, column_index: i32, op: carquet_compare_op_t, value: rawptr, value_size: i32, might_match: ^bool) -> carquet_status_t ---

	/**
	* @brief Filter row groups based on a predicate.
	*
	* Returns indices of row groups that might contain matching data.
	* Use this to skip reading row groups that cannot match a query.
	*
	* @param[in] reader File reader
	* @param[in] column_index Column index
	* @param[in] op Comparison operator
	* @param[in] value Value to compare against
	* @param[in] value_size Size of value in bytes
	* @param[out] matching_indices Output array of matching row group indices
	* @param[in] max_indices Maximum number of indices to return
	* @return Number of matching row groups, or negative on error
	*
	* @note Thread-safe: Yes (read-only)
	*
	* @code{.c}
	* int32_t threshold = 1000;
	* int32_t matches[100];
	* int32_t count = carquet_reader_filter_row_groups(
	*     reader, 0, CARQUET_COMPARE_GT, &threshold, sizeof(threshold), matches, 100);
	*
	* printf("Found %d row groups with values > 1000\n", count);
	* for (int i = 0; i < count; i++) {
	*     // Read only matching row groups...
	* }
	* @endcode
	*/
	carquet_reader_filter_row_groups :: proc(reader: ^carquet_reader_t, column_index: i32, op: carquet_compare_op_t, value: rawptr, value_size: i32, matching_indices: ^i32, max_indices: i32) -> i32 ---
}

/**
* @brief Writer configuration options.
*/
carquet_writer_options :: struct {
	/**
	* @brief Compression codec for all columns.
	*
	* Default: CARQUET_COMPRESSION_SNAPPY
	*/
	compression: carquet_compression_t,

	/**
	* @brief Compression level (codec-specific).
	*
	* - ZSTD: 1-22
	* - GZIP: 1-9
	* - Others: ignored
	*
	* Default: 0 (use codec default)
	*/
	compression_level: i32,

	/**
	* @brief Target row group size in bytes.
	*
	* Row groups are automatically flushed when this size is exceeded.
	*
	* Default: 128MB
	*/
	row_group_size: i64,

	/**
	* @brief Target page size in bytes.
	*
	* Default: 1MB
	*/
	page_size: i64,

	/**
	* @brief Write column statistics (min/max values).
	*
	* Statistics enable predicate pushdown when reading.
	*
	* Default: true
	*/
	write_statistics: bool,

	/**
	* @brief Write page CRC32 checksums.
	*
	* CRCs improve corruption detection but add write-side overhead.
	*
	* Default: true
	*/
	write_crc: bool,

	/**
	* @brief Write page index for efficient page skipping.
	*
	* Default: false
	*/
	write_page_index: bool,

	/**
	* @brief Write bloom filters for membership testing.
	*
	* Default: false
	*/
	write_bloom_filters: bool,

	/**
	* @brief Dictionary encoding mode.
	*
	* Default: CARQUET_ENCODING_PLAIN_DICTIONARY
	*/
	dictionary_encoding: carquet_encoding_t,

	/**
	* @brief Maximum dictionary page size.
	*
	* Dictionary encoding is disabled for columns exceeding this size.
	*
	* Default: 1MB
	*/
	dictionary_page_size: i64,

	/**
	* @brief Creator identification string.
	*
	* Stored in file metadata.
	*
	* Default: "Carquet"
	*/
	created_by: cstring,

	/**
	* @brief Maximum number of rows per data page.
	*
	* When greater than 0, a data page is flushed once it accumulates this
	* many rows, in addition to the size-based trigger (@ref page_size).
	*
	* Default: 0 (unlimited — size-based flushing only)
	*/
	max_rows_per_page: i64,

	/**
	* @brief Embed the original Arrow schema as "ARROW:schema" footer metadata.
	*
	* When true, an Arrow IPC Schema message describing the columns is written
	* (base64-encoded) under the "ARROW:schema" key, so Arrow/PyArrow can
	* recover Arrow-specific type information losslessly. Only emitted for
	* flat (non-nested) schemas; nested schemas leave it out rather than write
	* a schema that disagrees with the Parquet schema. Default output bytes
	* are unchanged when this is false.
	*
	* Default: false
	*/
	write_arrow_schema: bool,

	/**
	* @brief Data page format version to write (1 or 2).
	*
	* Version 1 (default) writes DATA_PAGE; version 2 writes DATA_PAGE_V2,
	* which stores repetition/definition levels uncompressed and outside the
	* compressed value region (matching Arrow's parquet-cpp). Any value other
	* than 2 is treated as version 1.
	*
	* Default: 1
	*/
	data_page_version: i32,

	/**
	* @brief Coerce all TIMESTAMP columns to a single unit on write.
	*
	* When true, every `TIMESTAMP` (INT64) column is rescaled to
	* @ref coerce_timestamp_unit and its metadata is emitted at that unit,
	* regardless of the unit declared in the schema (mirrors PyArrow's
	* `coerce_timestamps`). A coarser target loses precision; that is only
	* allowed when @ref allow_timestamp_truncation is true, otherwise a value
	* with a non-zero remainder fails the write.
	*
	* Default: false
	*/
	coerce_timestamps: bool,

	/**
	* @brief Target unit when @ref coerce_timestamps is true.
	*
	* Default: CARQUET_TIME_UNIT_MICROS
	*/
	coerce_timestamp_unit: carquet_time_unit_t,

	/**
	* @brief Allow lossy TIMESTAMP truncation during coercion.
	*
	* Mirrors PyArrow's `allow_truncated_timestamps`. Only consulted when
	* @ref coerce_timestamps is true and the target unit is coarser than the
	* source unit.
	*
	* Default: false
	*/
	allow_timestamp_truncation: bool,

	/**
	* @brief Internal value-batch size for column writing.
	*
	* Caps how many values are processed per internal chunk before a page
	* flush is considered (mirrors PyArrow's `write_batch_size`). 0 keeps the
	* automatic page-size-derived heuristic.
	*
	* Default: 0 (automatic)
	*/
	write_batch_size: i64,

	/**
	* @brief Parquet file format version written into the footer (1 or 2).
	*
	* Controls the `version` field of `FileMetaData`. Version 2 (default) is
	* what every modern reader expects and what carquet has always emitted.
	* Setting this to 1 produces a footer compatible with very old readers
	* that reject version-2 files; it does not change page or encoding format
	* (use @ref data_page_version for that). Any value other than 1 is
	* treated as 2.
	*
	* Default: 2
	*/
	file_format_version: i32,
}

/**
* @brief Writer configuration options.
*/
carquet_writer_options_t :: carquet_writer_options

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Initialize writer options with default values.
	*
	* @param[out] options Options to initialize
	*
	* @note Thread-safe: Yes
	*/
	carquet_writer_options_init :: proc(options: ^carquet_writer_options_t) ---

	/**
	* @brief Create a new Parquet file for writing.
	*
	* Creates a new file and prepares it for writing. The schema defines the
	* structure of the data to be written.
	*
	* @param[in] path Output file path
	* @param[in] schema File schema (copied, caller retains ownership)
	* @param[in] options Writer options (may be NULL for defaults)
	* @param[out] error Error information (may be NULL)
	* @return Writer handle, or NULL on error
	*
	* @note Thread-safe: Yes
	*
	* @code{.c}
	* carquet_writer_options_t opts;
	* carquet_writer_options_init(&opts);
	* opts.compression = CARQUET_COMPRESSION_ZSTD;
	*
	* carquet_writer_t* writer = carquet_writer_create(
	*     "output.parquet", schema, &opts, &err);
	* @endcode
	*/
	carquet_writer_create :: proc(path: cstring, schema: ^carquet_schema_t, options: ^carquet_writer_options_t, error: ^carquet_error_t) -> ^carquet_writer_t ---

	/**
	* @brief Create a writer to a FILE handle.
	*
	* @param[in] file FILE handle (must be opened in binary write mode)
	* @param[in] schema File schema
	* @param[in] options Writer options (may be NULL)
	* @param[out] error Error information (may be NULL)
	* @return Writer handle, or NULL on error
	*
	* @note Thread-safe: Yes
	* @note Caller retains ownership of FILE handle.
	*/
	carquet_writer_create_file :: proc(file: ^FILE, schema: ^carquet_schema_t, options: ^carquet_writer_options_t, error: ^carquet_error_t) -> ^carquet_writer_t ---

	/**
	* @brief Open an existing Parquet file and append new row groups to it.
	*
	* Parses the existing file's footer, validates that @p schema describes the
	* same leaf columns (count / name / physical type / repetition), and returns
	* a writer positioned just before the existing footer. Subsequent calls to
	* `carquet_writer_write_batch()` and `carquet_writer_new_row_group()` add new
	* row groups; on `carquet_writer_close()` the writer emits a fresh footer
	* that lists the existing row groups followed by the new ones. Existing
	* bloom filters and page indexes are preserved (they sit between the row
	* group data and the old footer, which is the region we overwrite).
	*
	* Restrictions:
	* - The file must exist and contain a valid Parquet footer.
	* - The supplied schema must match the existing file's leaf columns. Logical
	*   types and adjacent metadata on the new row groups follow @p schema and
	*   @p options; the existing row groups keep their original metadata as
	*   parsed from the footer.
	* - Existing key-value metadata is carried over; calls to
	*   `carquet_writer_add_metadata()` add additional entries.
	*
	* @param[in] path Path to an existing Parquet file (opened with read+write
	*                 access; not truncated).
	* @param[in] schema Schema describing the file's leaf columns.
	* @param[in] options Writer options for the new row groups (may be NULL).
	* @param[out] error Error information (may be NULL).
	* @return Writer handle, or NULL on error (e.g. schema mismatch, footer
	*         missing).
	*
	* @note Thread-safe: Yes (returns an independent handle).
	*/
	carquet_writer_open_append :: proc(path: cstring, schema: ^carquet_schema_t, options: ^carquet_writer_options_t, error: ^carquet_error_t) -> ^carquet_writer_t ---

	/**
	* @brief Write a batch of values to a column.
	*
	* Writes values to the specified column. All columns must be written the
	* same number of rows before closing or starting a new row group.
	*
	* @param[in] writer File writer
	* @param[in] column_index Column index
	* @param[in] values Input values (type must match column physical type).
	*                    For nullable columns, this contains only the non-null
	*                    values, packed contiguously (sparse encoding).
	* @param[in] num_values Number of logical rows (length of def_levels if provided)
	* @param[in] def_levels Definition levels (NULL if all values defined).
	*                        One entry per logical row.
	* @param[in] rep_levels Repetition levels (NULL if no repetition)
	* @return CARQUET_OK on success
	*
	* @note Thread-safe: No
	*
	* @par Writing Nullable Columns
	* For nullable columns (OPTIONAL repetition), provide definition levels:
	* - def_level = max_def_level: value is present
	* - def_level < max_def_level: value is null
	*
	* The values array uses sparse encoding: it contains only the non-null values,
	* packed contiguously. The def_levels array has num_values entries (one per
	* logical row). The number of entries in values must equal the number of
	* entries in def_levels where def_level == max_def_level.
	*
	* @code{.c}
	* // Write non-nullable column (5 rows, all present)
	* int64_t ids[] = {1, 2, 3, 4, 5};
	* carquet_writer_write_batch(writer, 0, ids, 5, NULL, NULL);
	*
	* // Write nullable column: logical rows [1.1, NULL, 3.3, NULL, 5.5]
	* double values[] = {1.1, 3.3, 5.5};              // 3 non-null values only
	* int16_t def_levels[] = {1, 0, 1, 0, 1};         // 5 entries, one per row
	* carquet_writer_write_batch(writer, 1, values, 5, def_levels, NULL);
	* @endcode
	*/
	carquet_writer_write_batch :: proc(writer: ^carquet_writer_t, column_index: i32, values: rawptr, num_values: i64, def_levels: ^i16, rep_levels: ^i16) -> carquet_status_t ---

	/**
	* @brief Write a single-level repeated (LIST / MAP) leaf column from
	*        Arrow-style offsets and validity, without precomputing levels.
	*
	* Auto-shreds a repeated leaf into the definition/repetition levels that
	* @ref carquet_writer_write_batch expects, then writes it. This is the
	* write-side inverse of @ref carquet_row_batch_column_list. It handles the
	* standard single-level encoding produced by @ref carquet_schema_add_list
	* (`LIST<T>`) and @ref carquet_schema_add_map (`MAP<K,V>`): a REPEATED group
	* (`max_rep_level == 1`) with an OPTIONAL or REQUIRED container above it and
	* an OPTIONAL or REQUIRED leaf below. Deeper nesting returns
	* @ref CARQUET_ERROR_NOT_IMPLEMENTED.
	*
	* @p column_index is the *leaf* column: the list element, or a map's key or
	* value column. A `MAP<K,V>` is written with two calls sharing the same
	* @p offsets and @p list_validity — one for the key leaf (`value_validity`
	* NULL, keys are REQUIRED) and one for the value leaf.
	*
	* Buffers follow the Arrow columnar layout:
	* - @p offsets has `num_lists + 1` int32 entries; `offsets[0]` must be 0 and
	*   the array must be non-decreasing. `offsets[num_lists]` is the total child
	*   element count.
	* - @p list_validity is an Arrow (LSB-first) validity bitmap over the lists
	*   (bit set ⇒ present); NULL means every list is present. A cleared bit
	*   writes a null list (requires an OPTIONAL container).
	* - @p values holds `offsets[num_lists]` child values in child order (the
	*   full child array, including slots for null elements). For `BYTE_ARRAY`
	*   this is a `carquet_byte_array_t` array; for `FIXED_LEN_BYTE_ARRAY`,
	*   `type_length` bytes per element; otherwise the natural scalar type.
	* - @p value_validity is an Arrow validity bitmap over the child elements
	*   (bit set ⇒ present); NULL means every element is present. A cleared bit
	*   writes a null element (requires an OPTIONAL leaf).
	*
	* @param[in] writer         File writer
	* @param[in] column_index   Leaf column index (list element / map key or value)
	* @param[in] num_lists      Number of list (or map) rows
	* @param[in] offsets        `num_lists + 1` int32 offsets (may be NULL iff
	*                           `num_lists == 0`)
	* @param[in] list_validity  List-level validity bitmap, or NULL (all present)
	* @param[in] values         Child values buffer (may be NULL iff there are no
	*                           child elements)
	* @param[in] value_validity Element-level validity bitmap, or NULL (all present)
	* @param[out] error         Error information (may be NULL)
	* @return CARQUET_OK on success
	*
	* @note Thread-safe: No
	*/
	carquet_writer_write_list_column :: proc(writer: ^carquet_writer_t, column_index: i32, num_lists: i64, offsets: ^i32, list_validity: ^u8, values: rawptr, value_validity: ^u8, error: ^carquet_error_t) -> carquet_status_t ---

	/**
	* @brief Start a new row group.
	*
	* Flushes the current row group and starts a new one. This is called
	* automatically when the row group size exceeds the configured limit,
	* but can be called explicitly for finer control.
	*
	* @param[in] writer File writer
	* @return CARQUET_OK on success
	*
	* @note Thread-safe: No
	* @warning All columns must have the same number of rows when this is called.
	*/
	carquet_writer_new_row_group :: proc(writer: ^carquet_writer_t) -> carquet_status_t ---

	/**
	* @brief Get the number of leaf columns the writer expects.
	*
	* Mirrors @ref carquet_reader_num_columns for the write side. This is the count
	* of leaf columns in the schema the writer was created with, i.e. the valid
	* range of @p column_index for @ref carquet_writer_write_batch.
	*
	* @param[in] writer File writer
	* @return Number of leaf columns
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_writer_num_columns :: proc(writer: ^carquet_writer_t) -> i32 ---

	/**
	* @brief Close the writer and finalize the file.
	*
	* Writes any buffered data, the file footer, and closes the file.
	* The writer handle becomes invalid after this call.
	*
	* @param[in] writer Writer to close
	* @return CARQUET_OK on success
	*
	* @note Thread-safe: No
	* @warning All columns must have the same number of rows when this is called.
	*/
	carquet_writer_close :: proc(writer: ^carquet_writer_t) -> carquet_status_t ---

	/**
	* @brief Abort writing and clean up without finalizing the file.
	*
	* Closes the writer and releases resources without writing a valid
	* Parquet footer. The resulting file will be invalid/incomplete.
	*
	* @param[in] writer Writer to abort (may be NULL)
	*
	* @note Thread-safe: No
	*/
	carquet_writer_abort :: proc(writer: ^carquet_writer_t) ---
}

/* ============================================================================
* Utility Functions
* ============================================================================ */

/** @brief Maximum length (including NUL) of carquet_file_info_t::created_by. */
CARQUET_CREATED_BY_MAX :: 256

/**
* @brief File information from metadata (without full parsing).
*/
carquet_file_info :: struct {
	file_size:      i64, /**< Total file size in bytes */
	num_rows:       i64, /**< Total number of rows */
	num_row_groups: i32, /**< Number of row groups */
	num_columns:    i32, /**< Number of columns */
	version:        i32, /**< Parquet format version */

	/**
	* @brief Creator identification, NUL-terminated.
	*
	* Empty string if the file declares no creator. Stored inline (caller
	* owns the carquet_file_info_t), so no separate free is needed. A creator
	* string longer than CARQUET_CREATED_BY_MAX-1 bytes is truncated.
	*/
	created_by: [256]i8,
}

/**
* @brief File information from metadata (without full parsing).
*/
carquet_file_info_t :: carquet_file_info

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Get basic file information without fully opening the file.
	*
	* Reads only the file footer to extract basic metadata.
	* Faster than opening a full reader when only metadata is needed.
	*
	* @param[in] path File path
	* @param[out] info Output file information
	* @param[out] error Error information (may be NULL)
	* @return CARQUET_OK on success
	*
	* @note Thread-safe: Yes
	*/
	carquet_get_file_info :: proc(path: cstring, info: ^carquet_file_info_t, error: ^carquet_error_t) -> carquet_status_t ---

	/**
	* @brief Validate a Parquet file structure.
	*
	* Performs structural validation of the file:
	* - Checks magic bytes
	* - Validates footer
	* - Optionally verifies page checksums
	*
	* @param[in] path File path
	* @param[out] error Detailed error information (may be NULL)
	* @return CARQUET_OK if file is valid
	*
	* @note Thread-safe: Yes
	*/
	carquet_validate_file :: proc(path: cstring, error: ^carquet_error_t) -> carquet_status_t ---

	/**
	* @brief Read a bloom filter for a column in a row group.
	*
	* Reads the bloom filter data from the file at the offset stored in
	* column chunk metadata. Returns NULL if no bloom filter is available.
	*
	* @param[in] reader File reader
	* @param[in] row_group_index Row group index
	* @param[in] column_index Column index
	* @param[out] error Error information (may be NULL)
	* @return Bloom filter handle, or NULL if unavailable
	*
	* @note The caller must free the returned filter with carquet_bloom_filter_destroy().
	*/
	carquet_reader_get_bloom_filter :: proc(reader: ^carquet_reader_t, row_group_index: i32, column_index: i32, error: ^carquet_error_t) -> ^carquet_bloom_filter_t ---

	/**
	* @brief Check if a bloom filter might contain an int32 value.
	* @return true if value might be present, false if definitely absent
	*/
	carquet_bloom_filter_check_i32 :: proc(filter: ^carquet_bloom_filter_t, value: i32) -> bool ---

	/**
	* @brief Check if a bloom filter might contain an int64 value.
	*/
	carquet_bloom_filter_check_i64 :: proc(filter: ^carquet_bloom_filter_t, value: i64) -> bool ---

	/**
	* @brief Check if a bloom filter might contain a float value.
	*/
	carquet_bloom_filter_check_float :: proc(filter: ^carquet_bloom_filter_t, value: f32) -> bool ---

	/**
	* @brief Check if a bloom filter might contain a double value.
	*/
	carquet_bloom_filter_check_double :: proc(filter: ^carquet_bloom_filter_t, value: f64) -> bool ---

	/**
	* @brief Check if a bloom filter might contain a byte sequence.
	*/
	carquet_bloom_filter_check_bytes :: proc(filter: ^carquet_bloom_filter_t, data: ^u8, len: c.size_t) -> bool ---

	/**
	* @brief Get bloom filter size in bytes.
	*/
	carquet_bloom_filter_size :: proc(filter: ^carquet_bloom_filter_t) -> c.size_t ---

	/**
	* @brief Free a bloom filter.
	* @param[in] filter Filter to free (may be NULL)
	*/
	carquet_bloom_filter_destroy :: proc(filter: ^carquet_bloom_filter_t) ---
}

/**
* @brief Per-page statistics from a column index.
*/
carquet_page_stats :: struct {
	null_count:     i64,    /**< Number of nulls in this page */
	min_value:      rawptr, /**< Minimum value (type depends on column) */
	min_value_size: i32,    /**< Size of min_value in bytes */
	max_value:      rawptr, /**< Maximum value (type depends on column) */
	max_value_size: i32,    /**< Size of max_value in bytes */
	is_null_page:   bool,   /**< True if page contains only nulls */
}

/**
* @brief Per-page statistics from a column index.
*/
carquet_page_stats_t :: carquet_page_stats

/**
* @brief Per-page location from an offset index.
*/
carquet_page_location :: struct {
	offset:          i64, /**< File offset of the page */
	compressed_size: i32, /**< Compressed page size in bytes */
	first_row_index: i64, /**< Index of first row in this page */
}

/**
* @brief Per-page location from an offset index.
*/
carquet_page_location_t :: carquet_page_location

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Read column index (per-page statistics) for a column chunk.
	*
	* @param[in] reader File reader
	* @param[in] row_group_index Row group index
	* @param[in] column_index Column index
	* @param[out] error Error information (may be NULL)
	* @return Column index handle, or NULL if unavailable
	*
	* @note Caller must free with carquet_column_index_free().
	*/
	carquet_reader_get_column_index :: proc(reader: ^carquet_reader_t, row_group_index: i32, column_index: i32, error: ^carquet_error_t) -> ^carquet_column_index_t ---

	/**
	* @brief Get the number of pages in a column index.
	*/
	carquet_column_index_num_pages :: proc(index: ^carquet_column_index_t) -> i32 ---

	/**
	* @brief Get per-page statistics from a column index.
	*
	* @param[in] index Column index
	* @param[in] page_index Page number (0 to num_pages - 1)
	* @param[out] stats Output page statistics
	* @return CARQUET_OK on success
	*/
	carquet_column_index_get_page_stats :: proc(index: ^carquet_column_index_t, page_index: i32, stats: ^carquet_page_stats_t) -> carquet_status_t ---

	/**
	* @brief Get boundary order of a column index.
	* @return 0=UNORDERED, 1=ASCENDING, 2=DESCENDING
	*/
	carquet_column_index_boundary_order :: proc(index: ^carquet_column_index_t) -> i32 ---

	/**
	* @brief Free a column index.
	*/
	carquet_column_index_free :: proc(index: ^carquet_column_index_t) ---

	/**
	* @brief Read offset index (per-page locations) for a column chunk.
	*
	* @param[in] reader File reader
	* @param[in] row_group_index Row group index
	* @param[in] column_index Column index
	* @param[out] error Error information (may be NULL)
	* @return Offset index handle, or NULL if unavailable
	*
	* @note Caller must free with carquet_offset_index_free().
	*/
	carquet_reader_get_offset_index :: proc(reader: ^carquet_reader_t, row_group_index: i32, column_index: i32, error: ^carquet_error_t) -> ^carquet_offset_index_t ---

	/**
	* @brief Get the number of pages in an offset index.
	*/
	carquet_offset_index_num_pages :: proc(index: ^carquet_offset_index_t) -> i32 ---

	/**
	* @brief Get page location from an offset index.
	*
	* @param[in] index Offset index
	* @param[in] page_index Page number (0 to num_pages - 1)
	* @param[out] location Output page location
	* @return CARQUET_OK on success
	*/
	carquet_offset_index_get_page_location :: proc(index: ^carquet_offset_index_t, page_index: i32, location: ^carquet_page_location_t) -> carquet_status_t ---

	/**
	* @brief Free an offset index.
	*/
	carquet_offset_index_free :: proc(index: ^carquet_offset_index_t) ---
}

/**
* @brief Comparison operators for page filter clauses.
*/
carquet_filter_op :: enum u32 {
	EQ          = 0,
	NE          = 1,
	LT          = 2,
	LE          = 3,
	GT          = 4,
	GE          = 5,
	RANGE       = 6, /**< closed [lo, hi]; either endpoint may be omitted */
	IN          = 7, /**< value membership; values + value_count */
	IS_NULL     = 8,
	IS_NOT_NULL = 9,
}

/**
* @brief Comparison operators for page filter clauses.
*/
carquet_filter_op_t :: carquet_filter_op

/**
* @brief One clause in a conjunctive page filter.
*
* For numeric types (INT32/INT64/FLOAT/DOUBLE/BOOLEAN), `value` points to
* a scalar of the column's native width and `value_size` is ignored.
*
* For BYTE_ARRAY, `value` is a pointer to the raw bytes and `value_size`
* is the byte length. For FIXED_LEN_BYTE_ARRAY, `value_size` must equal
* the column's declared type_length.
*
* For RANGE: when has_lo is true, lo/lo_size give the lower bound;
* when has_hi is true, hi/hi_size give the upper bound. At least one
* endpoint must be present.
*
* For IN: `values` points to a packed array of `value_count` entries.
* For fixed-width numeric types, the entries are native-width scalars laid
* out contiguously (stride = sizeof(physical type)). For BYTE_ARRAY and
* FIXED_LEN_BYTE_ARRAY, `values` is a contiguous array of
* carquet_byte_array_t entries.
*
* For IS_NULL / IS_NOT_NULL, all value fields are ignored.
*
* The clauses array and all data it points to are referenced (not copied)
* by the batch reader for the lifetime of the filter — the caller must
* keep them alive until set_page_filter() is called again or the batch
* reader is freed.
*/
carquet_filter_clause :: struct {
	column_index: i32,
	op:           carquet_filter_op_t,

	/* Unary ops (EQ, NE, LT, LE, GT, GE) */
	value:      rawptr,
	value_size: i32,

	/* RANGE */
	lo:      rawptr,
	lo_size: i32,
	hi:      rawptr,
	hi_size: i32,
	has_lo:  bool,
	has_hi:  bool,

	/* IN */
	values:      rawptr,
	value_count: i32,
}

/**
* @brief One clause in a conjunctive page filter.
*
* For numeric types (INT32/INT64/FLOAT/DOUBLE/BOOLEAN), `value` points to
* a scalar of the column's native width and `value_size` is ignored.
*
* For BYTE_ARRAY, `value` is a pointer to the raw bytes and `value_size`
* is the byte length. For FIXED_LEN_BYTE_ARRAY, `value_size` must equal
* the column's declared type_length.
*
* For RANGE: when has_lo is true, lo/lo_size give the lower bound;
* when has_hi is true, hi/hi_size give the upper bound. At least one
* endpoint must be present.
*
* For IN: `values` points to a packed array of `value_count` entries.
* For fixed-width numeric types, the entries are native-width scalars laid
* out contiguously (stride = sizeof(physical type)). For BYTE_ARRAY and
* FIXED_LEN_BYTE_ARRAY, `values` is a contiguous array of
* carquet_byte_array_t entries.
*
* For IS_NULL / IS_NOT_NULL, all value fields are ignored.
*
* The clauses array and all data it points to are referenced (not copied)
* by the batch reader for the lifetime of the filter — the caller must
* keep them alive until set_page_filter() is called again or the batch
* reader is freed.
*/
carquet_filter_clause_t :: carquet_filter_clause

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Attach a conjunctive page filter to the batch reader.
	*
	* Pass clauses = NULL or count = 0 to clear any previously installed filter.
	*
	* The filter is evaluated lazily, per row group, the first time each row
	* group is read. Subsequent batches within a row group reuse the cached
	* row-range list.
	*
	* @param[in] reader   Batch reader
	* @param[in] clauses  Array of filter clauses (AND'd together), or NULL
	* @param[in] count    Number of clauses
	* @return CARQUET_OK on success;
	*         CARQUET_ERROR_INVALID_ARGUMENT for an out-of-range column,
	*         a type/size mismatch, or an INT96 predicate;
	*         CARQUET_ERROR_PAGE_INDEX_REQUIRED if any referenced column lacks
	*         a column index (file was not written with write_page_index = true).
	*
	* @note Thread-safe: No
	*/
	carquet_batch_reader_set_page_filter :: proc(reader: ^carquet_batch_reader_t, clauses: ^carquet_filter_clause_t, count: i32) -> carquet_status_t ---

	/**
	* @brief Number of rows skipped by the active page filter so far.
	*
	* Returns 0 when no filter is set, or when no rows have been skipped yet.
	* Useful for confirming that filtering is firing on a given workload.
	*/
	carquet_batch_reader_rows_skipped :: proc(reader: ^carquet_batch_reader_t) -> i64 ---

	/**
	* @brief Get the number of key-value metadata entries in the file.
	*
	* @param[in] reader File reader
	* @return Number of key-value pairs
	*/
	carquet_reader_num_metadata :: proc(reader: ^carquet_reader_t) -> i32 ---

	/**
	* @brief Get a key-value metadata entry by index.
	*
	* @param[in] reader File reader
	* @param[in] index Entry index (0 to num_metadata - 1)
	* @param[out] key Output key string pointer (valid until reader is closed)
	* @param[out] value Output value string pointer (may be NULL)
	* @return CARQUET_OK on success
	*/
	carquet_reader_get_metadata :: proc(reader: ^carquet_reader_t, index: i32, key: ^cstring, value: ^cstring) -> carquet_status_t ---

	/**
	* @brief Find a metadata value by key.
	*
	* @param[in] reader File reader
	* @param[in] key Key to search for
	* @return Value string, or NULL if key not found
	*/
	carquet_reader_find_metadata :: proc(reader: ^carquet_reader_t, key: cstring) -> cstring ---

	/**
	* @brief Number of Arrow per-field metadata entries for a leaf column.
	*
	* Recovered from the file's `ARROW:schema` footer blob (variable
	* labels/descriptions written via @ref carquet_schema_set_field_metadata, or
	* by PyArrow / Arrow C++). Returns 0 when the file has no `ARROW:schema` blob,
	* the blob is malformed, or the column carries no field metadata.
	*
	* @param[in] reader File reader
	* @param[in] column_index Leaf column index (0 to num_columns - 1)
	* @return Entry count, or 0 on an invalid column index
	*/
	carquet_reader_column_num_metadata :: proc(reader: ^carquet_reader_t, column_index: i32) -> i32 ---

	/**
	* @brief Get an Arrow per-field metadata entry for a leaf column by index.
	*
	* @param[in] reader File reader
	* @param[in] column_index Leaf column index (0 to num_columns - 1)
	* @param[in] index Entry index (0 to column_num_metadata - 1)
	* @param[out] key Output key string (valid until reader is closed)
	* @param[out] value Output value string (may be NULL)
	* @return CARQUET_OK on success, CARQUET_ERROR_INVALID_ARGUMENT if out of range
	*/
	carquet_reader_column_get_metadata :: proc(reader: ^carquet_reader_t, column_index: i32, index: i32, key: ^cstring, value: ^cstring) -> carquet_status_t ---

	/**
	* @brief Find an Arrow per-field metadata value for a leaf column by key.
	*
	* Convenience lookup, e.g. `carquet_reader_column_find_metadata(r, i, "Label")`
	* to read a variable label.
	*
	* @param[in] reader File reader
	* @param[in] column_index Leaf column index (0 to num_columns - 1)
	* @param[in] key Key to search for
	* @return Value string, or NULL if the column/key is not found
	*/
	carquet_reader_column_find_metadata :: proc(reader: ^carquet_reader_t, column_index: i32, key: cstring) -> cstring ---
}

/**
* @brief Arrow type refinements recovered from the "ARROW:schema" footer blob.
*
* Some Arrow types cannot be expressed by the Parquet type system, so a
* PyArrow / Arrow C++ writer stores the original Arrow type only in the
* "ARROW:schema" footer. On read, carquet recovers the ones that apply to a
* flat leaf column; the leaf's Parquet physical type is unchanged (e.g. a
* LargeUtf8 column is still stored as a `BYTE_ARRAY` with STRING logical type)
* but the refinement tells the caller the original 64-bit-offset Arrow type.
*/
carquet_arrow_type_refinement :: enum u32 {
	NONE         = 0, /**< No Arrow-only refinement */
	LARGE_UTF8   = 1, /**< Arrow LargeUtf8 (64-bit offsets) */
	LARGE_BINARY = 2, /**< Arrow LargeBinary (64-bit offsets) */
	LARGE_LIST   = 3, /**< Arrow LargeList (64-bit offsets) */
}

/**
* @brief Arrow type refinements recovered from the "ARROW:schema" footer blob.
*
* Some Arrow types cannot be expressed by the Parquet type system, so a
* PyArrow / Arrow C++ writer stores the original Arrow type only in the
* "ARROW:schema" footer. On read, carquet recovers the ones that apply to a
* flat leaf column; the leaf's Parquet physical type is unchanged (e.g. a
* LargeUtf8 column is still stored as a `BYTE_ARRAY` with STRING logical type)
* but the refinement tells the caller the original 64-bit-offset Arrow type.
*/
carquet_arrow_type_refinement_t :: carquet_arrow_type_refinement

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Recover the Arrow type refinement for a leaf column, if any.
	*
	* Reads the refinement recovered from the file's "ARROW:schema" blob (see
	* @ref carquet_arrow_type_refinement_t). Returns @ref CARQUET_ARROW_REFINE_NONE
	* when the file has no "ARROW:schema", the column is not a flat top-level
	* field, or the field carried no 64-bit-offset Arrow type. Purely informational
	* — it never changes how the column's values are read.
	*
	* @param[in] reader File reader
	* @param[in] column_index Leaf column index (0 to num_columns - 1)
	* @return The recovered refinement, or CARQUET_ARROW_REFINE_NONE
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_reader_column_arrow_type_refinement :: proc(reader: ^carquet_reader_t, column_index: i32) -> carquet_arrow_type_refinement_t ---

	/**
	* @brief Add key-value metadata to the file being written.
	*
	* Must be called before carquet_writer_close(). Multiple entries with
	* the same key are allowed (last wins for most readers).
	*
	* @param[in] writer File writer
	* @param[in] key Metadata key
	* @param[in] value Metadata value (may be NULL)
	* @return CARQUET_OK on success
	*/
	carquet_writer_add_metadata :: proc(writer: ^carquet_writer_t, key: cstring, value: cstring) -> carquet_status_t ---
}

/**
* @brief Detailed metadata for a column chunk.
*/
carquet_column_chunk_metadata :: struct {
	type:                    carquet_physical_type_t, /**< Physical type */
	codec:                   carquet_compression_t,   /**< Compression codec used */
	num_values:              i64,                     /**< Number of values */
	total_compressed_size:   i64,                     /**< Total compressed bytes */
	total_uncompressed_size: i64,                     /**< Total uncompressed bytes */
	data_page_offset:        i64,                     /**< File offset of first data page */
	has_dictionary_page:     bool,                    /**< Dictionary page present */
	dictionary_page_offset:  i64,                     /**< File offset of dictionary page */
	num_encodings:           i32,                     /**< Number of encodings used */
	encodings:               [4]carquet_encoding_t,   /**< Encodings used (up to 4) */
	has_bloom_filter:        bool,                    /**< Bloom filter present */
	has_column_index:        bool,                    /**< Column index present */
	has_offset_index:        bool,                    /**< Offset index present */
}

/**
* @brief Detailed metadata for a column chunk.
*/
carquet_column_chunk_metadata_t :: carquet_column_chunk_metadata

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Get metadata for a column chunk.
	*
	* @param[in] reader File reader
	* @param[in] row_group_index Row group index
	* @param[in] column_index Column index
	* @param[out] metadata Output metadata
	* @return CARQUET_OK on success
	*/
	carquet_reader_column_chunk_metadata :: proc(reader: ^carquet_reader_t, row_group_index: i32, column_index: i32, metadata: ^carquet_column_chunk_metadata_t) -> carquet_status_t ---
}

/** @brief Maximum geometry type codes reported in geospatial statistics. */
CARQUET_MAX_GEOSPATIAL_TYPES :: 64

/**
* @brief GeospatialStatistics for a GEOMETRY/GEOGRAPHY column chunk.
*
* @c has_bbox is true when a coordinate bounding box was recorded. @c has_z /
* @c has_m indicate whether the Z (elevation) and M dimensions are present.
* @c geometry_types holds the distinct ISO-WKB type codes encountered
* (e.g. 1 = Point XY, 1001 = Point XYZ); an empty list means "unknown".
*/
carquet_geospatial_statistics :: struct {
	has_bbox:               bool,
	xmin, xmax, ymin, ymax: f64,
	has_z:                  bool,
	zmin, zmax:             f64,
	has_m:                  bool,
	mmin, mmax:             f64,
	num_geometry_types:     i32,
	geometry_types:         [64]i32,
}

/**
* @brief GeospatialStatistics for a GEOMETRY/GEOGRAPHY column chunk.
*
* @c has_bbox is true when a coordinate bounding box was recorded. @c has_z /
* @c has_m indicate whether the Z (elevation) and M dimensions are present.
* @c geometry_types holds the distinct ISO-WKB type codes encountered
* (e.g. 1 = Point XY, 1001 = Point XYZ); an empty list means "unknown".
*/
carquet_geospatial_statistics_t :: carquet_geospatial_statistics

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Get GeospatialStatistics for a GEOMETRY/GEOGRAPHY column chunk.
	*
	* @param[in] reader File reader
	* @param[in] row_group_index Row group index
	* @param[in] column_index Column index
	* @param[out] stats Output statistics
	* @return CARQUET_OK if the column chunk carries geospatial statistics;
	*         CARQUET_ERROR_INVALID_METADATA if it does not (not an error for
	*         non-geospatial columns); CARQUET_ERROR_INVALID_ARGUMENT on bad
	*         indices.
	*
	* @note Thread-safe: Yes (read-only)
	*/
	carquet_reader_geospatial_statistics :: proc(reader: ^carquet_reader_t, row_group_index: i32, column_index: i32, stats: ^carquet_geospatial_statistics_t) -> carquet_status_t ---

	/**
	* @brief Set encoding for a specific column.
	*
	* Overrides the automatic encoding selection for this column.
	*
	* @param[in] writer File writer
	* @param[in] column_index Column index
	* @param[in] encoding Desired encoding
	* @return CARQUET_OK on success
	*/
	carquet_writer_set_column_encoding :: proc(writer: ^carquet_writer_t, column_index: i32, encoding: carquet_encoding_t) -> carquet_status_t ---

	/**
	* @brief Set compression for a specific column.
	*
	* Overrides the global compression setting for this column.
	*
	* @param[in] writer File writer
	* @param[in] column_index Column index
	* @param[in] codec Compression codec
	* @param[in] level Compression level (0 for codec default)
	* @return CARQUET_OK on success
	*/
	carquet_writer_set_column_compression :: proc(writer: ^carquet_writer_t, column_index: i32, codec: carquet_compression_t, level: i32) -> carquet_status_t ---

	/**
	* @brief Override the target byte-based page-flush size for one column.
	*
	* Overrides `carquet_writer_options_t.page_size` for the given column.
	* Useful when some columns benefit from smaller pages (finer page-level
	* pruning via the page index) while others benefit from larger pages
	* (lower per-page header overhead). Must be called before writing data,
	* like the other per-column setters.
	*
	* @param[in] writer File writer
	* @param[in] column_index Column index
	* @param[in] bytes Target page size in bytes (must be > 0)
	* @return CARQUET_OK on success; CARQUET_ERROR_INVALID_ARGUMENT if
	*         @p column_index is out of range or @p bytes is non-positive.
	*/
	carquet_writer_set_column_page_size :: proc(writer: ^carquet_writer_t, column_index: i32, bytes: i64) -> carquet_status_t ---

	/**
	* @brief Maximum stored size of variable-length min/max statistics.
	*
	* Caps how many bytes of a BYTE_ARRAY column's `min` / `max` are stored in
	* column statistics. Longer values are truncated: the min is stored as the
	* leading prefix (still a valid lower bound), and the max is stored as the
	* leading prefix incremented lexicographically (still a valid upper bound).
	* If the max prefix is all `0xFF` so the increment cannot be represented,
	* the max is omitted entirely rather than being stored as an invalid bound.
	* The `is_min_value_exact` / `is_max_value_exact` flags reflect whether the
	* stored value equals the actual column min / max.
	*
	* Fixed-width physical types (numeric, BOOLEAN, FIXED_LEN_BYTE_ARRAY) are
	* stored at their natural width and ignore this setting.
	*
	* Default: 32 bytes (matches Arrow and the Parquet spec recommendation).
	*
	* @param[in] writer File writer
	* @param[in] bytes Maximum stored size (must be > 0)
	* @return CARQUET_OK on success; CARQUET_ERROR_INVALID_ARGUMENT if
	*         @p bytes is non-positive.
	*/
	carquet_writer_set_max_statistics_size :: proc(writer: ^carquet_writer_t, bytes: i64) -> carquet_status_t ---

	/**
	* @brief Enable or disable statistics for a specific column.
	*
	* @param[in] writer File writer
	* @param[in] column_index Column index
	* @param[in] enabled Whether to write statistics
	* @return CARQUET_OK on success
	*/
	carquet_writer_set_column_statistics :: proc(writer: ^carquet_writer_t, column_index: i32, enabled: bool) -> carquet_status_t ---

	/**
	* @brief Enable or disable bloom filter for a specific column.
	*
	* @param[in] writer File writer
	* @param[in] column_index Column index
	* @param[in] enabled Whether to write a bloom filter
	* @return CARQUET_OK on success
	*/
	carquet_writer_set_column_bloom_filter :: proc(writer: ^carquet_writer_t, column_index: i32, enabled: bool) -> carquet_status_t ---

	/**
	* @brief Enable or disable a bloom filter for a column with explicit sizing.
	*
	* Like carquet_writer_set_column_bloom_filter() but additionally lets the
	* caller control the expected number of distinct values (NDV) and the target
	* false-positive probability (FPP) used to size the filter.
	*
	* Using this for any column switches bloom emission to per-column opt-in: only
	* columns enabled through this function or through
	* carquet_writer_set_column_bloom_filter() get a filter. Columns left untouched
	* do not gain a default filter even though enabling one here turns the global
	* write_bloom_filters flag on. The two setters compose freely and may be mixed.
	*
	* @param[in] writer File writer
	* @param[in] column_index Column index
	* @param[in] enabled Whether to write a bloom filter
	* @param[in] ndv Expected number of distinct values (<= 0 => use default)
	* @param[in] fpp Target false-positive probability in (0, 1)
	*                (<= 0 or >= 1 => use default 0.01)
	* @return CARQUET_OK on success
	*/
	carquet_writer_set_column_bloom_filter_options :: proc(writer: ^carquet_writer_t, column_index: i32, enabled: bool, ndv: i64, fpp: f64) -> carquet_status_t ---
}

/**
* @brief Describes a column's contribution to a row group's sort order.
*
* Mirrors the Parquet Thrift `SortingColumn` structure.
*/
carquet_sorting_column :: struct {
	column_index: i32,  /**< Ordinal position of the column in the row group */
	descending:   bool, /**< true => column is sorted in descending order */
	nulls_first:  bool, /**< true => nulls sort before non-null values */
}

/**
* @brief Describes a column's contribution to a row group's sort order.
*
* Mirrors the Parquet Thrift `SortingColumn` structure.
*/
carquet_sorting_column_t :: carquet_sorting_column

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Declare the sort order of row groups.
	*
	* The supplied list is recorded in the `sorting_columns` metadata of every
	* row group written by this writer (matching PyArrow's behavior). This only
	* declares the order; the writer does not sort or verify the data. Pass
	* count == 0 to clear a previously set order.
	*
	* @param[in] writer File writer
	* @param[in] columns Array of sorting column descriptors (copied)
	* @param[in] count Number of entries in @p columns
	* @return CARQUET_OK on success
	*/
	carquet_writer_set_sorting_columns :: proc(writer: ^carquet_writer_t, columns: ^carquet_sorting_column_t, count: i32) -> carquet_status_t ---

	/**
	* @brief Create a writer that writes to an internal memory buffer.
	*
	* After closing the writer with carquet_writer_close(), retrieve the
	* buffer contents with carquet_writer_get_buffer().
	*
	* @param[in] schema File schema
	* @param[in] options Writer options (may be NULL)
	* @param[out] error Error information (may be NULL)
	* @return Writer handle, or NULL on error
	*/
	carquet_writer_create_buffer :: proc(schema: ^carquet_schema_t, options: ^carquet_writer_options_t, error: ^carquet_error_t) -> ^carquet_writer_t ---

	/**
	* @brief Get the buffer contents after writing.
	*
	* Must be called after carquet_writer_close(). The buffer is owned by the
	* caller and must be freed with free().
	*
	* @param[in] writer Writer (must have been created with create_buffer)
	* @param[out] buffer Output pointer to buffer data
	* @param[out] size Output buffer size in bytes
	* @return CARQUET_OK on success
	*/
	carquet_writer_get_buffer :: proc(writer: ^carquet_writer_t, buffer: ^rawptr, size: ^c.size_t) -> carquet_status_t ---
}

ARROW_FLAG_DICTIONARY_ORDERED :: 1
ARROW_FLAG_NULLABLE           :: 2
ARROW_FLAG_MAP_KEYS_SORTED    :: 4

ArrowSchema :: struct {
	format:       cstring,
	name:         cstring,
	metadata:     cstring,
	flags:        i64,
	n_children:   i64,
	children:     ^^ArrowSchema,
	dictionary:   ^ArrowSchema,
	release:      proc "c" (^ArrowSchema),
	private_data: rawptr,
}

ArrowArray :: struct {
	length:       i64,
	null_count:   i64,
	offset:       i64,
	n_buffers:    i64,
	n_children:   i64,
	buffers:      ^rawptr,
	children:     ^^ArrowArray,
	dictionary:   ^ArrowArray,
	release:      proc "c" (^ArrowArray),
	private_data: rawptr,
}

@(default_calling_convention="c")
foreign carquet {
	/**
	* @brief Export a flat Carquet schema as an Arrow C Data Interface schema.
	*
	* Produces a top-level struct schema (`format = "+s"`) whose children are the
	* schema's leaf columns, in order. Each child's `format` string encodes the
	* Arrow type derived from the column's physical + logical type; `name` is the
	* column name; ARROW_FLAG_NULLABLE is set for non-REQUIRED columns.
	*
	* @param[in] schema Flat (non-nested) schema. A leaf with `max_rep_level > 0`
	*                   is rejected.
	* @param[out] out Uninitialised ArrowSchema to populate. On success the caller
	*                 owns it and must call `out->release(out)`.
	* @param[out] error Error details (may be NULL).
	* @return CARQUET_OK, or an error (INVALID_ARGUMENT / NOT_IMPLEMENTED /
	*         OUT_OF_MEMORY). On error @p out is left released (untouched).
	*/
	/* No CARQUET_NONNULL: these are an external ABI boundary (Arrow structs may
	* originate from other-language producers), so the runtime NULL checks are
	* intentional and must not be optimised away. */
	carquet_arrow_export_schema :: proc(schema: ^carquet_schema_t, out: ^ArrowSchema, error: ^carquet_error_t) -> carquet_status_t ---

	/**
	* @brief Export a flat Carquet row batch as an Arrow C Data Interface array.
	*
	* Produces a top-level struct array whose children are the batch columns. Every
	* buffer is a freshly allocated copy owned by @p out_array, so the export
	* survives freeing the source batch or advancing the batch reader.
	*
	* Buffer layout per child follows the Arrow spec:
	* - primitive fixed-width: `[validity, data]`
	* - BOOLEAN: `[validity, data]` with the data buffer bit-packed (LSB-first)
	* - UTF8 / binary (BYTE_ARRAY): `[validity, offsets(int32), data]`
	* - fixed-size binary (FIXED_LEN_BYTE_ARRAY): `[validity, data]`
	*
	* The @p schema supplies column names, logical types, and nullability; its leaf
	* column count must equal the batch column count (batch read without column
	* projection). Dictionary-preserved batch columns are rejected.
	*
	* @param[in] batch Source row batch.
	* @param[in] schema Matching flat schema (leaf count == batch columns).
	* @param[out] out_schema Optional ArrowSchema for the batch (may be NULL); when
	*                        non-NULL, caller must release it.
	* @param[out] out_array ArrowArray to populate; caller must release.
	* @param[out] error Error details (may be NULL).
	* @return CARQUET_OK or an error. On error nothing is left owned by the caller.
	*/
	carquet_arrow_export_batch :: proc(batch: ^carquet_row_batch_t, schema: ^carquet_schema_t, out_schema: ^ArrowSchema, out_array: ^ArrowArray, error: ^carquet_error_t) -> carquet_status_t ---

	/**
	* @brief Build a Carquet schema from an Arrow C Data Interface schema.
	*
	* Accepts a top-level struct schema (`format = "+s"`) and creates a flat
	* Carquet schema whose columns mirror the struct's children. Each child's Arrow
	* `format` string is mapped back to a Carquet physical + logical type; the
	* ARROW_FLAG_NULLABLE flag selects OPTIONAL vs REQUIRED.
	*
	* Consumes @p schema: its `release` callback is called before returning
	* (success or failure). Nested children are rejected with
	* CARQUET_ERROR_NOT_IMPLEMENTED.
	*
	* @param[in] schema Arrow struct schema to import (consumed).
	* @param[out] out Receives a new carquet_schema_t; free with carquet_schema_free.
	* @param[out] error Error details (may be NULL).
	* @return CARQUET_OK or an error.
	*/
	carquet_arrow_import_schema :: proc(schema: ^ArrowSchema, out: ^^carquet_schema_t, error: ^carquet_error_t) -> carquet_status_t ---

	/**
	* @brief Write an Arrow C Data Interface array to a Carquet writer.
	*
	* Accepts a top-level struct array (from any Arrow C Data Interface exporter)
	* and writes each child column to @p writer via the normal column batch path —
	* converting Arrow validity bitmaps to Parquet definition levels and compacting
	* values as required. The array's children map positionally to the writer's
	* columns; the child count must equal the writer column count.
	*
	* Consumes both @p array and @p schema: their `release` callbacks are called
	* before returning (success or failure). Nested / dictionary children are
	* rejected.
	*
	* @param[in] writer Target writer.
	* @param[in] array Arrow struct array to write (consumed).
	* @param[in] schema Arrow schema describing @p array (consumed).
	* @param[out] error Error details (may be NULL).
	* @return CARQUET_OK or an error.
	*/
	carquet_writer_write_arrow :: proc(writer: ^carquet_writer_t, array: ^ArrowArray, schema: ^ArrowSchema, error: ^carquet_error_t) -> carquet_status_t ---

	/**
	* @brief Read one Parquet row group directly into a nested Arrow C Data array.
	*
	* Reassembles the row group as a top-level Arrow struct array whose children
	* are the file's top-level fields, reconstructing struct, list, large-list and
	* map nesting to any depth from the columns' repetition/definition levels. This
	* is the read-side counterpart to @ref carquet_writer_write_arrow and handles
	* the full nesting the flat @ref carquet_arrow_export_batch cannot.
	*
	* Every buffer is a freshly allocated copy owned by @p out_array (and
	* @p out_schema when requested), so the result outlives @p reader. The consumer
	* takes ownership and must call `out_array->release(out_array)` (and the schema
	* release if requested) exactly once.
	*
	* @param[in] reader Open reader.
	* @param[in] row_group_index Row group to read (0-based).
	* @param[out] out_schema Optional ArrowSchema for the file (may be NULL); when
	*                        non-NULL the caller must release it.
	* @param[out] out_array ArrowArray to populate; caller must release.
	* @param[out] error Error details (may be NULL).
	* @return CARQUET_OK or an error. On error nothing is left owned by the caller.
	*/
	carquet_reader_read_arrow :: proc(reader: ^carquet_reader_t, row_group_index: i32, out_schema: ^ArrowSchema, out_array: ^ArrowArray, error: ^carquet_error_t) -> carquet_status_t ---
}

