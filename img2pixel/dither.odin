package main

import "core:log"
import "core:container/bit_array"
import "core:mem"
import "core:slice"
import "core:math"
import "core:math/linalg"

import "../prof"

@(private="file")
dither_threshold_none: [1]f32 = {0.5}

@(private="file")
dither_threshold_bayer8x8: [64]f32 = 
{
    0.0 / 64.0, 32.0 / 64.0,  8.0 / 64.0, 40.0 / 64.0,  2.0 / 64.0, 34.0 / 64.0, 10.0 / 64.0, 42.0 / 64.0, 
   48.0 / 64.0, 16.0 / 64.0, 56.0 / 64.0, 24.0 / 64.0, 50.0 / 64.0, 18.0 / 64.0, 58.0 / 64.0, 26.0 / 64.0, 
   12.0 / 64.0, 44.0 / 64.0,  4.0 / 64.0, 36.0 / 64.0, 14.0 / 64.0, 46.0 / 64.0,  6.0 / 64.0, 38.0 / 64.0, 
   60.0 / 64.0, 28.0 / 64.0, 52.0 / 64.0, 20.0 / 64.0, 62.0 / 64.0, 30.0 / 64.0, 54.0 / 64.0, 22.0 / 64.0, 
    3.0 / 64.0, 35.0 / 64.0, 11.0 / 64.0, 43.0 / 64.0,  1.0 / 64.0, 33.0 / 64.0,  9.0 / 64.0, 41.0 / 64.0, 
   51.0 / 64.0, 19.0 / 64.0, 59.0 / 64.0, 27.0 / 64.0, 49.0 / 64.0, 17.0 / 64.0, 57.0 / 64.0, 25.0 / 64.0, 
   15.0 / 64.0, 47.0 / 64.0,  7.0 / 64.0, 39.0 / 64.0, 13.0 / 64.0, 45.0 / 64.0,  5.0 / 64.0, 37.0 / 64.0, 
   63.0 / 64.0, 31.0 / 64.0, 55.0 / 64.0, 23.0 / 64.0, 61.0 / 64.0, 29.0 / 64.0, 53.0 / 64.0, 21.0 / 64.0, 
}

@(private="file")
dither_threshold_bayer4x4: [16]f32 = 
{
   0.0 / 16.0, 8.0 / 16.0, 2.0 / 16.0, 10.0 / 16.0, 
   12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0, 6.0 / 16.0, 
   3.0 / 16.0, 11.0 / 16.0, 1.0 / 16.0, 9.0 / 16.0, 
   15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0, 5.0 / 16.0, 
};

@(private="file")
dither_threshold_bayer2x2: [4]f32 = 
{
   0.0 / 4.0, 2.0 / 4.0, 
   3.0 / 4.0, 1.0 / 4.0,
};

@(private="file")
dither_threshold_cluster8x8: [64]f32 = 
{
   24.0 / 64.0, 10.0 / 64.0, 12.0 / 64.0, 26.0 / 64.0, 35.0 / 64.0, 47.0 / 64.0, 49.0 / 64.0, 37.0 / 64.0, 
   8.0 / 64.0, 0.0 / 64.0, 2.0 / 64.0, 14.0 / 64.0, 45.0 / 64.0, 59.0 / 64.0, 61.0 / 64.0, 51.0 / 64.0, 
   22.0 / 64.0, 6.0 / 64.0, 4.0 / 64.0, 16.0 / 64.0, 43.0 / 64.0, 57.0 / 64.0, 63.0 / 64.0, 53.0 / 64.0, 
   30.0 / 64.0, 20.0 / 64.0, 18.0 / 64.0, 28.0 / 64.0, 33.0 / 64.0, 41.0 / 64.0, 55.0 / 64.0, 39.0 / 64.0, 
   34.0 / 64.0, 46.0 / 64.0, 48.0 / 64.0, 36.0 / 64.0, 25.0 / 64.0, 11.0 / 64.0, 13.0 / 64.0, 27.0 / 64.0, 
   44.0 / 64.0, 58.0 / 64.0, 60.0 / 64.0, 50.0 / 64.0, 9.0 / 64.0, 1.0 / 64.0, 3.0 / 64.0, 15.0 / 64.0, 
   42.0 / 64.0, 56.0 / 64.0, 62.0 / 64.0, 52.0 / 64.0, 23.0 / 64.0, 7.0 / 64.0, 5.0 / 64.0, 17.0 / 64.0, 
   32.0 / 64.0, 40.0 / 64.0, 54.0 / 64.0, 38.0 / 64.0, 31.0 / 64.0, 21.0 / 64.0, 19.0 / 64.0, 29.0 / 64.0, 
}

