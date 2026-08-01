/**
 * @file error.h
 * @brief Error handling for Carquet library
 *
 * This header provides error codes and error handling utilities.
 * All Carquet functions that can fail return an error code or use
 * the carquet_error_t structure for detailed error information.
 */
package carquet_bindings

foreign import carquet "libcarquet.a"
import "core:c"


/* ============================================================================
* Error Codes
* ============================================================================
*/
carquet_status :: enum u32 {
	/* Success */
	OK                            = 0,

	/* General errors */
	ERROR_INVALID_ARGUMENT        = 1,
	ERROR_OUT_OF_MEMORY           = 2,
	ERROR_NOT_IMPLEMENTED         = 3,
	ERROR_INTERNAL                = 4,

	/* File I/O errors */
	ERROR_FILE_NOT_FOUND          = 10,
	ERROR_FILE_OPEN               = 11,
	ERROR_FILE_READ               = 12,
	ERROR_FILE_WRITE              = 13,
	ERROR_FILE_SEEK               = 14,
	ERROR_FILE_TRUNCATED          = 15,

	/* Format errors */
	ERROR_INVALID_MAGIC           = 20,
	ERROR_INVALID_FOOTER          = 21,
	ERROR_INVALID_SCHEMA          = 22,
	ERROR_INVALID_METADATA        = 23,
	ERROR_INVALID_PAGE            = 24,
	ERROR_INVALID_ENCODING        = 25,
	ERROR_VERSION_NOT_SUPPORTED   = 26,

	/* Thrift parsing errors */
	ERROR_THRIFT_DECODE           = 30,
	ERROR_THRIFT_ENCODE           = 31,
	ERROR_THRIFT_INVALID_TYPE     = 32,
	ERROR_THRIFT_TRUNCATED        = 33,

	/* Encoding/decoding errors */
	ERROR_DECODE                  = 40,
	ERROR_ENCODE                  = 41,
	ERROR_DICTIONARY_NOT_FOUND    = 42,
	ERROR_INVALID_RLE             = 43,
	ERROR_INVALID_DELTA           = 44,

	/* Compression errors */
	ERROR_COMPRESSION             = 50,
	ERROR_DECOMPRESSION           = 51,
	ERROR_UNSUPPORTED_CODEC       = 52,
	ERROR_INVALID_COMPRESSED_DATA = 53,

	/* Data errors */
	ERROR_TYPE_MISMATCH           = 60,
	ERROR_COLUMN_NOT_FOUND        = 61,
	ERROR_ROW_GROUP_NOT_FOUND     = 62,
	ERROR_END_OF_DATA             = 63,

	/* Checksum errors */
	ERROR_CHECKSUM                = 70,
	ERROR_CRC_MISMATCH            = 71,

	/* State errors */
	ERROR_INVALID_STATE           = 80,
	ERROR_ALREADY_CLOSED          = 81,
	ERROR_NOT_OPEN                = 82,

	/* Filter / page-index errors */
	ERROR_PAGE_INDEX_REQUIRED     = 90,
}

/* ============================================================================
* Error Codes
* ============================================================================
*/
carquet_status_t :: carquet_status

/* ============================================================================
* Error Context
* ============================================================================
* Detailed error information for debugging.
*/
CARQUET_ERROR_MESSAGE_MAX :: 256

carquet_error :: struct {
	code:    carquet_status_t,
	message: [256]i8,

	/* Location information (optional) */
	file:     cstring,
	line:     i32,
	function: cstring,

	/* Additional context */
	offset:          i64, /* File offset where error occurred */
	column_index:    i32, /* Column index if applicable */
	row_group_index: i32, /* Row group index if applicable */
}

carquet_error_t :: carquet_error

@(default_calling_convention="c")
foreign carquet {
	/**
	* Initialize an error structure.
	*/
	carquet_error_init :: proc(error: ^carquet_error_t) ---

	/**
	* Clear an error structure (reset to success state).
	*/
	carquet_error_clear :: proc(error: ^carquet_error_t) ---
	carquet_error_set   :: proc(error: ^carquet_error_t, code: carquet_status_t, file: cstring, line: i32, function: cstring, format: cstring, #c_vararg _: ..any) ---

	/**
	* Copy error from source to destination.
	*/
	carquet_error_copy :: proc(dest: ^carquet_error_t, src: ^carquet_error_t) ---

	/**
	* Get a human-readable description of a status code.
	*/
	carquet_status_string :: proc(status: carquet_status_t) -> cstring ---

	/**
	* Get a recovery hint for a status code.
	* Returns NULL if no hint is available.
	*/
	carquet_error_recovery_hint :: proc(status: carquet_status_t) -> cstring ---

	/**
	* Format an error into a human-readable string.
	*
	* The output includes:
	* - Status code name and message
	* - File offset, row group, and column context (if set)
	* - Recovery hint (if available)
	*
	* @param error The error to format
	* @param buffer Output buffer
	* @param buffer_size Size of output buffer
	* @return Number of characters written (excluding null terminator)
	*/
	carquet_error_format :: proc(error: ^carquet_error_t, buffer: cstring, buffer_size: c.size_t) -> i32 ---

	/**
	* Set additional context on an error.
	*
	* @param error The error to modify
	* @param offset File offset where error occurred (-1 to skip)
	* @param row_group_index Row group index (-1 to skip)
	* @param column_index Column index (-1 to skip)
	*/
	carquet_error_set_context :: proc(error: ^carquet_error_t, offset: i64, row_group_index: i32, column_index: i32) ---

	/**
	* Check if an error might be recoverable.
	*
	* Some errors (like file corruption) are not recoverable, while
	* others (like temporary I/O errors) might succeed on retry.
	*
	* @param status The status code to check
	* @return true if the error might be recoverable
	*/
	carquet_error_is_recoverable :: proc(status: carquet_status_t) -> bool ---
}

/* Common result types */
carquet_result_i32 :: struct {
	status: carquet_status_t,
	value:  i32,
}

/* Common result types */
carquet_result_i32_t :: carquet_result_i32

carquet_result_i64 :: struct {
	status: carquet_status_t,
	value:  i64,
}

carquet_result_i64_t :: carquet_result_i64

carquet_result_size :: struct {
	status: carquet_status_t,
	value:  c.size_t,
}

carquet_result_size_t :: carquet_result_size

carquet_result_ptr :: struct {
	status: carquet_status_t,
	value:  rawptr,
}

carquet_result_ptr_t :: carquet_result_ptr

