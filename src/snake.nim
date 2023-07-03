import pkg/[
  nimraylib_now,
  vmath
]

import std/[
  random,
  strformat,
  monotimes,
  times,
  os,
  tables,
  lenientops,
  json
]

import drawing, utils

{.experimental: "overloadableEnums".}

const
  background: Color = (0xff, 0xc2, 0x00)
  boardSize = 20
  squareSize = 15
  boardStart = ivec2(0, 30) # Start of game area
  boardPixLength = boardSize * squareSize
  moveTime = 166 # Move after this many milliseconds
  fruitNum = 1 # How much fruit to place
  epsilon = 0.00 # Chance to explore a random option
  learningRate = 0.7
  discount = 0.5
  saveFile = "snake.brain"

var highscore: int = 0

type
  GameState = object
    fruits, snake: seq[IVec2]
    gameOver: bool
    direction: IVec2
    score: int
    grow: bool

  RelativePos = enum
    Higher
    Lower
    Same

  QState = object
    ## Represents the Q-State of the snake
    leftOf, forward: RelativePos
    inDanger: array[3, bool]
  Action = enum
    Forward
    Left
    Right
  ActionArray = array[Action, float]
  QScores = Table[QState, array[Action, float]]

  HistoryItem = object
    state: QState
    distance: float # distance to fruit. 0 if they ate
    action: Action # Action that was taken
    gameOver: bool # If the game ended after action was taken

randomize()

proc loadScores(): QScores =
  if not saveFile.fileExists: return
  for line in saveFile.lines:
    let data = line.parseJson()
    result[data["state"].to(QState)] = data["scores"].to(ActionArray)

var
  scores: QScores = loadScores()
  history: seq[HistoryItem]
    ## History for episode
    ## Is a series of states and distance to the fruit

proc saveScores() =
  let file = saveFile.open(fmWrite)
  defer: file.close()
  for (state, scores) in scores.pairs:
    file.writeLine(%* {"state": state, "scores": scores})

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

func freePos(state: GameState, pos: IVec2): bool =
  ## Checks if a position is free (in bounds, not a snake part)
  result = pos notin state.snake and pos.x >= 0 and pos.y >= 0 and pos.x < boardSize and pos.y < boardSize

func dist(a, b: IVec2): float =
  let diff = a - b
  math.sqrt(float32(diff.x * diff.x) + float32(diff.y * diff.y))

func zeroSign(i: int): int =
  if i == 0: 0
  elif i > 0: 1
  else: -1

func sign(a: IVec2): IVec2 =
  result.x = zeroSign(a.x)
  result.y = zeroSign(a.y)

func handyPos(start, direction, point: IVec2): RelativePos =
  let
    a = start
    b = start + direction
    c = point
  let cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
  if cross == 0:
    Same
  elif cross < 0:
    Lower
  else:
    Higher

func magnitude(v: IVec2): int =
  ## Returns the magnitude of a vector (i.e its distance from 0, 0)
  v.x + v.y

func directionPos(start, direction, point: IVec2): RelativePos =
  let diff = magnitude((point - start) * direction)
  if diff == 0:
    Same
  elif diff < 0:
    Lower
  else:
    Higher

func turn(v: IVec2, action: Action): IVec2 =
  case action
  of Forward: v
  of Left: ivec2(v.y, v.x * -1)
  of Right: ivec2(v.y * -1, v.x)

func swap(v: IVec2): IVec2 =
  ## Swaps x and y and returns new vector
  result.x = v.y
  result.y = v.x

func applyAction(state: GameState, action: Action): IVec2 =
  ## Returns the position of the snake after applying an action
  state.snake[0] + state.direction.turn(action)

func initQState(state: GameState): QState =
  let headPos = state.snake[0]
  let fruit = state.fruits[0]
  QState(
    leftOf: handyPos(headPos, state.direction, fruit),
    forward: directionPos(headPos, state.direction, fruit),
    inDanger: [
        not state.freePos(state.applyAction(Left)),
        not state.freePos(state.applyAction(Right)),
        not state.freePos(state.applyAction(Forward))
    ]
  )