@(private="file")
dither_threshold_cluster4x4: [16]f32 = 
{
   12.0 / 16.0, 5.0 / 16.0, 6.0 / 16.0, 13.0 / 16.0, 
   4.0 / 16.0, 0.0 / 16.0, 1.0 / 16.0, 7.0 / 16.0, 
   11.0 / 16.0, 3.0 / 16.0, 2.0 / 16.0, 8.0 / 16.0, 
   15.0 / 16.0, 10.0 / 16.0, 9.0 / 16.0, 14.0 / 16.0, 
}

image64_dither :: proc(img: ^Image64, conf: ^Config) -> (^Image32, ^Image8)
{
   prof.SCOPED_EVENT(#procedure)

   palette: [256][3]f32

   // Convert palette to format
   switch conf.colour_dist
   {
   case .RGB_Euclidian, .RGB_Weighted, .RGB_Redmean:
      for i in 0..<conf.colour_count
      {
         palette[i] = colour_to_rgb(conf.palette[i])
      }
   case .LAB_CIE76, .LAB_CIE94, .LAB_CIEDE2000:
      for i in 0..<conf.colour_count
      {
         palette[i] = colour_to_lab(conf.palette[i])
      }
   }

   switch conf.dither_mode
   {
   case .None:
      return dither_threshold(img, 0, dither_threshold_none[:], palette, conf)
   case .Bayer8x8:
      return dither_threshold(img, 3, dither_threshold_bayer8x8[:], palette, conf)
   case .Bayer4x4:
      return dither_threshold(img, 2, dither_threshold_bayer4x4[:], palette, conf)
   case .Bayer2x2:
      return dither_threshold(img, 1, dither_threshold_bayer2x2[:], palette, conf)
   case .Cluster8x8:
      return dither_threshold(img, 3, dither_threshold_cluster8x8[:], palette, conf)
   case .Cluster4x4:
      return dither_threshold(img, 2, dither_threshold_cluster4x4[:], palette, conf)
   case .Floyd:
      return dither_floyd(img, palette, conf)
   case .Floyd2:
      return dither_floyd2(img, palette, conf)
   case .MedianCut:
      return assign_median(img, palette, conf)
   }

   return nil, nil
}

@(private="file")
dither_threshold :: proc(img: ^Image64, dim: u32, threshold: []f32, palette: [256][3]f32, conf: ^Config) -> (^Image32, ^Image8) #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   out32: ^Image32 = image32_new(img.width, img.height)
   out: ^Image8 = image8_new(img.width, img.height)
   out.colour_count = u32(conf.colour_count)
   for i in 0..<conf.colour_count
   {
      out.palette = conf.palette[i]
   }

   for y in 0..<img.height
   {
      for x in 0..<img.width
      {
         p: [4]u16 = img.data[y * img.width + x]
         mod: u8 = u8((1 << dim) - 1)
         threshold_id: u8 = u8(((u32(y) & u32(mod)) << dim) + (u32(x) & u32(mod)))

         p[0] = max(0, min(u16(max(i16)), u16(f32(p[0]) + (32767 * conf.dither_amount / 8) * (threshold[threshold_id] - 0.5))))
         p[1] = max(0, min(u16(max(i16)), u16(f32(p[1]) + (32767 * conf.dither_amount / 8) * (threshold[threshold_id] - 0.5))))
         p[2] = max(0, min(u16(max(i16)), u16(f32(p[2]) + (32767 * conf.dither_amount / 8) * (threshold[threshold_id] - 0.5))))

         if i32(p[3] / 128) < conf.alpha_threshold
         {
            out32.data[y * out32.width + x] = 0
            out.data[y * out.width + x] = 0
            continue
         }

         out.data[y * img.width + x] = colour_closest(p, palette, conf)
         out32.data[y * img.width + x] = out.palette[out.data[y * img.width + x]]
      }
   }

   return out32, out
}

@(private="file")
dither_floyd :: proc(img: ^Image64, palette: [256][3]f32, conf: ^Config) -> (^Image32, ^Image8) #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   out32: ^Image32 = image32_new(img.width, img.height)
   out: ^Image8 = image8_new(img.width, img.height)
   out.colour_count = u32(conf.colour_count)
   for i in 0..<conf.colour_count
   {
      out.palette = conf.palette[i]
   }

   dup: ^Image64 = image64_dup(img)
   defer free(dup)

   for y in 0..<img.height
   {
      for x in 0..<img.width
      {
         p: [4]u16 = dup.data[y * img.width + x]

         if i32(p[3] / 128) < conf.alpha_threshold
         {
            out32.data[y * out32.width + x] = 0
            out.data[y * out.width + x] = 0
            continue
         }

         c: u8 = colour_closest(p, palette, conf)
         error: [3]f32
         error[0] = f32(colour64_to_32(p)[0]) - f32(conf.palette[c][0])
         error[1] = f32(colour64_to_32(p)[1]) - f32(conf.palette[c][1])
         error[2] = f32(colour64_to_32(p)[2]) - f32(conf.palette[c][2])

         floyd_apply_error(dup, (error * 7) / 16, x + 1, y)
         floyd_apply_error(dup, (error * 3) / 16, x + 1, y)
         floyd_apply_error(dup, (error * 5) / 16, x + 1, y)
         floyd_apply_error(dup, (error * 1) / 16, x + 1, y)

         out.data[y * img.width + x] = c
         out32.data[y * img.width + x] = out.palette[c]
      }
   }

   return out32, out
}

