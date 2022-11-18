switch("gc", "arc")
switch("threads", "on")

# Basically copied from https://github.com/treeform/nim_emscripten_tutorial
if defined(emscripten):
  --nimcache:tmp # Store intermediate files close by in the ./tmp dir.

  --os:linux # Emscripten pretends to be linux.
  --cpu:wasm32 # Emscripten is 32bits.
  --cc:clang # Emscripten is very close to clang, so we ill replace it.
  --passL: -sASYNCIFY # Needed for raylib to work
  when defined(windows):
    --clang.exe:emcc.bat  # Replace C
    --clang.linkerexe:emcc.bat # Replace C linker
    --clang.cpp.exe:emcc.bat # Replace C++
    --clang.cpp.linkerexe:emcc.bat # Replace C++ linker.
  else:
    --clang.exe:emcc  # Replace C
    --clang.linkerexe:emcc # Replace C linker
    --clang.cpp.exe:emcc # Replace C++
    --clang.cpp.linkerexe:emcc # Replace C++ linker.
  --listCmd # List what commands we are running so that we can debug them.

  --exceptions:goto # Goto exceptions are friendlier with crazy platforms.
  --define:noSignalHandler # Emscripten doesn't support signal handlers.

  # Pass this to Emscripten linker to generate html file scaffold for us.
  --passL:"-o index.html -sPTHREAD_POOL_SIZE=2 --shell-file shell.html"
  --passC:"-sUSE_PTHREADS=1"
