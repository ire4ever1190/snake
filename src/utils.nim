import nimraylib_now

proc anyPressed*(keys: varargs[KeyboardKey]): bool =
  for key in keys:
    if isKeyPressed(key):
      return true