@(private="file")
dither_floyd2 :: proc(img: ^Image64, palette: [256][3]f32, conf: ^Config) -> (^Image32, ^Image8) #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   out32: ^Image32 = image32_new(img.width, img.height)
   out: ^Image8 = image8_new(img.width, img.height)
   out.colour_count = u32(conf.colour_count)
   for i in 0..<conf.colour_count
   {
      out.palette = conf.palette[i]
   }

   dup: ^Image64 = image64_dup(img)
   defer free(dup)

   for y in 0..<img.height
   {
      for x in 0..<img.width
      {
         p: [4]u16 = dup.data[y * img.width + x]

         if i32(p[3] / 128) < conf.alpha_threshold
         {
            out32.data[y * out32.width + x] = 0
            out.data[y * out.width + x] = 0
            continue
         }

         c: u8 = colour_closest(p, palette, conf)
         error: [3]f32
         error[0] = f32(colour64_to_32(p)[0]) - f32(conf.palette[c][0])
         error[1] = f32(colour64_to_32(p)[1]) - f32(conf.palette[c][1])
         error[2] = f32(colour64_to_32(p)[2]) - f32(conf.palette[c][2])
         error[0] = error[0] + error[1] + error[2]
         error[1] = error[0]
         error[2] = error[0]

         floyd_apply_error(dup, (error * 7) / 16, x + 1, y)
         floyd_apply_error(dup, (error * 3) / 16, x + 1, y)
         floyd_apply_error(dup, (error * 5) / 16, x + 1, y)
         floyd_apply_error(dup, (error * 1) / 16, x + 1, y)

         out.data[y * img.width + x] = c
         out32.data[y * img.width + x] = out.palette[c]
      }
   }

   return out32, out
}

@(private="file")
floyd_apply_error :: proc(img: ^Image64, err: [3]f32, x: i32, y: i32) #no_bounds_check
{
   if x < 0 || x >= img.width do return
   if y < 0 || y >= img.height do return

   p: [4]u16 = img.data[y * img.width + x]
   p[0] = max(0, min(u16(max(i16)), u16(f32(p[0]) + err[0] * 128)))
   p[1] = max(0, min(u16(max(i16)), u16(f32(p[1]) + err[1] * 128)))
   p[2] = max(0, min(u16(max(i16)), u16(f32(p[2]) + err[2] * 128)))

   img.data[y * img.width + x] = p
}

