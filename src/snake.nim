import pkg/[
  nimraylib_now,
  vmath
]

import std/[
  random,
  strformat,
  monotimes,
  times,
  os
]

import drawing, utils

{.experimental: "overloadableEnums".}

const 
  background: Color = (0xff, 0xc2, 0x00)
  boardSize = 10
  squareSize = 30
  boardStart = ivec2(0, 30) # Start of game area
  boardPixLength = boardSize * squareSize
  moveTime = 166 # Move after this many milliseconds

var highscore: int = 0

type
  GameState = object
    fruits, snake: seq[IVec2]
    gameOver: bool
    direction: IVec2
    score: int
    grow: bool

randomize()

proc randomAvailableSpot(g: GameState): IVec2 =
  ## Returns a position that isn't a fruit or snake piece
  # From benchmarking, linear scan vs hashset seems to give similar performance
  var availableSpots = newSeqOfCap[IVec2](boardSize * boardSize - g.snake.len)
  for x in 0..<boardSize:
    for y in 0..<boardSize:
      let pos = ivec2(x, y)
      if pos notin g.fruits and pos notin g.snake:
        availableSpots &= pos
  if availableSpots.len > 0:
    result = availableSpots.sample()
  else:
    result = ivec2(-1, -1)
      
proc initGame(): GameState = 
  result.snake &= ivec2(boardSize div 2)
  for i in 0..<3:
    result.fruits &= result.randomAvailableSpot()
  result.direction = ivec2(1, 0)
  result.grow = false
    
var 
  state = initGame()
  newDirection = state.direction
  paused = false
  runChecks = false
  
block:
  setConfigFlags(VsyncHint or Msaa4xHint)
  let windowSize = boardStart + ivec2(boardSize * squareSize)
  initWindow(windowSize.x, windowSize.y, "Snake")
  
proc logicLoop() {.thread.} =
  {.cast(gcsafe).}: # Trust me bro this is GC safe
    var start = getMonoTime()
    while true:
      if not state.gameOver:
        template handlePress(a, b: KeyboardKey, d: IVec2) =
          if anyPressed(a, b): newDirection = d
        handlePress(KeyboardKey.Right, KeyboardKey.D, ivec2(1, 0))
        handlePress(KeyboardKey.Left,  KeyboardKey.A, ivec2(-1, 0))
        handlePress(KeyboardKey.Up,    KeyboardKey.W, ivec2(0, -1))
        handlePress(KeyboardKey.Down,  KeyboardKey.S, ivec2(0, 1))
         
        if isKeyPressed(SPACE):
          paused = not paused
          start = getMonoTime()
      else:
        if anyPressed(KeyboardKey.Left, KeyboardKey.Right, Up, Down, A, W, S, D):
          state = initGame()
          continue
          
      runChecks = (getMonoTime() - start).inMilliseconds >= moveTime and not paused
      # Move snake forward
      if runChecks and not state.gameOver:
        start = getMonoTime()
        # Check not going back on itself
        if newDirection.abs != state.direction.abs:
          state.direction = newDirection
        # Get new position
        let newPosition = state.snake[0] + state.direction
        # Check snake isn't biting itself and in bounds
        if newPosition in state.snake[0 ..< ^1] or newPosition.x notin 0..<boardSize or newPosition.y notin 0..<boardSize:
          state.gameOver = true
        # If we got a fruit last round then don't remove tail so we 'grow'
        if not state.gameOver:
          if not state.grow:
            discard state.snake.pop()
          state.snake.insert(newPosition, 0)    
          state.grow = false
          # Check if the snake ate any fruit
          let fruitHit = state.fruits.find(state.snake[0])
              
          if fruitHit != -1:
            state.fruits.del(fruitHit)
            state.score += 1
            if state.score > highScore:
              highscore = state.score
            state.grow = true
            # Add in fruit to replace the lost one
            let newFruit = state.randomAvailableSpot()
            if newFruit.x != -1:
              state.fruits &= newFruit
      sleep 1 # Lets not use all the CPU, tone it down a bit
var logicThread: Thread[void]
createThread(logicThread, logicLoop)

while not windowShouldClose():
  # Check input
  beginDrawing:
    clearBackground(RayWhite)
    # Render score
    drawText(cstring(fmt"Score: {state.score} High score: {highscore}"), 10, 10, 20, Pink)
    # Draw walls
    drawLine(boardStart, boardStart + ivec2(boardPixLength, 0), Black)
    # Render board and check if snake intersecting with fruit
    for i in 0..<state.fruits.len:
      let pos = state.fruits[i]
      drawRectangle(
        boardStart + pos * squareSize, 
        ivec2(squareSize, squareSize), 
        (139, 198, 252)
      )
      
    for i in 0..<state.snake.len:
      let pos = state.snake[i]
      drawRectangle(
        boardStart + pos * squareSize, 
        ivec2(squareSize, squareSize),
        (0, min(57 + i * 5, 255), 0) # Add changing colour to snake
      )
    if state.gameOver:
      drawTextCenter("GAME OVER", boardStart + ivec2(boardPixLength div 2), 47, Pink)
      
closeWindow()
