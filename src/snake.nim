import pkg/[
  nimraylib_now,
  vmath
]

import std/random

import drawing, utils

{.experimental: "overloadableEnums".}

const 
  background: Color = (0xff, 0xc2, 0x00)
  boardSize = 10
  squareSize = 30
  boardStart = ivec2(30, 30) # Start of game area

var scores: seq[int]

type
  GameState = object
    fruits, snake: seq[IVec2]
    gameOver: bool
    step: int
    direction: IVec2
    score: int
    grow: bool

randomize()

proc randomAvailableSpot(g: GameState): IVec2 =
  ## Returns a position that isn't a fruit or snake piece
  while true:
    let 
      x = rand(0..<boardSize)
      y = rand(0..<boardSize)
      pos = ivec2(x, y)
    if pos notin g.fruits and pos notin g.snake:
      return pos 
      
func incStep(g: var GameState) =
  g.step = (g.step + 1) mod 10



proc initGame(): GameState = 
  result.snake &= result.randomAvailableSpot()
  echo result.snake.len
  result.fruits &= result.randomAvailableSpot()
  result.direction = ivec2(1, 0)
  result.grow = false
    
var 
  state = initGame()
  newDirection = state.direction


initWindow(800, 450, "Example")
setTargetFPS(60)

while not windowShouldClose():
  # Check input
  if not state.gameOver:
    newDirection = if anyPressed(KeyboardKey.Right, KeyboardKey.D):
      ivec2(1, 0)
    elif anyPressed(KeyboardKey.Left, KeyboardKey.A):
      ivec2(-1, 0)
    elif anyPressed(KeyboardKey.Up, KeyboardKey.W):
      ivec2(0, -1)
    elif anyPressed(KeyboardKey.Down, KeyboardKey.S):
      ivec2(0, 1)
    else: 
      newDirection
    
  else:
    if isKeyPressed(KeyboardKey.Enter):
      scores &= state.score
      state = initGame()
      continue
  state.incStep()

  let runChecks = state.step == 0
  # Move snake forward
  if runChecks and not state.gameOver:
    # Check not going back on itself
    if newDirection.abs != state.direction.abs:
      state.direction = newDirection
    # Get new position
    let newPosition = state.snake[0] + state.direction
    # Check snake isn't biting itself and in bounds
    if newPosition in state.snake or newPosition.x notin 0..<boardSize or newPosition.y notin 0..<boardSize:
      state.gameOver = true
    # If we got a fruit last round then don't remove tail so we 'grow'
    if not state.gameOver:
      if not state.grow:
        discard state.snake.pop()
      state.snake.insert(newPosition, 0)    
    state.grow = false
    
  beginDrawing:
    clearBackground(RayWhite)
    # Render score
    drawText(cstring("You're score is " & $state.score), 10, 10, 20, Black)
    # Render previous scores
    # for i in 0..<scores.len:
      # drawText($score, boardStart + ivec2(squareSize * boardSize) + ivec2(10), 20, Black)
    if state.gameOver:
      drawText("GAME OVER", 50, 50, 20, Red)
    # Draw walls
    drawRectangleLines(boardStart, ivec2(squareSize * boardSize), Black)
    # Render board and check if snake intersecting with fruit
    var fruitHit = -1
    for i in 0..<state.fruits.len:
      let pos = state.fruits[i]
      drawRectangle(
        boardStart + pos * squareSize, 
        ivec2(squareSize, squareSize), 
        Red
      )
      if pos == state.snake[0] and runChecks:
        fruitHit = i
    # If a fruit was collided with then remove it, replace it, add score to player
    # and set flag to grow next check
    if fruitHit != -1:
      state.fruits.del(fruitHit)
      state.score += 1
      state.grow = true
      state.fruits &= state.randomAvailableSpot()
      
    for i in 0..<state.snake.len:
      let pos = state.snake[i]
      drawRectangle(
        boardStart + pos * squareSize, 
        ivec2(squareSize, squareSize),
        (0, min(57 + i * 5, 255), 0) # Add changing colour to snake
      )
closeWindow()
