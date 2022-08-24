import nimraylib_now

proc anyPressed*(keys: varargs[KeyboardKey]): bool =
  for key in keys:
    if isKeyDown(key):
      return true
