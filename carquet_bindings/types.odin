/**
 * @file types.h
 * @brief Parquet physical and logical type definitions
 *
 * This header defines all Parquet data types according to the Apache Parquet
 * specification. Types are organized into physical types (storage format) and
 * logical types (semantic interpretation).
 */
package carquet_bindings
foreign import carquet "libcarquet.a"

/* ============================================================================
* Physical Types
* ============================================================================
* Physical types represent how data is stored on disk. Parquet supports a
* limited set of physical types to keep the format simple.
*/
carquet_physical_type :: enum u32 {
	BOOLEAN              = 0,
	INT32                = 1,
	INT64                = 2,
	INT96                = 3, /* Deprecated, used for timestamps */
	FLOAT                = 4,
	DOUBLE               = 5,
	BYTE_ARRAY           = 6,
	FIXED_LEN_BYTE_ARRAY = 7,
}

/* ============================================================================
* Physical Types
* ============================================================================
* Physical types represent how data is stored on disk. Parquet supports a
* limited set of physical types to keep the format simple.
*/
carquet_physical_type_t :: carquet_physical_type

/* ============================================================================
* Logical Types (ConvertedType - legacy)
* ============================================================================
* Legacy converted types for backwards compatibility.
*/
carquet_converted_type :: enum i32 {
	NONE             = -1,
	UTF8             = 0,
	MAP              = 1,
	MAP_KEY_VALUE    = 2,
	LIST             = 3,
	ENUM             = 4,
	DECIMAL          = 5,
	DATE             = 6,
	TIME_MILLIS      = 7,
	TIME_MICROS      = 8,
	TIMESTAMP_MILLIS = 9,
	TIMESTAMP_MICROS = 10,
	UINT_8           = 11,
	UINT_16          = 12,
	UINT_32          = 13,
	UINT_64          = 14,
	INT_8            = 15,
	INT_16           = 16,
	INT_32           = 17,
	INT_64           = 18,
	JSON             = 19,
	BSON             = 20,
	INTERVAL         = 21,
}

/* ============================================================================
* Logical Types (ConvertedType - legacy)
* ============================================================================
* Legacy converted types for backwards compatibility.
*/
carquet_converted_type_t :: carquet_converted_type

/* ============================================================================
* Logical Types (Modern)
* ============================================================================
* Modern logical type system with more detailed type information.
*/
carquet_logical_type_id :: enum u32 {
	UNKNOWN   = 0,
	STRING    = 1,
	MAP       = 2,
	LIST      = 3,
	ENUM      = 4,
	DECIMAL   = 5,
	DATE      = 6,
	TIME      = 7,
	TIMESTAMP = 8,
	INTEGER   = 9,
	NULL      = 10,
	JSON      = 11,
	BSON      = 12,
	UUID      = 13,
	FLOAT16   = 14,
	VARIANT   = 15,
	GEOMETRY  = 16,
	GEOGRAPHY = 17,

	/* INTERVAL has no modern LogicalType; it is ConvertedType-only and
	requires FIXED_LEN_BYTE_ARRAY with type_length == 12. */
	INTERVAL  = 18,
}

/* ============================================================================
* Logical Types (Modern)
* ============================================================================
* Modern logical type system with more detailed type information.
*/
carquet_logical_type_id_t :: carquet_logical_type_id

/* Time unit for temporal types */
carquet_time_unit :: enum u32 {
	MILLIS = 0,
	MICROS = 1,
	NANOS  = 2,
}

/* Time unit for temporal types */
carquet_time_unit_t :: carquet_time_unit

CARQUET_GEOSPATIAL_CRS_MAX :: 128

carquet_geospatial_edge_algorithm :: enum u32 {
	SPHERICAL = 0,
	VINCENTY  = 1,
	THOMAS    = 2,
	ANDOYER   = 3,
	KARNEY    = 4,
}

carquet_geospatial_edge_algorithm_t :: carquet_geospatial_edge_algorithm

