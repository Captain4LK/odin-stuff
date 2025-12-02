package main

import "core:log"
import "core:strings"
import "core:path/filepath"
import "core:math"

import "../prof"

palette_load :: proc(path: string, colours: ^[256][4]u8, colour_count: ^i32)
{
   prof.SCOPED_EVENT(#procedure)

   if len(path) == 0 do return

   ext: string = filepath.ext(path)
   ext_lower: string = strings.to_lower(ext)
   defer delete(ext_lower)

   if strings.compare(ext_lower, "pal") == 0
   {
   }
}
