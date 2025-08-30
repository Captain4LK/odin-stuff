package gui

import "core:log"
import "core:fmt"
import "vendor:sdl3"

@(private="file")
id_next: u64 = 0

element_create :: proc($T: typeid, parent: ^Element, flags: ElementFlags, msg_base: MsgHandler) -> ^Element
{
   t := new(T)
   t.derived = t^
   t.flags = flags
   t.msg_base = msg_base
   t.id = id_next
   id_next += 1

   if parent != nil
   {
      t.window = parent.window

      if !t.flags.no_parent
      {
         t.parent = parent
         append(&parent.children, t)
      }

      if parent.flags.overlay
      {
         t.flags.overlay = true
      }
   }

   return t
}

element_msg :: proc(e: ^Element, msg: Msg, di: int, dp: rawptr) -> int
{
   if e == nil do return 0
   if e.flags.destroy && msg != .DESTROY do return 0

   if element_ignored(e)
   {
      #partial switch msg
      {
      case .MOUSE: return 0
      case .MOUSE_LEAVE: return 0
      case .DRAW: return 0
      case .GET_WIDTH: return 0
      case .GET_HEIGHT: return 0
      case .GET_CHILD_PAD: return 0
      }
   }

   if msg == .DRAW && e.flags.invisible do return 0
   if e.window.blocking != nil && (msg < .NO_BLOCK_START || msg > .NO_BLOCK_END) do return 0

   if e.msg_user != nil
   {
      res: int = e.msg_user(e, msg, di, dp)
      if res != 0 do return res
   }

   if e.msg_base != nil do return e.msg_base(e, msg, di, dp)

   return 0
}

element_msg_all :: proc(e: ^Element, msg: Msg, di: int, dp: rawptr) -> int
{
   if e == nil do return 0
   if e.flags.destroy && msg != .DESTROY do return 0
   if element_ignored(e) do return 0
   if e.flags.invisible && msg == .DRAW do return 0

   for child in e.children
   {
      element_msg_all(child, msg, di, dp)
   }

   element_msg(e, msg, di, dp)

   return 0
}

element_redraw :: proc(e: ^Element)
{
   if e.flags.overlay || e.flags.no_parent
   {
      element_redraw_now(e)
      return
   }

   e.window.redraw = true
   //e.needs_redraw = true
   //append(&e.window.redraw, e)
}

@(private="file")
element_redraw_now :: proc(e: ^Element)
{
   if e.flags.overlay
   {
      res: bool = sdl3.SetRenderTarget(e.window.sdl_renderer, e.window.sdl_overlay)
      if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())
   }
   else
   {
      res: bool = sdl3.SetRenderTarget(e.window.sdl_renderer, e.window.sdl_target)
      if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())
   }

   //fmt.printf("Draw\n")
   element_redraw_intern(e)

   res: bool = sdl3.SetRenderTarget(e.window.sdl_renderer, nil)
   if !res do log.errorf("SetRenderTarget failed: %v", sdl3.GetError())

   res = sdl3.RenderClear(e.window.sdl_renderer)
   if !res do log.errorf("RenderClear failed: %v", sdl3.GetError())

   res = sdl3.RenderTexture(e.window.sdl_renderer, e.window.sdl_target, nil, nil)
   if !res do log.errorf("RenderTexture failed: %v", sdl3.GetError())

   res = sdl3.RenderTexture(e.window.sdl_renderer, e.window.sdl_overlay, nil, nil)
   if !res do log.errorf("RenderTexture failed: %v", sdl3.GetError())

   sdl3.RenderPresent(e.window.sdl_renderer)
}

element_redraw_msg :: proc(e: ^Element)
{
   e.window.clip = {{-1, -1}, {-1, -1}}
   e.window.translation = {0, 0}
   draw_disable_clip(e)
   element_redraw_intern(e)
}

element_layout :: proc(e: ^Element, space: Rect)
{
   element_calculate_width(e)
   if !e.flags.overlay
   {
      element_calculate_grow_width(e, space.max - space.min)
   }
   else
   {
      element_calculate_grow_width(e, {e.size.x, space.max.y - space.min.y})
   }
   element_calculate_height(e)
   element_calculate_grow_height(e, space.max - space.min)
   element_calculate_position(e, {space.min, space.min + e.size})
   // TODO: for floating containers, given size is calculated size of e
}