proc getScores(state: QState): ActionArray =
  if state notin scores:
    scores[state] = default(typeof result)
  scores[state]

proc bestAction(state: QState): Action =
  let scores = getScores(state)
  var highest = (Action.Forward, scores[Action.Forward])
  for action, score in scores:
    if score > highest[1]:
      highest = (action, score)
  result = highest[0]

proc updateScores() =
  for i in countdown(history.len - 1, 1):
    let
      item = history[i]
      prev = history[i - 1]
    var reward = 0
    if item.gameOver: # Bad snake, shouldn't die
      reward = -2
    elif item.distance == 0: # Rewarded since it ate something
      reward = 2
    elif item.distance < prev.distance: # Rewarded since it got closer
      reward = 1
    else: # Bad snake, don't run away
      reward = -1
    # echo reward
    # Drake, wheres the score?
    let
      score = getScores(item.state)[item.action]
      prevScore = getScores(prev.state)[prev.action]
    if item.gameOver:
      # Since there is no future state, we dont reward or something
      scores[item.state][item.action] = (1 - learningRate) * score + learningRate * reward
    else:
      scores[prev.state][prev.action] = (1 - learningRate) * prevScore + learningRate * (reward + discount * max(getScores(item.state)))

proc initGame(): GameState =
  result.snake &= ivec2(boardSize div 2)
  for i in 0..<fruitNum:
    result.fruits &= result.randomAvailableSpot()
  result.direction = ivec2(1, 0)
  result.grow = false

var
  state = initGame()
  newDirection = state.direction
  paused = false
  runChecks = false

proc step(state: var GameState) =
  let qstate = state.initQState()
  let action = if rand(1.0) < epsilon: sample({Left, Right, Forward})
               else: qstate.bestAction()
  state.direction = state.direction.turn(action)
  # Get new position
  let
    newPosition = state.snake[0] + state.direction
    distance = state.snake[0].dist(state.fruits[0])
  # Check snake isn't biting itself and in bounds
  if not state.freePos(newPosition):
    # echo newDirection
    # let pos = newPosition
    # echo pos notin state.snake, " ", pos.x >= 0, " ", pos.y >= 0, " ", pos.x < boardSize, " ", pos.y < boardSize
    # echo pos
    # echo state.snake
    # sleep 1000000
    state.gameOver = true
    return
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

  history &= HistoryItem(
    distance: distance,
    state: qstate,
    gameOver: state.gameOver,
    action: action
  )
  updateScores()

var epNum = 0

# while epNum < 100_000:
#   state.step()
#   if state.gameOver:
#     epNum += 1
#     if epNum mod 1000 == 0:
#       # echo "Saving..."
#       saveScores()
#       discard
#     echo "Episode ended: ", epNum
#     # Episode has ended, update the score table
#     # We ignore first item since no action was taken
#     history.setLen(0)
#     state = initGame()


when true:
  block:
    # setConfigFlags(VsyncHint or Msaa4xHint)
    let windowSize = boardStart + ivec2(boardSize * squareSize)
    initWindow(windowSize.x, windowSize.y, "Snake")
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
          if i == 0: (100, 50, 0)
          else: (0, min(57 + i * 5, 255), 0) # Add changing colour to snake
        )
      if state.gameOver:
        drawTextCenter("GAME OVER", boardStart + ivec2(boardPixLength div 2), 47, Pink)

      {.gcsafe.}:
        state.step()
        if state.gameOver:
          epNum += 1
          if epNum mod 1000 == 0:
            # echo "Saving..."
            saveScores()
            discard
          echo "Episode ended: ", epNum
          # Episode has ended, update the score table
          # We ignore first item since no action was taken
          history.setLen(0)
          state = initGame()
        sleep 100
  closeWindow()