@(private="file")
assign_median :: proc(img: ^Image64, palette: [256][3]f32, conf: ^Config) -> (^Image32, ^Image8) #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   out32: ^Image32 = image32_new(img.width, img.height)
   out: ^Image8 = image8_new(img.width, img.height)
   out.colour_count = u32(conf.colour_count)
   for i in 0..<conf.colour_count
   {
      out.palette = conf.palette[i]
   }

   MedianColour :: struct
   {
      colour: [4]u8,
      idx: u32,
   }

   MedianBox :: struct
   {
      start: i32,
      count: i32,
      range: [3]i32,
      range_max: i32,
   }

   target: i32 = max(1, min(conf.target_colours, conf.colour_count))
   colours := make([]MedianColour, 2 * img.width * img.height)
   defer delete(colours)

   for i in 0..<img.width * img.height
   {
      colours[i].colour = colour64_to_32(img.data[i])
      colours[i].idx = u32(i)
   }

   boxes := make([]MedianBox, target)
   defer delete(boxes)

   //Put all above alpha threshold at start
   slow: i32
   for i in 0..<img.width * img.height
   {
      if i32(colours[i].colour[3]) >= conf.alpha_threshold
      {
         colours[i], colours[slow] = colours[slow], colours[i]
         slow += 1
      }
   }

   // Initial box
   boxes[0].start = 0
   boxes[0].count = slow
   cmin: [3]u8 = {255, 255, 255}
   cmax: [3]u8 = {0, 0, 0}
   for i in 0..<boxes[0].count
   {
      p: [4]u8 = colours[boxes[0].start + i].colour
      cmin[0] = min(cmin[0], p[0])
      cmin[1] = min(cmin[1], p[1])
      cmin[2] = min(cmin[2], p[2])
      cmax[0] = min(cmax[0], p[0])
      cmax[1] = min(cmax[1], p[1])
      cmax[2] = min(cmax[2], p[2])
   }
   boxes[0].range[0] = i32(cmax[0] - cmin[0])
   boxes[0].range[1] = i32(cmax[1] - cmin[1])
   boxes[0].range[2] = i32(cmax[2] - cmin[2])
   boxes[0].range_max = max(boxes[0].range[0], boxes[0].range[1], boxes[0].range[2])

   box_count: i32
   for box_count = 1; box_count < target; box_count += 1
   {
      //Choose box with largest range to subdivide
      rmax: i32 = 0
      max_box: i32 = 0
      for i in 0..<box_count
      {
         if boxes[i].range_max > rmax
         {
            rmax = boxes[i].range_max
            max_box = i
         }
      } 

      if boxes[max_box].range_max == 0 do break

      // Sort by largest range
      largest: i32 = max(boxes[max_box].range[0], boxes[max_box].range[1], boxes[max_box].range[2])
      if largest == boxes[max_box].range[0]
      {
         slice.sort_by(colours, proc(i, j: MedianColour) -> bool { return i.colour[0] > j.colour[0] })
      }
      else if largest == boxes[max_box].range[1]
      {
         slice.sort_by(colours, proc(i, j: MedianColour) -> bool { return i.colour[1] > j.colour[1] })
      }
      else if largest == boxes[max_box].range[2]
      {
         slice.sort_by(colours, proc(i, j: MedianColour) -> bool { return i.colour[2] > j.colour[2] })
      }

      //Divide
      len: i32 = 0
      if largest == boxes[max_box].range[0]
      {
         cut: u32 = (u32(colours[boxes[max_box].start].colour[0]) + 
                     u32(colours[boxes[max_box].start + boxes[max_box].count - 1].colour[0])) / 2
         for
         {
            if u32(colours[boxes[max_box].start + len].colour[0]) > cut do break
            len += 1
         }
      }
      else if largest == boxes[max_box].range[1]
      {
         cut: u32 = (u32(colours[boxes[max_box].start].colour[1]) + 
                     u32(colours[boxes[max_box].start + boxes[max_box].count - 1].colour[1])) / 2
         for
         {
            if u32(colours[boxes[max_box].start + len].colour[1]) > cut do break
            len += 1
         }
      }
      else if largest == boxes[max_box].range[2]
      {
         cut: u32 = (u32(colours[boxes[max_box].start].colour[2]) + 
                     u32(colours[boxes[max_box].start + boxes[max_box].count - 1].colour[2])) / 2
         for
         {
            if u32(colours[boxes[max_box].start + len].colour[2]) > cut do break
            len += 1
         }
      }

      old_count: i32 = boxes[max_box].count
      boxes[max_box].count = len
      boxes[box_count].start = boxes[max_box].start + boxes[max_box].count
      boxes[box_count].count = old_count - len

      // Recalculate ranges
      cmin: [3]u8 = {255, 255, 255}
      cmax: [3]u8 = {0, 0, 0}
      for i in 0..<boxes[max_box].count
      {
         p: [4]u8 = colours[boxes[max_box].start + i].colour
         cmin[0] = min(cmin[0], p[0])
         cmin[1] = min(cmin[1], p[1])
         cmin[2] = min(cmin[2], p[2])
         cmax[0] = min(cmax[0], p[0])
         cmax[1] = min(cmax[1], p[1])
         cmax[2] = min(cmax[2], p[2])
      }
      boxes[max_box].range[0] = i32(cmax[0] - cmin[0])
      boxes[max_box].range[1] = i32(cmax[1] - cmin[1])
      boxes[max_box].range[2] = i32(cmax[2] - cmin[2])
      boxes[max_box].range_max = max(boxes[max_box].range[0], boxes[max_box].range[1], boxes[max_box].range[2])

      cmin = {255, 255, 255}
      cmax = {0, 0, 0}
      for i in 0..<boxes[box_count].count
      {
         p: [4]u8 = colours[boxes[box_count].start + i].colour
         cmin[0] = min(cmin[0], p[0])
         cmin[1] = min(cmin[1], p[1])
         cmin[2] = min(cmin[2], p[2])
         cmax[0] = min(cmax[0], p[0])
         cmax[1] = min(cmax[1], p[1])
         cmax[2] = min(cmax[2], p[2])
      }
      boxes[box_count].range[0] = i32(cmax[0] - cmin[0])
      boxes[box_count].range[1] = i32(cmax[1] - cmin[1])
      boxes[box_count].range[2] = i32(cmax[2] - cmin[2])
      boxes[box_count].range_max = max(boxes[box_count].range[0], boxes[box_count].range[1], boxes[box_count].range[2])
   }

   // Calculate errors
   errors := make([]f64, conf.colour_count * box_count)
   defer delete(errors)
   for i in 0..<box_count
   {
      for j in 0..<boxes[i].count
      {
         p: [4]u8 = colours[boxes[i].start + j].colour
         c: [3]f32
         switch conf.colour_dist
         {
         case .RGB_Euclidian, .RGB_Weighted, .RGB_Redmean:
            c = colour_to_rgb(p)
         case .LAB_CIE76, .LAB_CIE94, .LAB_CIEDE2000:
            c = colour_to_lab(p)
         }

         for idx in 0..<conf.colour_count
         {
            dist: f32
            switch conf.colour_dist
            {
            case .RGB_Euclidian:
               dist = dist_rgb_euclidian(palette[idx], c)
            case .RGB_Weighted:
               dist = dist_rgb_weighted(palette[idx], c)
            case .RGB_Redmean:
               dist = dist_rgb_redmean(palette[idx], c)
            case .LAB_CIE76:
               dist = dist_cie76(palette[idx], c)
            case .LAB_CIE94:
               dist = dist_cie94(palette[idx], c)
            case .LAB_CIEDE2000:
               dist = dist_ciede2000(palette[idx], c)
            }

            errors[i * conf.colour_count + idx] += f64(dist)
         }
      }
   }

   //Find best asignment
   assign_lowest := kuhn_match(box_count, conf.colour_count, errors)
   defer delete(assign_lowest)
   for i in 0..<box_count
   {
      for j in 0..<boxes[i].count
      {
         idx: u32 = colours[boxes[i].start + j].idx
         colour: [4]u8 = colours[boxes[i].start + j].colour

         if i32(colour[3]) < conf.alpha_threshold
         {
            out.data[idx] = 0
            out32.data[idx] = 0
         }
         else
         {
            out.data[idx] = assign_lowest[i]
            out32.data[idx] = out.palette[out.data[idx]]
         }
      }
   }

   return out32, out
}

