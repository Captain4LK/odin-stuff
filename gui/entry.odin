package gui

import "core:log"
import "core:strings"
import "core:fmt"
import "vendor:sdl3"

Entry :: struct
{
   using element: Element,

   state: bool,
   active: bool,
   entry: [dynamic]u8,
   len_max: i32,
}

entry_create :: proc(parent: ^Element, flags: ElementFlags, len_max: i32) -> ^Entry
{
   entry: ^Entry= &element_create(Entry, parent, flags, entry_msg).derived.(Entry)
   entry.len_max = len_max

   return entry 
}

@(private="file")
entry_msg :: proc(e: ^Element, msg: Msg, di: int, dp: rawptr) -> int
{
   entry: ^Entry = &e.derived.(Entry)

   if msg == .GET_WIDTH
   {
      return int(entry.len_max * GLYPH_WIDTH * get_scale() + 12 * get_scale())
   }
   else if msg == .GET_HEIGHT
   {
      return int(GLYPH_HEIGHT * get_scale() + 10 * get_scale())
   }
   else if msg == .MOUSE_LEAVE
   {
      entry.state = false
   }
   else if msg == .MOUSE
   {
      mouse: ^Mouse = cast(^Mouse)dp

      if card(mouse.button & {.LEFT, .RIGHT, .MIDDLE}) > 0
      {
         mouse.handled = true
         entry.state = true
      }
      else if entry.state
      {
         //fmt.printf("TextStart\n")
         textinput_start(entry)
         mouse.handled = true
         entry.active = true
         entry.state = false
         element_redraw(entry)
      }
   }
   else if msg == .TEXTINPUT
   {
      input: ^TextInput = cast(^TextInput)dp
      changed: bool = false

      if input.type == .CHARACTER
      {
         if len(entry.entry) < int(entry.len_max)
         {
            append(&entry.entry, input.ch)
            changed = true
         }
      }
      else if input.type == .KEYCODE
      {
         if input.keycode == sdl3.K_RETURN
         {
            textinput_stop(entry.window)
            changed = true
         }
         else if input.keycode == sdl3.K_BACKSPACE
         {
            if len(entry.entry) > 0
            {
               pop(&entry.entry)
               changed = true
            }
         }
      }

      if changed
      {
         element_redraw(entry)
      }
      //fmt.printf("%v\n",input)
   }
   else if msg == .TEXTINPUT_END
   {
      entry.active = false
      element_redraw(entry)
   }
   else if msg == .DRAW
   {
      entry_draw(entry)
      //draw_rectangle(entry, entry.bounds, {0, 0, 0, 255})
   }
   else if msg == .DESTROY
   {
      delete(entry.entry)
   }

   return 0
}

@(private="file")
entry_draw :: proc(entry: ^Entry)
{
   bounds: Rect = entry.bounds
   scale: i32 = get_scale()

   draw_rectangle_fill(entry, {bounds.min + scale, bounds.max - scale}, {90, 90, 90, 255})

   draw_rectangle_fill(entry, {{bounds.min[0] + scale, bounds.min[1] + 2 * scale},
      {bounds.min[0] + 2 * scale, bounds.max[1] - scale}}, {200, 200, 200, 255})
   draw_rectangle_fill(entry, {{bounds.min[0] + scale, bounds.max[1] - 2 * scale},
      {bounds.max[0] - 2 * scale, bounds.max[1] - scale}}, {200, 200, 200, 255})
   draw_rectangle_fill(entry, {{bounds.max[0] - 2 * scale, bounds.min[1] + 2 * scale},
      {bounds.max[0] - scale, bounds.max[1] - 2 * scale}}, {50, 50, 50, 255})
   draw_rectangle_fill(entry, {{bounds.min[0] + 2 * scale, bounds.min[1] + scale},
      {bounds.max[0] - scale, bounds.min[1] + 2 * scale}}, {50, 50, 50, 255})

   draw_label(entry, {{bounds.min.x + 3 * scale, bounds.min.y}, bounds.max}, transmute(string)entry.entry[:], {0, 0, 0, 255}, false)

   if entry.active
   {
      draw_label(entry, {{bounds.min.x + 3 * scale + GLYPH_WIDTH * i32(len(entry.entry)) * scale, bounds.min.y}, bounds.max}, "\x16", {0, 0, 0, 255}, false)
   }
}
