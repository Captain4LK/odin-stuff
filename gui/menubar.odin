package gui

import "core:log"
import "core:strings"
import "core:fmt"
import "vendor:sdl3"

DropDown :: struct
{
   using element: Element,

   text: string,
   drop: ^Element,
   side: b32,
   state: i32,
}

menubar_create :: proc(parent: ^Element, flags: ElementFlags, 
                       cflags: ElementFlags, labels: []string, 
                       panels: []^Element, msg_usr: MsgHandler) -> ^Group
{
   group: ^Group = group_create(parent, flags)

   side: b32 = false
   if flags.layout == .VERTICAL do side = true
   else do side = false

   for label, idx in labels
   {
      drop: ^DropDown = &element_create(DropDown, group, cflags, dropdown_msg).derived.(DropDown)
      drop.text = strings.clone(label)
      drop.drop = panels[idx]
      drop.drop.window = drop.window
      drop.side = side
   }

   return group
}

@(private="file")
dropdown_msg :: proc(e: ^Element, msg: Msg, di: int, dp: rawptr) -> int
{
   drop: ^DropDown = &e.derived.(DropDown)

   if msg == .GET_WIDTH
   {
      return len(drop.text) * int(GLYPH_WIDTH * get_scale()) + int(10 * get_scale())
   }
   else if msg == .GET_HEIGHT
   {
      return int(GLYPH_HEIGHT * get_scale()) + int(8 * get_scale())
   }
   else if msg == .MOUSE
   {
      mouse: ^Mouse = cast(^Mouse)dp
      hit: ^Element
      state_old: i32 = drop.state


      if drop.state == 0
      {
         if rect_inside(drop.bounds, {i32(mouse.pos.x), i32(mouse.pos.y)}) &&
            card(mouse.button & {.LEFT, .RIGHT, .MIDDLE}) > 0
         {
            bounds: Rect = drop.window.bounds

            if !drop.side
            {
               bounds.min.x = drop.bounds.min.x
               bounds.min.y = drop.bounds.max.y
               //flags
            }
            else
            {
               bounds.min.x = drop.bounds.max.x
               bounds.min.y = drop.bounds.min.y
               //flags
            }

            element_set_invisible(drop.drop, false)
            element_layout(drop.drop, bounds)
            //fmt.printf("Draw overlay %v\n", drop.drop)
            element_redraw(drop.drop)

            drop.state = 1
         }
      }
      else if drop.state == 1
      {
         if rect_inside(drop.drop.bounds, {i32(mouse.pos.x), i32(mouse.pos.y)})
         {
            hit = drop.drop
         }

         if card(mouse.button & {.LEFT, .RIGHT, .MIDDLE}) == 0
         {
            if rect_inside(drop.drop.bounds, {i32(mouse.pos.x), i32(mouse.pos.y)})
            {
               hit = drop.drop
               drop.state = 0
               element_set_invisible(drop.drop, true)
               hit = drop.drop
               element_redraw(drop.window)
               overlay_clear(drop)
            }
            else if rect_inside(drop.bounds, {i32(mouse.pos.x), i32(mouse.pos.y)})
            {
               drop.state = 2
            }
            else
            {
               drop.state = 0
               element_set_invisible(drop.drop, true)
               hit = drop.drop
               element_redraw(drop.window)
               overlay_clear(drop)
            }
         }
      }
      else if drop.state == 2
      {
         if rect_inside(drop.drop.bounds, {i32(mouse.pos.x), i32(mouse.pos.y)})
         {
            hit = drop.drop
         }

         if card(mouse.button & {.LEFT, .RIGHT, .MIDDLE}) > 0
         {
            drop.state = 3
         }
      }
      else if drop.state == 3
      {
         if rect_inside(drop.drop.bounds, {i32(mouse.pos.x), i32(mouse.pos.y)})
         {
            hit = drop.drop
         }

         if card(mouse.button & {.LEFT, .RIGHT, .MIDDLE}) == 0
         {
            if rect_inside(drop.drop.bounds, {i32(mouse.pos.x), i32(mouse.pos.y)})
            {
               hit = drop.drop
               drop.state = 0

               element_set_invisible(drop.drop, true)

               element_redraw(drop.window)
               overlay_clear(drop)
            }
            else
            {
               drop.state = 0

               element_set_invisible(drop.drop, true)

               element_redraw(drop.window)
               overlay_clear(drop)
            }
         }
      }


      if drop.state != state_old
      {
         element_redraw(drop)
      }

      if hit != nil
      {
         handle_mouse(hit, mouse^)
      }

      mouse.handled = true

      return int(drop.state > 0)
   }
   else if msg == .DESTROY
   {
      delete(drop.text)
      element_destroy(drop.drop)
   }
   else if msg == .DRAW
   {
      dropdown_draw(drop)
   }

   return 0
}

@(private="file")
dropdown_draw :: proc(drop: ^DropDown)
{
   bounds: Rect = drop.bounds

   if drop.state != 0
   {
      draw_rectangle_fill(drop, bounds, {50, 50, 50, 255})
   }
   else
   {
      draw_rectangle_fill(drop, bounds, {90, 90, 90, 255})
   }

   draw_label(drop, bounds, drop.text, {0, 0, 0, 255}, true)
}