//From: https://github.com/maandree/hungarian-algorithm-n3
/**
 * O(n³) implementation of the Hungarian algorithm
 * 
 * Copyright (C) 2011, 2014, 2020  Mattias Andrée
 * 
 * This program is free software. It comes without any warranty, to
 * the extent permitted by applicable law. You can redistribute it
 * and/or modify it under the terms of the Do What The Fuck You Want
 * To Public License, Version 2, as published by Sam Hocevar. See
 * http://sam.zoy.org/wtfpl/COPYING for more details.
 */

kuhn_match :: proc(n: i32, m: i32, table: []f64) -> []u8 #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   row_covered := make([]b8, n)
   defer delete(row_covered)
   col_covered := make([]b8, m)
   defer delete(col_covered)
   row_primes := make([]i32, n)
   defer delete(row_primes)
   col_marks := make([]i32, m)
   defer delete(col_marks)
   alt := make([]u32, n * m)
   defer delete(alt)

   kuhn_reduce_rows(n, m, table)
   marks: []u8 = kuhn_mark(n, m, table)
   prime: u32 = 0
   for !kuhn_is_done(n, m, marks, col_covered)
   {
      for !kuhn_find_prime(n, m, table, marks, row_covered, col_covered, &prime)
      {
         kuhn_add_subtract(n, m, table, row_covered, col_covered)
      }

      kuhn_alt_marks(n, m, marks, alt, col_marks, row_primes, &prime)
      mem.set(raw_data(row_covered), 0, size_of(row_covered[0]) * int(n))
      mem.set(raw_data(col_covered), 0, size_of(col_covered[0]) * int(m))
   }

   return kuhn_assign(n, m, marks)
}

@(private="file")
kuhn_reduce_rows :: proc(n: i32, m: i32, table: []f64) #no_bounds_check
{
   for i in 0..<n
   {
      min: f64 = table[i * m]
      for j in 1..<m
      {
         if table[i * m + j] < min
         {
            min = table[i * m + j]
         }
      }

      for j in 0..<m
      {
         table[i * m + j] -= min
      }
   }
}

@(private="file")
kuhn_mark :: proc(n: i32, m: i32, table: []f64) -> []u8 #no_bounds_check
{
   marks := make([]u8, n * m)
   row_covered := make([]b8, n)
   defer delete(row_covered)
   col_covered := make([]b8, m)
   defer delete(col_covered)

   for i in 0..<n
   {
      for j in 0..<m
      {
         if !row_covered[i] && !col_covered[j] && table[i * m + j] == 0
         {
            marks[i * m + j] = 1
            row_covered[i] = true
            col_covered[j] = true
         }
      }
   }

   return marks
}

