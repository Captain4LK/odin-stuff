package gui

import "core:log"
import "vendor:sdl3"
import "core:fmt"

import "../prof"

DragGroup :: struct
{
   using element: Element,

   direction: DragGroupDirection,
   drag_size: i32,
   state: bool,
}

DragGroupDirection :: enum
{
   North,
   South,
   West,
   East,
}

draggroup_create :: proc(parent: ^Element, flags: ElementFlags, direction: DragGroupDirection) -> ^DragGroup
{
   prof.SCOPED_EVENT(#procedure)

   group: ^DragGroup = &element_create(DragGroup, parent, flags, draggroup_msg).derived.(DragGroup)
   group.direction = direction
   group.drag_size = 128

   return group
}

@(private="file")
draggroup_msg :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   group: ^DragGroup = &e.derived.(DragGroup)

   if msg == .GET_WIDTH
   {
      space: ^[2]i32 = cast(^[2]i32)dp

      if group.direction == .West ||
         group.direction == .East
      {
         return i64(group.drag_size)
      }
      return i64(space[0])
      /*
      if group.flags.style == 0
      {
         return int(max(space[0], group.size_min[0]))
      }
      else if group.flags.style == 1
      {
         return int(max(space[0], group.size_min[0])) + 2 * int(get_scale())
      }
      */
   }
   else if msg == .GET_HEIGHT
   {
      space: ^[2]i32 = cast(^[2]i32)dp

      if group.direction == .North ||
         group.direction == .South
      {
         return i64(group.drag_size)
      }
      return i64(space[0])

      /*
      if group.flags.style == 0
      {
         return int(max(space[0], group.size_min[1]))
      }
      else if group.flags.style == 1
      {
         return int(max(space[0], group.size_min[1])) + 2 * int(get_scale())
      }
      */
   }
   else if msg == .GET_CHILD_PAD
   {
      pad: ^[2][2]i32 = cast(^[2][2]i32)dp

      if group.direction == .West
      {
         pad[0][0] = get_scale() * 4
      }
      else if group.direction == .East
      {
         pad[1][0] = get_scale() * 4
      }
      /*
      if group.flags.style == 1
      {
         pad[0][0] = get_scale()
         pad[0][1] = get_scale()
         pad[1][0] = get_scale()
         pad[1][1] = get_scale()
      }
      */
   }
   else if msg == .MOUSE
   {
      mouse: ^Mouse = cast(^Mouse)dp

      if group.state
      {
         mouse.handled = true
      }

      /*
      click: bool = false
      state_old: bool = button.state
      if card(mouse.button & {.LEFT, .RIGHT, .MIDDLE}) > 0
      {
         button.state = true
         mouse.handled = true
      }
      else
      {
         click = button.state
         button.state = false
      }

      if click || state_old != button.state
      {
         element_redraw(button)
      }

      if click
      {
         element_msg(button, .CLICK, 0, nil)
         button.state = false
      }
      */
   }
   else if msg == .DRAW
   {
      draggroup_draw(group)
   }

   return 0
}

@(private="file")
draggroup_draw :: proc(group: ^DragGroup)
{
   bounds: Rect = group.bounds
   scale: i32 = get_scale()

   if group.direction == .West
   {
      //fmt.printf("Draw\n")
      draw_rectangle_fill(group, {{bounds.min.x, bounds.min.y}, 
         {bounds.min.x + scale * 1, bounds.max.y}}, {50, 50, 50, 255})
      draw_rectangle_fill(group, {{bounds.min.x + scale * 1, bounds.min.y}, 
         {bounds.min.x + scale * 3, bounds.max.y}}, {90, 90, 90, 255})
      draw_rectangle_fill(group, {{bounds.min.x + scale * 3, bounds.min.y}, 
         {bounds.min.x + scale * 4, bounds.max.y}}, {200, 200, 200, 255})
      //draw_rectangle_fill(group, {{bounds.min.x, bounds.min.y}, 
         //{bounds.min.x + scale * 2, bounds.max.y}}, {90, 90, 90, 255})
      //draw_rectangle_fill(group, {{bounds.min.x + scale * 2, bounds.min.y}, 
         //{bounds.max.x + scale, bounds.max.y}}, {90, 90, 90, 255})
   }
   else if group.direction == .East
   {
      /*draw_rectangle_fill(img, {{middle - 2 * scale, bounds.min.y + 3 * scale}, 
         {middle - scale, bounds.max.y - 3 * scale}}, {50, 50, 50, 255})
      draw_rectangle_fill(img, {{middle + scale, bounds.min.y + 3 * scale}, 
         {middle + 2 * scale, bounds.max.y - 3 * scale}}, {200, 200, 200, 255})*/
   }
   /*
   if group.flags.style == 0
   {
      draw_rectangle_fill(group, group.bounds, {90, 90, 90, 255})
   }
   else if group.flags.style == 1
   {
      draw_rectangle_fill(group, group.bounds, {90, 90, 90, 255})
      draw_rectangle(group, group.bounds, {0, 0, 0, 255})
   }
   */
}
