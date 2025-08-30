package gui

import "core:log"
import "core:strings"
import "core:fmt"
import "vendor:sdl3"

ImageComp :: struct
{
   using element: Element,

   width0: i32,
   height0: i32,
   width1: i32,
   height1: i32,
   img0: ^sdl3.Texture,
   img1: ^sdl3.Texture,

   slider: i32,

   x: f32,
   y: f32,
   ox: f32,
   oy: f32,
   scale: f32,
   scale1: f32,
}

@(private="file")
texture_from_data :: proc(w: ^Window, pix: []u8, width: i32, height: i32) -> ^sdl3.Texture
{
   surface: ^sdl3.Surface = sdl3.CreateSurfaceFrom(width, height, .RGBA32, raw_data(pix), width * 4)
   defer sdl3.DestroySurface(surface)
   return sdl3.CreateTextureFromSurface(w.sdl_renderer, surface)
}

imgcmp_create :: proc(parent: ^Element, flags: ElementFlags, pix0: []u8, width0: i32, height0: i32, 
   pix1: []u8, width1: i32, height1: i32) -> ^ImageComp
{
   imgcmp: ^ImageComp = &element_create(ImageComp, parent, flags, imgcmp_msg).derived.(ImageComp)

   imgcmp.slider = 1024
   imgcmp.width0 = width0
   imgcmp.height0 = height0
   imgcmp.width1 = width1
   imgcmp.height1 = height1
   imgcmp.img0 = texture_from_data(parent.window, pix0, width0, height0)
   imgcmp.img1 = texture_from_data(parent.window, pix1, width1, height1)

   imgcmp.bounds = {{0, 0}, {imgcmp.width0 + 6 * get_scale(), imgcmp.height0 + 6 * get_scale()}}
   imgcmp_update_view(imgcmp, true)

   return imgcmp
}

imgcmp_update0 :: proc(img: ^ImageComp, pix: []u8, width: i32, height: i32)
{
   if img.img0 != nil
   {
      sdl3.DestroyTexture(img.img0)
   }

   img.width0 = width
   img.height0 = height
   img.img0 = texture_from_data(img.window, pix, width, height)

   imgcmp_update_view(img, true)
}

imgcmp_update1 :: proc(img: ^ImageComp, pix: []u8, width: i32, height: i32)
{
   if img.img1 != nil
   {
      sdl3.DestroyTexture(img.img1)
   }

   img.width1 = width
   img.height1 = height
   img.img1 = texture_from_data(img.window, pix, width, height)

   imgcmp_update_view(img, false)
}

@(private="file")
imgcmp_msg :: proc(e: ^Element, msg: Msg, di: int, dp: rawptr) -> int
{
   img: ^ImageComp = &e.derived.(ImageComp)

   if msg == .GET_WIDTH
   {
      return int(img.width0 + 6 * get_scale())
   }
   else if msg == .GET_HEIGHT
   {
      return int(img.height0 + 6 * get_scale())
   }
   else if msg == .MOUSE
   {
      mouse: ^Mouse = cast(^Mouse)dp
      redraw: bool

      if card(mouse.button & {.LEFT, .RIGHT}) > 0
      {
         bounds: Rect = img.bounds
         scale: i32 = get_scale()

         mx: i32 = i32(mouse.pos.x) - bounds.min.x - 3 * scale
         value: i32 = (mx * 2048) / (bounds.max.x - bounds.min.x - 6 * scale)
         value = max(0, min(2048, value))

         if img.slider != value
         {
            img.slider = value
            element_redraw(img)
         }

         return 1
      }

      if mouse.wheel > 0 && img.scale <= 64.0
      {
         mx: f32 = mouse.pos.x - f32(img.bounds.min.x)
         my: f32 = mouse.pos.y - f32(img.bounds.min.y)
         x: f32 = (mx - img.x) / img.scale
         y: f32 = (my - img.y) / img.scale
         scale_change: f32 = -img.scale * 0.15
         img.x += x * scale_change
         img.y += y * scale_change
         img.scale += img.scale * 0.15
         redraw = true
      }
      else if mouse.wheel < 0 && img.scale >= 0.1
      {
         mx: f32 = mouse.pos.x - f32(img.bounds.min.x)
         my: f32 = mouse.pos.y - f32(img.bounds.min.y)
         x: f32 = (mx - img.x) / img.scale
         y: f32 = (my - img.y) / img.scale
         scale_change: f32 = img.scale * 0.15
         img.x += x * scale_change
         img.y += y * scale_change
         img.scale -= img.scale * 0.15
         redraw = true
      }

      if card(mouse.button & {.MIDDLE}) > 0 &&
         (mouse.rel.x != 0 || mouse.rel.y != 0)
      {
         img.x += mouse.rel.x
         img.y += mouse.rel.y
         element_redraw(img)

         return 1
      }

      if redraw
      {
         element_redraw(img)
      }
   }
   else if msg == .DRAW
   {
      imgcmp_draw(img)
   }
   else if msg == .BUTTON_DOWN
   {
      scancode: int = di

      if sdl3.Scancode(scancode) == .BACKSPACE
      {
         imgcmp_update_view(img, true)
         element_redraw(img)
      }
   }
   else if msg == .DESTROY
   {
      if img.img0 == nil do sdl3.DestroyTexture(img.img0)
      if img.img1 == nil do sdl3.DestroyTexture(img.img1)
   }

   return 0
}