element_by_point :: proc(e: ^Element, pt: [2]f32) -> ^Element
{
   old_trans: [2]i32 = e.window.translation
   e.window.translation += e.translate

   for i := 0; i < len(e.children); i += 1
   {
      child: ^Element = e.children[i]

      if element_ignored(child) do continue

      b: Rect = child.bounds
      b.min += e.window.translation
      b.max += e.window.translation
      if pt[0] >= f32(b.min[0]) && pt[1] >= f32(b.min[1]) &&
         pt[0] <= f32(b.max[0]) && pt[1] <= f32(b.max[1])
      {
         leaf: ^Element = element_by_point(child, pt)
         if leaf != nil do return leaf
         return child
      }
   }

   e.window.translation = old_trans
   
   return nil
}

element_set_invisible :: proc(e: ^Element, invisible: bool)
{
   e.flags.invisible = invisible

   for i := 0; i < len(e.children); i += 1
   {
      element_set_invisible(e.children[i], invisible)
   }
}

element_ignored :: proc(e: ^Element) -> bool
{
   if e == nil do return false
   if e.flags.ignore do return true
   return element_ignored(e.parent)
}

element_destroy :: proc(e: ^Element)
{
   for i := 0; i < len(e.children); i += 1
   {
      element_destroy(e.children[i])
   }

   element_msg(e, .DESTROY, 0, nil)
   delete(e.children)
   free(e)
}

@(private="file")
element_redraw_intern :: proc(e: ^Element)
{
   if e.flags.invisible || element_ignored(e) do return

   element_msg(e, .DRAW, 0, nil)

   old_clip: Rect = e.window.clip
   if e.flags.clip
   {
      draw_set_clip_rect(e, e.bounds)
      e.window.clip = e.bounds
   }

   old_trans: [2]i32 = e.window.translation
   e.window.translation += e.translate

   for i := 0; i < len(e.children); i += 1
   {
      element_redraw_intern(e.children[i])
   }

   if e.flags.clip
   {
      if old_clip == {{-1, -1}, {-1, -1}}
      {
         draw_disable_clip(e)
      }
      else
      {
         draw_set_clip_rect(e, old_clip)
         e.window.clip = old_clip
      }
   }

   e.window.translation = old_trans
}

@(private="file",rodata)
layout_axes: [Layout][2]int = {.VERTICAL= {1,0}, .HORIZONTAL = {0,1}}

@(private="file")
element_calculate_width :: proc(e: ^Element)
{
   major: int = layout_axes[e.flags.layout][0]
   minor: int = layout_axes[e.flags.layout][1]
   size: [2]i32

   e.size = {0, 0}

   for child in e.children
   {
      element_calculate_width(child)

      size[major] += child.size[major]
      size[minor] = max(child.size[minor], size[minor])
   }

   size += e.pad[0] + e.pad[1]
   size[minor] += e.child_gap * i32(len(e.children) - 1)
   space: [2]i32 = {size[0], 0}
   e.size[0] = i32(element_msg(e, .GET_WIDTH, 0, &space))
}

@(private="file")
element_calculate_height :: proc(e: ^Element)
{
   major: int = layout_axes[e.flags.layout][0]
   minor: int = layout_axes[e.flags.layout][1]
   size: [2]i32

   for child in e.children
   {
      element_calculate_height(child)

      size[major] += child.size[major]
      size[minor] = max(child.size[minor], size[minor])
   }

   size += e.pad[0] + e.pad[1]
   size[minor] += e.child_gap * i32(len(e.children) - 1)
   space: [2]i32 = {size[1], e.size[0]}
   e.size[1] = i32(element_msg(e, .GET_HEIGHT, 0, &space))
}

