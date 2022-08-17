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
