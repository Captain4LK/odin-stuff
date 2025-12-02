package main

import "base:runtime"
import "core:log"
import "core:math"
import "core:math/rand"

import "../prof"

image32_kmeans :: proc(img: ^Image32, palette: ^[256][4]u8, colours: i32, seed: u64, kmeanspp: bool) #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   if img == nil do return
   if palette == nil do return

   centers := choose_centers(img, colours, seed, kmeanspp)
   defer delete(centers)

   clusters := make([][dynamic][4]u8, colours)
   defer delete(clusters)
   defer for d in clusters do delete(d)

   for i in 0..<colours
   {
      palette[i] = centers[i]
   }

   for i in 0..<8
   {
      //Reset clusters
      for idx in 0..<len(clusters)
      {
         clear(&clusters[idx])
      }

      for j in 0..<int(img.width) * int(img.height)
      {
         p: [4]u8 = img.data[j]
         cr: i32 = i32(p[0])
         cg: i32 = i32(p[1])
         cb: i32 = i32(p[2])
         ca: i32 = i32(p[3])

         dist_min: u64 = max(u64)
         min_i: int = 0
         for c in 0..<len(centers)
         {
            r: i32 = i32(centers[c][0])
            g: i32 = i32(centers[c][1])
            b: i32 = i32(centers[c][2])
            a: i32 = i32(centers[c][3])

            dist: i32 = (cr - r) * (cr - r)
            dist += (cg - g) * (cg - g)
            dist += (cb - b) * (cb - b)

            if u64(dist) < dist_min
            {
               dist_min = u64(dist)
               min_i = c
            }
         }

         append(&clusters[min_i], p)
      }

      //Recalculate centers
      for j in 0..<colours
      {
         sum: [3]u64
         for c in 0..<len(clusters[j])
         {
            sum[0] += u64(clusters[j][c][0])
            sum[1] += u64(clusters[j][c][1])
            sum[2] += u64(clusters[j][c][2])
         }

         if len(clusters[j]) > 0
         {
            p: [4]u8
            p[0] = u8(sum[0] / u64(len(clusters[j])))
            p[1] = u8(sum[1] / u64(len(clusters[j])))
            p[2] = u8(sum[2] / u64(len(clusters[j])))
            p[3] = 255
            centers[j] = p
            palette[j] = p
         }
         else
         {
            centers[j] = img.data[rand.int63_max(i64(img.width) * i64(img.height))]
            palette[j] = {0, 0, 0, 255}
         }
      }
   }
}

image32_kmeans_largest :: proc(img: ^Image32, palette: ^[256][4]u8, colours: i32, seed: u64) -> [4]u8 #no_bounds_check
{
   if img == nil do return {0, 0, 0, 255}
   if palette == nil do return { 0, 0, 0, 255}

   centers := choose_centers(img, colours, seed, true)
   defer delete(centers)

   clusters := make([][dynamic][4]u8, colours)
   defer delete(clusters)
   defer for d in clusters do delete(d)

   for i in 0..<8
   {
      //Reset clusters
      for idx in 0..<len(clusters)
      {
         clear(&clusters[idx])
      }

      for j in 0..<int(img.width) * int(img.height)
      {
         p: [4]u8 = img.data[j]
         cr: i32 = i32(p[0])
         cg: i32 = i32(p[1])
         cb: i32 = i32(p[2])
         ca: i32 = i32(p[3])

         dist_min: u64 = max(u64)
         min_i: int = 0
         for c in 0..<len(centers)
         {
            r: i32 = i32(centers[c][0])
            g: i32 = i32(centers[c][1])
            b: i32 = i32(centers[c][2])
            a: i32 = i32(centers[c][3])

            dist: i32 = (cr - r) * (cr - r)
            dist += (cg - g) * (cg - g)
            dist += (cb - b) * (cb - b)

            if u64(dist) < dist_min
            {
               dist_min = u64(dist)
               min_i = c
            }
         }

         append(&clusters[min_i], p)
      }

      //Recalculate centers
      for j in 0..<colours
      {
         sum: [3]u64
         for c in 0..<len(clusters[j])
         {
            sum[0] += u64(clusters[j][c][0])
            sum[1] += u64(clusters[j][c][1])
            sum[2] += u64(clusters[j][c][2])
         }

         if len(clusters[j]) > 0
         {
            p: [4]u8
            p[0] = u8(sum[0] / u64(len(clusters[j])))
            p[1] = u8(sum[1] / u64(len(clusters[j])))
            p[2] = u8(sum[2] / u64(len(clusters[j])))
            p[3] = 255
            centers[j] = p
            palette[j] = p
         }
         else
         {
            centers[j] = img.data[rand.int63_max(i64(img.width) * i64(img.height))]
            palette[j] = {0, 0, 0, 255}
         }
      }
   }

   largest: [4]u8 = palette[0]
   max_size: int = 0
   for i in 0..<colours
   {
      if len(clusters[i]) > max_size
      {
         max_size = len(clusters[i])
         largest = palette[i]
      }
   }

   return largest
}

@(private="file")
choose_centers :: proc(img: ^Image32, k: i32, seed: u64, kmeanspp: bool) -> [dynamic][4]u8 #no_bounds_check
{
   if img == nil do return nil

   rng_state := rand.create(seed)
   rng := runtime.default_random_generator(&rng_state)

   centers: [dynamic][4]u8

   if !kmeanspp
   {
      for i in 0..<k
      {
         index: i64 = rand.int63_max(i64(img.width) * i64(img.height), rng)
         append(&centers, img.data[index])
      }

      return centers
   }

   // Choose initial center
   index: i64 = rand.int63_max(i64(img.width) * i64(img.height), rng)
   append(&centers, img.data[index])

   distance := make([]u64, int(img.width) * int(img.height))
   defer delete(distance)
   for &dist in distance
   {
      dist = max(u64)
   }

   for i in 1..<k
   {
      dist_sum: u64
      for j in 0..<int(img.width) * int(img.height)
      {
         p: [4]u8 = img.data[j]
         cr: i32 = i32(p[0])
         cg: i32 = i32(p[1])
         cb: i32 = i32(p[2])
         ca: i32 = i32(p[3])

         center_idx: int = len(centers) - 1
         r: i32 = i32(centers[center_idx][0])
         g: i32 = i32(centers[center_idx][1])
         b: i32 = i32(centers[center_idx][2])
         a: i32 = i32(centers[center_idx][3])

         dist: i32 = (cr - r) * (cr - r)
         dist += (cg - g) * (cg - g)
         dist += (cb - b) * (cb - b)

         if u64(dist) < distance[j]
         {
            distance[j] = u64(dist)
         }
         dist_sum += distance[j]
      }

      // Weighted random to choose next centeroid
      random: u64 = 0
      if dist_sum != 0
      {
         random = u64(rand.int63_max(i64(dist_sum), rng))
      }

      found: bool
      dist_cur: u64 = 0
      for dist, idx in distance
      {
         dist_cur += dist
         if random < dist_cur
         {
            append(&centers, img.data[idx])
            found = true
            break
         }
      }

      if !found
      {
         append(&centers, img.data[0])
      }
   }

   return centers
}