element_calculate_grow_width :: proc(e: ^Element, available: [2]i32)
{
   major: int = layout_axes[e.flags.layout][0]
   minor: int = layout_axes[e.flags.layout][1]

   child_pad: [2][2]i32
   element_msg(e, .GET_CHILD_PAD, 0, &child_pad)

   available := available
   available -= e.pad[0] + e.pad[1] + child_pad[0] + child_pad[1]

   for child in e.children
   {
      available[major] -= child.size[major]
   }
   available[major] -= e.child_gap * i32(len(e.children) - 1)

   // Expand against layout direction
   for child in e.children
   {
      fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
      if fill[minor] && minor == 0 do child.size[minor] = available[minor]
   }

   // Expand in layouting direction
   remaining: i32 = available[major]
   for remaining > 0
   {
      smallest: i32 = max(i32)
      second_smallest: i32 = max(i32)
      to_add: i32 = remaining
      if major != 0 do break

      for child in e.children
      {
         size: i32 = child.size[major]
         fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
         if !fill[major] do continue

         if size < smallest
         {
            second_smallest = smallest
            smallest = size
         }

         if size > smallest
         {
            second_smallest = min(second_smallest, size)
         }
      }

      if second_smallest != max(i32)
      {
         to_add = second_smallest - smallest
      }
      to_add = min(remaining, to_add)

      num_to_add: int = 0
      for child in e.children
      {
         size: i32 = child.size[major]
         fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
         if !fill[major] do continue

         if size == smallest do num_to_add += 1
      }

      if num_to_add == 0 do break

      cur: int = 0
      rem: int = int(to_add) % num_to_add
      for child in e.children
      {
         size: i32 = child.size[major]
         fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
         if !fill[major] do continue

         if size != smallest do continue

         add: i32 = to_add / i32(num_to_add)
         if cur < rem do add += 1
         child.size[major] += add
         remaining -= add
         cur += 1
      }
   }

   // Children
   for child in e.children
   {
      element_calculate_grow_width(child, child.size)
   }
}

element_calculate_grow_height:: proc(e: ^Element, available: [2]i32)
{
   major: int = layout_axes[e.flags.layout][0]
   minor: int = layout_axes[e.flags.layout][1]

   child_pad: [2][2]i32
   element_msg(e, .GET_CHILD_PAD, 0, &child_pad)

   available := available
   available -= e.pad[0] + e.pad[1] + child_pad[0] + child_pad[1]

   for child in e.children
   {
      available[major] -= child.size[major]
   }
   available[major] -= e.child_gap * i32(len(e.children) - 1)

   // Expand against layout direction
   for child in e.children
   {
      fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
      if fill[minor] && minor == 1 do child.size[minor] = available[minor]
   }

   // Expand in layouting direction
   remaining: i32 = available[major]
   for remaining > 0
   {
      smallest: i32 = max(i32)
      second_smallest: i32 = max(i32)
      to_add: i32 = remaining
      if major != 1 do break

      for child in e.children
      {
         size: i32 = child.size[major]
         fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
         if !fill[major] do continue

         if size < smallest
         {
            second_smallest = smallest
            smallest = size
         }

         if size > smallest
         {
            second_smallest = min(second_smallest, size)
         }
      }

      if second_smallest != max(i32)
      {
         to_add = second_smallest - smallest
      }
      to_add = min(remaining, to_add)

      num_to_add: int = 0
      for child in e.children
      {
         size: i32 = child.size[major]
         fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
         if !fill[major] do continue

         if size == smallest do num_to_add += 1
      }

      if num_to_add == 0 do break

      cur: int = 0
      rem: int = int(to_add) % num_to_add
      for child in e.children
      {
         size: i32 = child.size[major]
         fill: [2]bool = {child.flags.fill_x, child.flags.fill_y}
         if !fill[major] do continue

         if size != smallest do continue

         add: i32 = to_add / i32(num_to_add)
         if cur < rem do add += 1
         child.size[major] += add
         remaining -= add
         cur += 1
      }
   }

   // Children
   for child in e.children
   {
      element_calculate_grow_height(child, child.size)
   }
}

@(private="file")
element_calculate_position :: proc(e: ^Element, available: Rect)
{
   e.bounds = available
   e.size_children = {0, 0}
   major: int = layout_axes[e.flags.layout][0]
   minor: int = layout_axes[e.flags.layout][1]

   child_pad: [2][2]i32
   element_msg(e, .GET_CHILD_PAD, 0, &child_pad)

   child_space: Rect = e.bounds
   child_space.min += e.pad[0] + child_pad[0]
   child_space.max -= e.pad[1] + child_pad[1]
   for child in e.children
   {
      if element_ignored(child) do continue

      element_calculate_position(child, {child_space.min, child_space.min + child.size})
      child_space.min[major] += child.size[major]
      child_space.min[major] += e.child_gap

      e.size_children[major] += child.size[major] + e.child_gap
      e.size_children[minor] = max(e.size_children[minor], child.size[minor])
   }
}
