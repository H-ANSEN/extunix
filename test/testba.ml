
open OUnit
open ExtUnix.All.BA
module LargeFile = ExtUnix.All.LargeFile.BA

let with_unix_error f () =
  try
    f ()
  with
  | Unix.Unix_error(e,f,a) ->
    let message = Printf.sprintf "Unix_error : %s(%s) : %s" f a (Unix.error_message e) in
    skip_if (e = Unix.ENOSYS) message; (* libc may raise Not implemented, not an error in extunix *)
    assert_failure message

let require feature =
  match ExtUnix.All.have feature with
  | None -> assert false
  | Some present -> skip_if (not present) (Printf.sprintf "%S is not available" feature)

let printer x = x

let test_endian_bigarray () =
  require "unsafe_get_int8";
  require "unsafe_get_int16";
  require "unsafe_get_int31";
  require "unsafe_get_int32";
  require "unsafe_get_int64";
  require "unsafe_get_uint8";
  require "unsafe_get_uint16";
  require "unsafe_get_uint31";
  require "unsafe_get_uint63";
  require "unsafe_get_int63";
  require "unsafe_set_uint8";
  require "unsafe_set_uint16";
  require "unsafe_set_uint31";
  require "unsafe_set_int8";
  require "unsafe_set_int16";
  require "unsafe_set_int31";
  require "unsafe_set_int32";
  require "unsafe_set_uint63";
  require "unsafe_set_int63";
  require "unsafe_set_int64";
  let module B = BigEndian in
  let module L = LittleEndian in
  let src = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout 18 in
  ignore (List.fold_left (fun off x -> Bigarray.Array1.set src off x; off + 1)
	    0
	    [0xFF;
	     0xFF;
	     0xFE; 0xDC;
	     0xFE; 0xDC;
	     0xFE; 0xDC; 0xBA; 0x98;
	     0xFE; 0xDC; 0xBA; 0x98; 0x76; 0x54; 0x32; 0x10]);
  assert_equal (B.get_uint8  src  0) 0xFF;
  assert_equal (B.get_int8   src  1) (-0x01);
  assert_equal (B.get_uint16 src  2) 0xFEDC;
  assert_equal (B.get_int16  src  4) (-0x0124);
  assert_equal (B.get_int32  src  6) (0xFEDCBA98l);
  assert_equal (B.get_int64  src 10) (0xFEDCBA9876543210L);
  assert_equal (L.get_uint8  src  0) 0xFF;
  assert_equal (L.get_int8   src  1) (-0x01);
  assert_equal (L.get_uint16 src  2) 0xDCFE;
  assert_equal (L.get_int16  src  4) (-0x2302);
  assert_equal (L.get_int32  src  6) (0x98BADCFEl);
  assert_equal (L.get_int64  src 10) (0x1032547698BADCFEL);
  assert_equal (B.get_uint31 src  6) (Int64.to_int 0xFEDCBA98L);
  assert_equal (B.get_int31  src  6) (Int64.to_int 0x7FFFFFFFFEDCBA98L);
  assert_equal (B.get_int31  src  6) (-0x1234568);
  assert_equal (B.get_uint63 src 10) (Int64.to_int 0x7EDCBA9876543210L);
  assert_equal (B.get_int63  src 10) (Int64.to_int 0x7EDCBA9876543210L);
  assert_equal (B.get_int63  src 10) (Int64.to_int (-0x123456789ABCDF0L));
  assert_equal (L.get_uint31 src  6) (Int64.to_int 0x98BADCFEL);
  assert_equal (L.get_int31  src  6) (Int64.to_int 0x7FFFFFFF98BADCFEL);
  assert_equal (L.get_int31  src  6) (-0x67452302);
  assert_equal (L.get_uint63 src 10) (Int64.to_int 0x1032547698BADCFEL);
  assert_equal (L.get_int63  src 10) (Int64.to_int 0x1032547698BADCFEL);
  assert_equal (L.get_int63  src 10) (Int64.to_int (-0x6FCDAB8967452302L));
  let b = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout 18 in
  B.set_uint8  b  0 0xFF;
  B.set_int8   b  1 (-0x01);
  B.set_uint16 b  2 0xFEDC;
  B.set_uint16 b  4 (-0x0124);
  B.set_int32  b  6 (0xFEDCBA98l);
  B.set_int64  b 10 (0xFEDCBA9876543210L);
  assert_equal b src;
  let l = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout 18 in
  L.set_uint8  l  0 0xFF;
  L.set_int8   l  1 (-0x01);
  L.set_uint16 l  2 0xDCFE;
  L.set_uint16 l  4 (-0x2302);
  L.set_int32  l  6 (0x98BADCFEl);
  L.set_int64  l 10 (0x1032547698BADCFEL);
  assert_equal l src

let cmp_buf buf c text =
  for i = 0 to Bigarray.Array1.dim buf - 1 do
    if Bigarray.Array1.get buf i <> (int_of_char c)
    then assert_failure text;
  done

