package main

import "core:mem"

import "../prof"

Image8 :: struct
{
   width: i32,
   height: i32,
   colour_count: u32,
   palette: [256][4]u8,
   data: [0]u8,
}

Image32 :: struct
{
   width: i32,
   height: i32,
   data: [0][4]u8,
}

Image64 :: struct
{
   width: i32,
   height: i32,
   data: [0][4]u16,
}

image8_new :: proc(width: i32, height: i32) -> ^Image8
{
   prof.SCOPED_EVENT(#procedure)

   if width <= 0 || height <= 0 do return nil

   data, err := mem.alloc(size_of(Image8) + int(width) * int(height))
   img: ^Image8 = cast(^Image8)data
   img.width = width
   img.height = height
   img.colour_count = 256

   return img
}

image8_dup :: proc(src: ^Image8) -> ^Image8
{
   prof.SCOPED_EVENT(#procedure)

   if src == nil || src.width <= 0 || src.height <= 0 do return nil

   img: ^Image8 = image8_new(src.width, src.height)
   img.colour_count = src.colour_count
   
   mem.copy(raw_data(img.palette[:]), raw_data(src.palette[:]), 4 * 256)
   mem.copy(raw_data(img.data[:]), raw_data(src.data[:]), int(img.width) * int(img.height) * 1)

   return img
}

image32_new :: proc(width: i32, height: i32) -> ^Image32
{
   prof.SCOPED_EVENT(#procedure)

   if width <= 0 || height <= 0 do return nil

   data, err := mem.alloc(size_of(Image8) + int(width) * int(height) * 4)
   img: ^Image32 = cast(^Image32)data
   img.width = width
   img.height = height

   return img
}

image32_dup :: proc(src: ^Image32) -> ^Image32
{
   prof.SCOPED_EVENT(#procedure)

   if src == nil || src.width <= 0 || src.height <= 0 do return nil

   img: ^Image32 = image32_new(src.width, src.height)
   mem.copy(raw_data(img.data[:]), raw_data(src.data[:]), int(img.width) * int(img.height) * 4)

   return img
}

image32_from_64 :: proc(img64: ^Image64) -> ^Image32
{
   img32: ^Image32 = image32_new(img64.width, img64.height)

   #no_bounds_check for i in 0 ..< int(img64.width) * int(img64.height)
   {
      pix64: [4]u16 = img64.data[i]
      pix32: [4]u8
      pix32[0] = u8(pix64[0] / 128)
      pix32[1] = u8(pix64[1] / 128)
      pix32[2] = u8(pix64[2] / 128)
      pix32[3] = u8(pix64[3] / 128)

      img32.data[i] = pix32
   }

   return img32
}

image32_get :: proc(img: ^Image32, x: i32, y: i32, default: [4]u8) -> [4]u8 #no_bounds_check
{
   if x < 0 || x >= img.width do return default
   if y < 0 || y >= img.height do return default

   return img.data[y * img.width + x]
}

image64_new :: proc(width: i32, height: i32) -> ^Image64
{
   prof.SCOPED_EVENT(#procedure)

   if width <= 0 || height <= 0 do return nil

   data, err := mem.alloc(size_of(Image8) + int(width) * int(height) * 8)
   img: ^Image64 = cast(^Image64)data
   img.width = width
   img.height = height

   return img
}

image64_dup :: proc(src: ^Image64) -> ^Image64
{
   prof.SCOPED_EVENT(#procedure)

   if src == nil || src.width <= 0 || src.height <= 0 do return nil

   img: ^Image64 = image64_new(src.width, src.height)
   mem.copy(raw_data(img.data[:]), raw_data(src.data[:]), int(img.width) * int(img.height) * 8)

   return img
}

image64_from_32 :: proc(img32: ^Image32) -> ^Image64
{
   img64: ^Image64 = image64_new(img32.width, img32.height)

   #no_bounds_check for i in 0 ..< int(img32.width) * int(img32.height)
   {
      pix32: [4]u8 = img32.data[i]
      pix64: [4]u16
      pix64[0] = u16(pix32[0]) * 128
      pix64[1] = u16(pix32[1]) * 128
      pix64[2] = u16(pix32[2]) * 128
      pix64[3] = u16(pix32[3]) * 128

      img64.data[i] = pix64
   }

   return img64
}

image64_get :: proc(img: ^Image64, x: i32, y: i32, default: [4]u16) -> [4]u16 #no_bounds_check
{
   if x < 0 || x >= img.width do return default
   if y < 0 || y >= img.height do return default

   return img.data[y * img.width + x]
}