@(private="file")
kuhn_is_done :: proc(n: i32, m: i32, marks: []u8, covered: []b8) -> bool
{
   mem.set(raw_data(covered), 0, size_of(covered[0]) * int(m))

   num_done: i32 = 0
   for j in 0..<m
   {
      for i in 0..<n
      {
         if marks[i * m + j] == 1
         {
            covered[j] = true
            num_done += 1
            break
         }
      }
   }

   return num_done == 0
}

@(private="file")
kuhn_find_prime :: proc(n: i32, m: i32, table: []f64, marks: []u8, row_covered: []b8, 
                        col_covered: []b8, prime: ^u32) -> bool #no_bounds_check
{
   zeroes := bit_array.create(int(n * m))
   defer bit_array.destroy(zeroes)

   for i in 0..<n
   {
      if row_covered[i] do continue

      for j in 0..<m
      {
         if !col_covered[j] && table[i * m + j] == 0
         {
            bit_array.set(zeroes, i * m + j, true)
         }
      }
   }

   for
   {
      iter := bit_array.make_iterator(zeroes)
      idx, ok := bit_array.iterate_by_set(&iter)

      if !ok do return false

      row: int = idx / int(m)
      col: int = idx % int(m)
      marks[row * int(m) + col] = 2
      mark_in_row: bool = false
      for j in 0..<m
      {
         if marks[row * int(m) + int(j)] == 1
         {
            mark_in_row = true
            col = int(j)
         }
      }

      if mark_in_row
      {
         row_covered[row] = true
         col_covered[col]= false
         for i in 0..<n
         {
            if table[int(i * m) + col] == 0 && row != int(i)
            {
               if !row_covered[i] && !col_covered[col]
               {
                  bit_array.set(zeroes, int(i * m) + col, true)
               }
               else
               {
                  bit_array.set(zeroes, int(i * m) + col, false)
               }
            }
         }

         for j in 0..<m
         {
            if table[row * int(m) + int(j)] == 0 && col != int(j)
            {
               if !row_covered[row] && !col_covered[j]
               {
                  bit_array.set(zeroes, row * int(m) + int(j), true)
               }
               else
               {
                  bit_array.set(zeroes, row * int(m) + int(j), false)
               }
            }
         }

         if !row_covered[row] && !col_covered[col]
         {
            bit_array.set(zeroes, row * int(m) + col, true)
         }
         else
         {
            bit_array.set(zeroes, row * int(m) + col, false)
         }
      }
      else
      {
         prime^ = u32(row * int(m) + col)
         return true
      }
   }

   return false
}

@(private="file")
kuhn_add_subtract :: proc(n: i32, m: i32, table: []f64, row_covered: []b8, col_covered: []b8) #no_bounds_check
{
   min: f64 = 1e24

   for i in 0..<n
   {
      if row_covered[i] do continue

      for j in 0..<m
      {
         if !col_covered[j] && table[i * m + j] < min
         {
            min = table[i * m +j]
         }
      }
   }

   for i in 0..<n
   {
      for j in 0..<m
      {
         if row_covered[i] do table[i * m + j] += min
         if !col_covered[j] do table[i * m + j] -= min
      }
   }
}

@(private="file")
kuhn_alt_marks :: proc(n: i32, m: i32, marks: []u8, alt: []u32, col_marks: []i32, row_primes: []i32, prime: ^u32) #no_bounds_check
{
   row: i32
   col: i32
   alt[0] = prime^
   for i in 0..<n
   {
      row_primes[i] = -1
   }
   for i in 0..<m
   {
      col_marks[i] = -1
   }

   for i in 0..<n
   {
      for j in 0..<m
      {
         if marks[i * m + j] == 1
         {
            col_marks[j] = i
         }
         else if marks[i * m + j] == 2
         {
            row_primes[i] = j
         }
      }
   }

   idx: i32 = 0
   row = col_marks[alt[idx] % u32(m)]
   for row >= 0
   {
      idx += 1
      alt[idx] = u32(row * m) + alt[idx - 1] % u32(m)
      col = row_primes[alt[idx] / u32(m)]
      idx += 1
      alt[idx] = (alt[idx - 1] / u32(m)) * u32(m) + u32(col)

      row = col_marks[alt[idx] % u32(m)]
   }

   for i in 0..=idx
   {
      value := marks[alt[i]]
      marks[alt[i]] = value == 1 ? 0 : 1
   }

   for i in 0..<n
   {
      for j in 0..<m
      {
         if marks[i * m + j] == 2
         {
            marks[i * m + j] = 0
         }
      }
   }
}