@(private="file")
imgcmp_draw :: proc(img: ^ImageComp)
{
   bounds: Rect = img.bounds
   scale: i32 = get_scale()

   draw_rectangle_fill(img, bounds, {90, 90, 90, 255})

   draw_rectangle_fill(img, {{bounds.min.x + scale, bounds.min.y + 2 * scale},
      {bounds.min.x + 2 * scale, bounds.max.y - 2 * scale}}, {50, 50, 50, 255})
   draw_rectangle_fill(img, {{bounds.min.x + scale, bounds.max.y - 2 * scale},
      {bounds.max.x - 2 * scale, bounds.max.y - 1 * scale}}, {50, 50, 50, 255})

   draw_rectangle_fill(img, {{bounds.max.x - 2 * scale, bounds.min.y + 2 * scale},
      {bounds.max.x - 1 * scale, bounds.max.y - 2 * scale}}, {200, 200, 200, 255})
   draw_rectangle_fill(img, {{bounds.min.x + 2 * scale, bounds.min.y + 1 * scale},
      {bounds.max.x - 1 * scale, bounds.min.y + 2 * scale}}, {200, 200, 200, 255})

   middle: i32 = ((bounds.max.x - bounds.min.x - 6 * scale) * img.slider) / 2048 + bounds.min.x + 3 * scale
   clip: sdl3.Rect
   dst: sdl3.FRect
   dst.x = img.x + f32(bounds.min.x)
   dst.y = img.y + f32(bounds.min.y)
   dst.w = f32(img.width0) * img.scale
   dst.h = f32(img.height0) * img.scale
   clip.x = bounds.min.x + 3 * scale
   clip.y = bounds.min.y + 3 * scale
   clip.w = middle - (bounds.min.x + 6 * scale)
   if clip.w <= 0 do clip.w = 1
   clip.h = bounds.max.y - bounds.min.y - 6 * scale

   //fmt.printf("%v %v\n", clip, dst)

   sdl3.SetRenderClipRect(img.window.sdl_renderer, &clip)
   sdl3.RenderTexture(img.window.sdl_renderer, img.img0, nil, &dst)
   sdl3.SetRenderClipRect(img.window.sdl_renderer, nil)

   clip.x = middle
   clip.y = bounds.min.y + 3 * scale
   clip.w = bounds.max.x - middle - 3 * scale
   if clip.w <= 0 do clip.w = 1
      clip.h = bounds.max.y - bounds.min.y - 6 * scale
   dst.x = img.x + img.ox * img.scale + f32(bounds.min.x)
   dst.y = img.y + img.oy * img.scale + f32(bounds.min.y)
   dst.w = f32(img.width1) * img.scale1 * img.scale
   dst.h = f32(img.height1) * img.scale1 * img.scale
   sdl3.SetRenderClipRect(img.window.sdl_renderer, &clip)
   sdl3.RenderTexture(img.window.sdl_renderer, img.img1, nil, &dst)
   sdl3.SetRenderClipRect(img.window.sdl_renderer, nil)

   draw_rectangle_fill(img, {{middle - scale, bounds.min.y + 3 * scale}, 
      {middle + scale, bounds.max.y - 3 * scale}}, {90, 90, 90, 255})
   draw_rectangle_fill(img, {{middle - 2 * scale, bounds.min.y + 3 * scale}, 
      {middle - scale, bounds.max.y - 3 * scale}}, {50, 50, 50, 255})
   draw_rectangle_fill(img, {{middle + scale, bounds.min.y + 3 * scale}, 
      {middle + 2 * scale, bounds.max.y - 3 * scale}}, {200, 200, 200, 255})
}

@(private="file")
imgcmp_update_view :: proc(img: ^ImageComp, reset: bool)
{
   bounds: Rect = img.bounds
   scale: i32 = get_scale()

   view_x: f32
   view_y: f32
   view_width: f32
   view_height: f32
   width: i32 = bounds.max.x - bounds.min.x - scale * 6
   height: i32 = bounds.max.y - bounds.min.y - scale * 6

   if width * img.height0 > img.width0 * height
   {
      view_height = f32(height)
      view_width = f32(img.width0 * height) / f32(img.height0)
   }
   else
   {
      view_width = f32(width)
      view_height = f32(img.height0 * width) / f32(img.width0)
   }

   view_x = (f32(width) - view_width) / 2.0
   view_y = (f32(height) - view_height) / 2.0

   if reset
   {
      img.x = view_x
      img.y = view_y
      img.scale = view_width / f32(img.width0)
   }

   if width * img.height1 > img.width1 * height
   {
      view_height = f32(height)
      view_width = f32(img.width1 * height) / f32(img.height1)
   }
   else
   {
      view_width = f32(width)
      view_height = f32(img.height1 * width) / f32(img.width1)
   }

   sc0: f32 = view_width / f32(img.width0)
   img.scale1 = (view_width / f32(img.width1)) / sc0
   img.ox = (f32(width) - view_width) / 2.0 - view_x
   img.oy = (f32(height) - view_height) / 2.0 - view_y
   img.ox /= sc0
   img.oy /= sc0
}
