## Contains more drawing procs (Mostly just overloads for using vec)

import vmath
import nimraylib_now


template drawRectProc(name: untyped) =
  proc name*(pos: IVec2, size: IVec2, color: Color) =
    name(pos.x, pos.y, size.x, size.y, color)

drawRectProc(drawRectangle)
drawRectProc(drawRectangleLines)

proc drawText*(text: string, pos: IVec2, size: int, color: Color) =
  drawText(cstring(text), pos.x, pos.y, size, color)

proc drawTextCenter*(text: string, pos: IVec2, size: int, color: Color) =
  ## like drawText except the center of the text will be `pos`
  let 
    length = measureText(cstring(text), size)
    height = size
    newPos = pos - ivec2(length div 2, height div 2)
  drawText(text, newPos, size, color)

proc drawLine*(a, b: IVec2, color: Color) =
  drawLine(a.x, a.y, b.x, b.y, color)