@(private="file")
kuhn_assign :: proc(n: i32, m: i32, marks: []u8) -> []u8 #no_bounds_check
{
   assign := make([]u8, n)
   for i in 0..<n
   {
      for j in 0..<m
      {
         if marks[i * m + j] == 1
         {
            assign[i] = u8(j)
         }
      }
   }

   return assign
}

@(private="file")
colour_closest :: proc(p: [4]u16, palette: [256][3]f32, conf: ^Config) -> u8
{
   min_dist: f32 = 1e12
   min_idx: u8 = 0

   c: [3]f32
   switch conf.colour_dist
   {
   case .RGB_Euclidian, .RGB_Weighted, .RGB_Redmean:
      c = colour_to_rgb(colour64_to_32(p))
   case .LAB_CIE76, .LAB_CIE94, .LAB_CIEDE2000:
      c = colour_to_lab(colour64_to_32(p))
   }

   for i in 0..<conf.colour_count
   {
      dist: f32

      switch conf.colour_dist
      {
      case .RGB_Euclidian:
         dist = dist_rgb_euclidian(c, palette[i])
      case .RGB_Weighted:
         dist = dist_rgb_weighted(c, palette[i])
      case .RGB_Redmean:
         dist = dist_rgb_redmean(c, palette[i])
      case .LAB_CIE76:
         dist = dist_cie76(c, palette[i])
      case .LAB_CIE94:
         dist = dist_cie94(c, palette[i])
      case .LAB_CIEDE2000:
         dist = dist_ciede2000(c, palette[i])
      }

      if dist < min_dist
      {
         min_dist = dist
         min_idx = u8(i)
      }
   }

   return min_idx
}

@(private="file")
dist_rgb_euclidian :: proc(a: [3]f32, b: [3]f32) -> f32
{
   return linalg.dot(a - b, a - b)
}

@(private="file")
dist_rgb_weighted :: proc(a: [3]f32, b: [3]f32) -> f32
{
   if a[0] + b[0] < 1
   {
      return (b[0] - a[0]) * (b[0] - a[0]) * 2 + 
             (b[1] - a[1]) * (b[1] - a[1]) * 4 + 
             (b[2] - a[2]) * (b[2] - a[2]) * 3
   }
   else
   {
      return (b[0] - a[0]) * (b[0] - a[0]) * 3 + 
             (b[1] - a[1]) * (b[1] - a[1]) * 4 + 
             (b[2] - a[2]) * (b[2] - a[2]) * 2
   }
}

@(private="file")
dist_rgb_redmean :: proc(a: [3]f32, b: [3]f32) -> f32
{
   r: f32 = 0.5 * 255 * (a[0] + b[0])

   return (b[0] - a[0]) * (b[0] - a[0]) * (2 + r / 256) +
          (b[1] - a[1]) * (b[1] - a[1]) * 4 +
          (b[2] - a[2]) * (b[2] - a[2]) * (2 + (255 - r) / 256)
}

@(private="file")
dist_cie76 :: proc(a: [3]f32, b: [3]f32) -> f32
{
   return linalg.dot(a - b, a - b)
}

@(private="file")
dist_cie94 :: proc(a: [3]f32, b: [3]f32) -> f32
{
   //return linalg.dot(a - b, a - b)
   L: f32 = a[0] - b[0]
   C1: f32 = math.sqrt(a[1] * a[1] + a[2] * a[2])
   C2: f32 = math.sqrt(b[1] * b[1] + b[2] * b[2])
   C: f32 = C1 - C2
   H: f32 = math.sqrt((a[1] - b[1]) * (a[1] - b[1]) + (a[2] - b[2]) * (a[2] - b[2]) - C * C)
   r1: f32 = L
   r2: f32 = C / (1.0 + 0.045 * C1)
   r3: f32 = H / (1.0 + 0.015 * C1)

   dist: f32 = r1 * r1 + r2 * r2 + r3 * r3
   if math.is_nan(dist) do dist = 1e15

   return dist
}

