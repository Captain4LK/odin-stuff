package main

import "core:log"
import "core:math"

import "../prof"

colour64_to_32 :: proc(c64: [4]u16) -> [4]u8
{
   c32: [4]u8
   c32[0] = u8(c64[0] / 128)
   c32[1] = u8(c64[1] / 128)
   c32[2] = u8(c64[2] / 128)
   c32[3] = u8(c64[3] / 128)

   return c32
}

colour32_to_64 :: proc(c32: [4]u8) -> [4]u16
{
   c64: [4]u16
   c64[0] = u16(c32[0]) * 128
   c64[1] = u16(c32[1]) * 128
   c64[2] = u16(c32[2]) * 128
   c64[3] = u16(c32[3]) * 128

   return c64
}
