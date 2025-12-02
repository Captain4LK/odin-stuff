package gui

import "core:log"
import "core:image/png"
import "core:image/qoi"
import "core:image/tga"
import "core:image/bmp"
import "core:image/netpbm"
import "core:image"
import "core:bytes"
import "core:strings"
import "core:fmt"
import "vendor:sdl3"

import "../prof"

Image :: struct
{
   using element: Element,

   width: i32,
   height: i32,
   img: ^sdl3.Texture,
}

image_create :: proc(parent: ^Element, flags: ElementFlags, path: string) -> ^Image
{
   prof.SCOPED_EVENT(#procedure)

   imge: ^Image= &element_create(Image, parent, flags, image_msg).derived.(Image)
   //image.text = strings.clone(str)

   img: ^image.Image
   err: image.Error
   img, err = image.load_from_file(path)
   defer image.destroy(img)
   image.alpha_add_if_missing(img)

   data: []u8 = bytes.buffer_to_bytes(&img.pixels)
   surface: ^sdl3.Surface = sdl3.CreateSurfaceFrom(i32(img.width), i32(img.height), .RGBA32, raw_data(data), i32(img.width * 4))
   defer sdl3.DestroySurface(surface)
   imge.img = sdl3.CreateTextureFromSurface(parent.window.sdl_renderer, surface)
   imge.width = i32(img.width)
   imge.height = i32(img.height)

   return imge
}

@(private="file")
image_msg :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   img: ^Image = &e.derived.(Image)

   if msg == .GET_WIDTH
   {
      return i64(img.width + 6 * get_scale())
   }
   else if msg == .GET_HEIGHT
   {
      return i64(img.height + 6 * get_scale())
   }
   else if msg == .DRAW
   {
      image_draw(img)
   }
   else if msg == .DESTROY
   {
      sdl3.DestroyTexture(img.img)
   }

   return 0
}

@(private)
image_draw :: proc(img: ^Image)
{
   bounds: Rect = img.bounds
   scale: i32 = get_scale()

   draw_rectangle_fill(img, {{bounds.min.x + scale, bounds.min.y + 2 * scale},
      {bounds.min.x + 2 * scale, bounds.max.y - 2 * scale}}, {50, 50, 50, 255})
   draw_rectangle_fill(img, {{bounds.min.x + scale, bounds.max.y - 2 * scale},
      {bounds.max.x - 2 * scale, bounds.max.y - scale}}, {50, 50, 50, 255})

   draw_rectangle_fill(img, {{bounds.max.x - 2 * scale, bounds.min.y + 2 * scale},
      {bounds.max.x - 1 * scale, bounds.max.y - 2 * scale}}, {200, 200, 200, 255})
   draw_rectangle_fill(img, {{bounds.min.x + 2 * scale, bounds.min.y + 1 * scale},
      {bounds.max.x - 1 * scale, bounds.min.y + 2 * scale}}, {200, 200, 200, 255})

   view_x: f32
   view_y: f32
   view_width: f32
   view_height: f32
   width: i32 = bounds.max.x - bounds.min.x - scale * 6
   height: i32 = bounds.max.y - bounds.min.y - scale * 6

   if width * img.height > img.width * height
   {
      view_height = f32(height)
      view_width = f32(img.width * height) / f32(img.height)
   }
   else
   {
      view_width = f32(width)
      view_height = f32(img.height * width) / f32(img.width)
   }

   view_x = (f32(width) - view_width) / 2.0 + f32(bounds.min.x + 3 * scale)
   view_y = (f32(height) - view_height) / 2.0 + f32(bounds.min.y + 3 * scale)

   dst: sdl3.FRect
   dst.x = view_x
   dst.y = view_y
   dst.w = view_width
   dst.h = view_height
   sdl3.RenderTexture(img.window.sdl_renderer, img.img, nil, &dst)
}