@(private="file")
dist_ciede2000 :: proc(b: [3]f32, c: [3]f32) -> f32
{
   C1: f64 = f64(math.sqrt(b[1] * b[1] + b[2] * b[2]))
   C2: f64 = f64(math.sqrt(c[1] * c[1] + c[2] * c[2]))
   C_: f64 = (C1 + C2) / 2.0

   C_p2: f64 = math.pow(C_, 7.0)
   v: f64 = 0.5 * (1.0 - math.sqrt(C_p2 / (C_p2 + 6103515625.0)))
   a1: f64 = (1.0 + v) * f64(b[1])
   a2: f64 = (1.0 + v) * f64(c[1])

   Cs1: f64 = math.sqrt(a1 * a1 + f64(b[2] * b[2]))
   Cs2: f64 = math.sqrt(a2 * a2 + f64(c[2] * c[2]))

   h1: f64 = 0.0
   if b[2] != 0 || a1 != 0
   {
      h1 = math.atan2(f64(b[2]), a1);
      if h1 < 0 do h1 += 2.0 * math.PI;
   }
   h2: f64 = 0.0;
   if c[2] != 0 || a2 != 0
   {
      h2 = math.atan2(f64(c[2]), a2);
      if h2 < 0 do h2 += 2.0 * math.PI;
   }

   L: f64 = f64(c[0] - b[0])
   Cs: f64 = Cs2 - Cs1

   h: f64 = 0.0
   if Cs1 * Cs2 != 0.0
   {
      h = h2 - h1
      if h < -math.PI do h+= 2 * math.PI
      else if h > math.PI do h -= 2 * math.PI
   }
   H: f64 = 2.0 * math.sqrt(Cs1 * Cs2) * math.sin(h / 2.0)

   L_: f64 = f64(b[0] + c[0]) / 2.0
   Cs_: f64 = (Cs1 + Cs2) / 2.0
   H_: f64 = h1 + h2
   if Cs1 * Cs2 != 0.0
   {
      if abs(h1 - h2) <= math.PI do H_ = (h1 + h2) / 2.0
      else if h1 + h2 < 2 * math.PI do H_ = (h1 + h2 + 2 * math.PI) / 2.0
      else do H_ = (h1 + h2 - 2 * math.PI) / 2.0
   }

   T: f64 = 1.0 - 0.17 * math.cos(H_ - math.to_radians(f64(30.0))) +
            0.24 * math.cos(2.0 * H_) + 0.32 * math.cos(3.0 * H_ + math.to_radians(f64(6.0))) - 
            0.2 * math.cos(4.0 * H_ - math.to_radians(f64(63.0)))
   v = math.to_radians(f64(60.0)) * math.exp(-1.0 * ((H_ - math.to_radians(f64(275))) / math.to_radians(f64(25))) *
      ((H_ - math.to_radians(f64(275.0))) / math.to_radians(f64(25))))
   Cs_p2: f64 = math.pow(Cs_, 7.0)
   RC: f64 = 2.0 * math.sqrt(Cs_p2 / (Cs_p2 + 6103515625.0))
   RT: f64 = -1.0 * math.sin(v) * RC
   SL: f64 = 1.0
   SC: f64 = 1.0 + 0.045 * Cs_
   SH: f64 = 1.0 + 0.015 * Cs_ * T

   return f32((L / SL) * (L / SL) + (Cs / SC) * (Cs / SC) +
      (H / SH) * (H / SH) + RT * (Cs / SC) * (H_ / SH))
}

@(private="file")
colour_to_rgb :: proc(c: [4]u8) -> [3]f32
{
   return {f32(c[0]) / 255, f32(c[1]) / 255, f32(c[2]) / 255}
}

@(private="file")
colour_to_lab :: proc(c: [4]u8) -> [3]f32
{
   // to rgb
   r: f32 = f32(c[0]) / 255
   g: f32 = f32(c[1]) / 255
   b: f32 = f32(c[2]) / 255

   // to xyz
   //-------------------------------------
   x, y, z: f32
   
   if r > 0.04045 do r = math.pow((r + 0.055) / 1.055, 2.4)
   else do r = r / 12.92

   if g > 0.04045 do g = math.pow((g + 0.055) / 1.055, 2.4)
   else do g = g / 12.92

   if b > 0.04045 do b = math.pow((b + 0.055) / 1.055, 2.4)
   else do b = b / 12.92

   x = r * 0.4124 + g * 0.3576 + b * 0.1805
   y = r * 0.2126 + g * 0.7152 + b * 0.0722
   z = r * 0.0193 + g * 0.1192 + b * 0.9504
   //-------------------------------------

   //Convert to lab
   lab: [3]f32
   if x > 0.008856 do x = math.pow(x ,1.0 / 3.0)
   else do x = (7.787 * x) + (16.0 / 116.0)

   if y > 0.008856 do y = math.pow(y, 1.0 / 3.0)
   else do y = (7.787 * y) + (16.0 / 116.0)

   if z > 0.008856 do z = math.pow(z, 1.0 / 3.0)
   else do z = (7.787 * z) + (16.0 / 116.0)

   lab[0] = 116 * y - 16
   lab[1] = 500 * (x - y)
   lab[2] = 200 * (y - z)

   return lab
}