/* Logical type with parameters */
carquet_logical_type :: struct {
	id: carquet_logical_type_id_t,

	params: struct #raw_union {
		decimal: struct {
			precision: i32,
			scale:     i32,
		},

		integer: struct {
			bit_width: i8, /* 8, 16, 32, or 64 */
			is_signed: bool,
		},

		time: struct {
			unit:               carquet_time_unit_t,
			is_adjusted_to_utc: bool,
		},

		timestamp: struct {
			unit:               carquet_time_unit_t,
			is_adjusted_to_utc: bool,
		},

		variant: struct {
			specification_version: i8, /* 1 when unset/zero */
		},

		geometry: struct {
			crs: [128]i8, /* Optional, empty => OGC:CRS84 */
		},

		geography: struct {
			crs:           [128]i8, /* Optional, empty => OGC:CRS84 */
			algorithm:     carquet_geospatial_edge_algorithm_t,
			has_algorithm: bool,    /* false => SPHERICAL */
		},
	},
}

/* Logical type with parameters */
carquet_logical_type_t :: carquet_logical_type

/* ============================================================================
* Field Repetition
* ============================================================================
*/
carquet_field_repetition :: enum u32 {
	REQUIRED = 0, /* Exactly one value */
	OPTIONAL = 1, /* Zero or one value */
	REPEATED = 2, /* Zero or more values */
}

/* ============================================================================
* Field Repetition
* ============================================================================
*/
carquet_field_repetition_t :: carquet_field_repetition

/* ============================================================================
* Encoding Types
* ============================================================================
*/
carquet_encoding :: enum u32 {
	PLAIN                   = 0,
	PLAIN_DICTIONARY        = 2, /* Deprecated */
	RLE                     = 3,
	BIT_PACKED              = 4, /* Deprecated */
	DELTA_BINARY_PACKED     = 5,
	DELTA_LENGTH_BYTE_ARRAY = 6,
	DELTA_BYTE_ARRAY        = 7,
	RLE_DICTIONARY          = 8,
	BYTE_STREAM_SPLIT       = 9,
}

/* ============================================================================
* Encoding Types
* ============================================================================
*/
carquet_encoding_t :: carquet_encoding

/* ============================================================================
* Compression Codecs
* ============================================================================
*/
carquet_compression :: enum u32 {
	UNCOMPRESSED = 0,
	SNAPPY       = 1,
	GZIP         = 2,
	LZO          = 3,
	BROTLI       = 4,
	LZ4          = 5,
	ZSTD         = 6,
	LZ4_RAW      = 7,
}

/* ============================================================================
* Compression Codecs
* ============================================================================
*/
carquet_compression_t :: carquet_compression

/* ============================================================================
* Page Types
* ============================================================================
*/
carquet_page_type :: enum u32 {
	DATA       = 0,
	INDEX      = 1,
	DICTIONARY = 2,
	DATA_V2    = 3,
}

/* ============================================================================
* Page Types
* ============================================================================
*/
carquet_page_type_t :: carquet_page_type

/* Fixed-length byte array */
carquet_fixed_byte_array :: struct {
	data:   ^u8,
	length: i32,
}

/* Fixed-length byte array */
carquet_fixed_byte_array_t :: carquet_fixed_byte_array

/* Variable-length byte array */
carquet_byte_array :: struct {
	data:   ^u8,
	length: i32,
}

/* Variable-length byte array */
carquet_byte_array_t :: carquet_byte_array

/* INT96 (deprecated, for legacy timestamp support) */
carquet_int96 :: struct {
	value: [3]u32,
}

/* INT96 (deprecated, for legacy timestamp support) */
carquet_int96_t :: carquet_int96

/* Decimal value (for high-precision decimals) */
carquet_decimal128 :: struct {
	low:  i64,
	high: i64,
}

/* Decimal value (for high-precision decimals) */
carquet_decimal128_t :: carquet_decimal128

@(default_calling_convention="c")
foreign carquet {
	/**
	* Get a human-readable name for a physical type.
	*/
	carquet_physical_type_name :: proc(type: carquet_physical_type_t) -> cstring ---

	/**
	* Get a human-readable name for a compression codec.
	*/
	carquet_compression_name :: proc(codec: carquet_compression_t) -> cstring ---

	/**
	* Get a human-readable name for an encoding.
	*/
	carquet_encoding_name :: proc(encoding: carquet_encoding_t) -> cstring ---
}