let test_pread_bigarray () =
  require "unsafe_pread";
  let name = Filename.temp_file "extunix" "pread" in
  let fd =
    Unix.openfile name [Unix.O_RDWR] 0
  in
  try
    let size = 65536 in
    let s = String.make size 'x' in
    assert_equal (Unix.write_substring fd s 0 size) size;
    let t = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout size in
    assert_equal (pread fd 0 t) size;
    cmp_buf t 'x' "pread read bad data";
    assert_equal (single_pread fd 0 t) size;
    cmp_buf t 'x' "pread read bad data";
    let t = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout size in
    assert_equal (LargeFile.pread fd Int64.zero t) size;
    cmp_buf t 'x' "Largefile.pread read bad data";
    assert_equal (LargeFile.single_pread fd Int64.zero t) size;
    cmp_buf t 'x' "Largefile.single_pread read bad data";
    Unix.close fd;
    Unix.unlink name
  with exn -> Unix.close fd; Unix.unlink name; raise exn

let cmp_bytes str c text =
  for i = 0 to Bytes.length str - 1 do
    if Bytes.get str i <> c
    then assert_failure text;
  done

let test_pwrite_bigarray () =
  require "unsafe_pwrite";
  let name = Filename.temp_file "extunix" "pwrite" in
  let fd =
    Unix.openfile name [Unix.O_RDWR] 0
  in
  let read dst =
    assert_equal (Unix.lseek fd 0 Unix.SEEK_SET) 0;
    let rec loop off = function
      | 0 -> ()
      | size ->
        let len = Unix.read fd dst off size
        in
        loop (off + len) (size - len)
    in
    loop 0 (Bytes.length dst)
  in
  try
    let size = 65536 in (* Must be larger than UNIX_BUFFER_SIZE (16384) *)
    let s = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout size in
    for i = 0 to size - 1 do
      Bigarray.Array1.set s i (int_of_char 'x');
    done;
    assert_equal (pwrite fd 0 s) size;
    let t = Bytes.make size ' ' in
    read t;
    cmp_bytes t 'x' "pwrite wrote bad data";
    assert_equal (single_pwrite fd 0 s) size;
    read t;
    cmp_bytes t 'x' "single_pwrite wrote bad data";
    for i = 0 to size - 1 do
      Bigarray.Array1.set s i (int_of_char 'y');
    done;
    assert_equal (LargeFile.pwrite fd Int64.zero s) size;
    read t;
    cmp_bytes t 'y' "Largefile.pwrite wrote bad data";
    assert_equal (LargeFile.single_pwrite fd Int64.zero s) size;
    read t;
    cmp_bytes t 'y' "Largefile.single_pwrite wrote bad data";
    Unix.close fd;
    Unix.unlink name
  with exn -> Unix.close fd; Unix.unlink name; raise exn

let test_substr () =
  let arr = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout 12 in
  set_substr arr 0 "Hell";
  set_substr arr 4 "o World!";
  assert_equal (get_substr arr 0 6) "Hello ";
  assert_equal (get_substr arr 6 6) "World!"

let test_read_bigarray () =
  require "read";
  let name = Filename.temp_file "extunix" "read" in
  let fd =
    Unix.openfile name [Unix.O_RDWR] 0
  in
  try
    let size = 65536 in
    let s = String.make size 'x' in
    assert_equal (Unix.write_substring fd s 0 size) size;
    let t = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout size in
    assert_equal (Unix.lseek fd 0 Unix.SEEK_SET) 0;
    assert_equal (read fd t) size;
    cmp_buf t 'x' "read read bad data";
    assert_equal (Unix.lseek fd 0 Unix.SEEK_SET) 0;
    assert_equal (single_read fd t) size;
    cmp_buf t 'x' "single_read read bad data";
    Unix.close fd;
    Unix.unlink name
  with exn -> Unix.close fd; Unix.unlink name; raise exn

let test_write_bigarray () =
  require "write";
  let name = Filename.temp_file "extunix" "write" in
  let fd =
    Unix.openfile name [Unix.O_RDWR] 0
  in
  let read dst =
    assert_equal (Unix.lseek fd 0 Unix.SEEK_SET) 0;
    let rec loop off = function
      | 0 -> ()
      | size ->
        let len = Unix.read fd dst off size
        in
        loop (off + len) (size - len)
    in
    loop 0 (Bytes.length dst)
  in
  try
    let size = 65536 in (* Must be larger than UNIX_BUFFER_SIZE (16384) *)
    let s = Bigarray.Array1.create Bigarray.int8_unsigned Bigarray.c_layout size in
    for i = 0 to size - 1 do
      Bigarray.Array1.set s i (int_of_char 'x');
    done;
    assert_equal (write fd s) size;
    let t = Bytes.make size ' ' in
    read t;
    cmp_bytes t 'x' "write wrote bad data";
    assert_equal (single_write fd s) size;
    read t;
    cmp_bytes t 'x' "write wrote bad data";
    Unix.close fd;
    Unix.unlink name
  with exn -> Unix.close fd; Unix.unlink name; raise exn

let () =
  let wrap test =
    with_unix_error (fun () -> test (); Gc.compact ())
  in
  let tests = ("tests" >::: [
    "endian_bigrray" >:: test_endian_bigarray;
    "pread_bigarray" >:: test_pread_bigarray;
    "pwrite_bigarray" >:: test_pwrite_bigarray;
    "substr" >:: test_substr;
    "read_bigarray" >:: test_read_bigarray;
    "write_bigarray" >:: test_write_bigarray;
  ]) in
  ignore (run_test_tt_main (test_decorate wrap tests))

