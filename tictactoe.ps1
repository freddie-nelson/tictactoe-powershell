# Types
enum CellType {
  x = 0
  o = 1
  empty = 2 
}

enum BoardState {
  inProgress = 0
  xWon = 1
  oWon = 2
  draw = 3
}

enum OpponentType {
  local = 0
  online = 1
  computer = 2
}

enum DifficultyType {
  easy = 0
  medium = 1
  hard = 2
}

# Input functions

function Read-Input {
  param (
    [Parameter(Mandatory = $true)]
    [string[]]$allowedInput,
    [Parameter(Mandatory = $true)]
    [string]$prompt
  )

  if ($allowedInput.Length -eq 0) {
    throw "Allowed input is empty"
  }

  $userInput = '' 
  while ($true) {
    $userInput = Read-Host -Prompt $prompt 
      
    foreach ($allowed in $allowedInput) {
      if ($userInput -eq $allowed) {
        return $userInput
      }
    }
  }

}

# Output functions
$borderWidth = $Host.UI.RawUI.BufferSize.Width

function Write-Border {
  Write-Host "".PadLeft($borderWidth, '#')
}

function Write-Title {
  param (
    [Parameter()]
    [String]
    $Title
  )

  if ($Title -eq $null) {
    $Title = ""
  }

  $paddingSize = ($borderWidth - $Title.Length) / 2 - 1
  $extraRightPadding = 0
  if ($paddingSize - [Math]::Floor($paddingSize) -gt 0) {
    $extraRightPadding = 1
  }
  $paddingSize = [Math]::Floor($paddingSize) 

  Write-Host "#$(''.PadLeft($paddingSize, ' '))$Title$(''.PadRight($paddingSize + $extraRightPadding, ' '))#"
}

function Write-Banner {
  param (
    [String]$Title, [Switch]$NoTop
  )
    

  if (!$NoTop) {
    Write-Border
  }

  Write-Title $Title
  Write-Border
}


function Write-Board {
  param (
    [Parameter(Mandatory = $true)]
    [CellType[]]
    $board
  )

  Write-Title ""

  for ($i = 0; $i -lt 3; $i++) {
    $1 = Get-CellAsStr $board[$i * 3]
    $2 = Get-CellAsStr $board[$i * 3 + 1]
    $3 = Get-CellAsStr $board[$i * 3 + 2]

    Write-Title "$1 | $2 | $3"

    if ($i -lt 2) {
      Write-Title "---|---|---"
    }
  }

  Write-Title ""
  Write-Border 
}

function Get-CellAsStr {
  param (
    [Parameter(Mandatory = $true)]
    [CellType] 
    $cell
  )

  if ($cell -eq [CellType]::x) {
    return "X"
  }
  elseif ($cell -eq [CellType]::o) {
    return "O"
  }
  else {
    return " "
  }
}

function Write-Cell {
  param (
    [Parameter(Mandatory = $true)]
    [CellType] 
    $cell
  )

  Get-CellAsStr $cell | Write-Host 
}

# Game Functions
function Select-Opponent {
  Clear-Host
  Write-Banner "Select Opponent"
  Write-Banner "[1] Local" -NoTop
  Write-Banner "[2] Online" -NoTop
  Write-Banner "[3] Computer" -NoTop
  
  $playerInput = Read-Input -AllowedInput '1', '2', '3' -Prompt "Enter 1-3 to select an opponent"

  if ($playerInput -eq '1') {
    return [OpponentType]::local
  }
  elseif ($playerInput -eq '2') {
    return [OpponentType]::online
  }
  else {
    return [OpponentType]::computer
  }
}

function Select-IsHost {
  Clear-Host
  Write-Banner "Are you hosting or joining?"
  Write-Banner "[1] Hosting" -NoTop
  Write-Banner "[2] Joining" -NoTop
  
  $playerInput = Read-Input -AllowedInput '1', '2' -Prompt "Enter 1-2 to select"
  
  if ($playerInput -eq '1') {
    return $true
  }
  else {
    return $false
  }
}

function Select-ComputerDifficulty {
  Clear-Host 
  Write-Banner "Select Computer Difficulty"
  Write-Banner "[1] Easy" -NoTop
  Write-Banner "[2] Medium" -NoTop
  Write-Banner "[3] Hard" -NoTop
  
  $playerInput = Read-Input -AllowedInput '1', '2', '3' -Prompt "Enter 1-3 to select the computer's difficulty"

  if ($playerInput -eq '1') {
    return [DifficultyType]::easy
  }
  elseif ($playerInput -eq '2') {
    return [DifficultyType]::medium
  }
  else {
    return [DifficultyType]::hard
  }
}

# multiplayer variables
$onlineInited = $false
$isHost = $false
$server = $null
$opponentConnection = $null

function Start-Game {
  global $onlineInited, $isHost, $server, $opponentConnection

  $onlineInited = $false
  $isHost = $false
  $server = $null
  $opponentConnection = $null

  $board = New-Board
  $state = [BoardState]::inProgress

  $opponent = $null
  if ($onlineInited) {
    $opponent = [OpponentType]::online
  }
  else {
    $opponent = Select-Opponent
  }

  $computerDifficulty = [DifficultyType]::easy
  if ($opponent -eq [OpponentType]::computer) {
    $computerDifficulty = Select-ComputerDifficulty
  }


  if ($opponent -eq [OpponentType]::online -and -not $onlineInited) {
    $isHost = Select-IsHost

    if ($isHost) {
      $server = New-Server
      $opponentConnection = Wait-ForClientConnection -Server $server
    }
    else {
      Write-Banner "Enter the server's IP address or hostname"
      $serverName = Read-Host -Prompt "Enter IP address or hostname"
      $opponentConnection = New-Client -Server $serverName
    }

    $onlineInited = $true
  } 

  $opponentStream = $null

  if ($onlineInited) {
    $opponentStream = $opponentConnection.GetStream()
  }

  # choose starting player
  # opponent is always o and player is always x
  # opponent can be human or computer
  $randomStart = Get-Random -Minimum 0 -Maximum 2 # random integer 0 or 1

  # send/receive starting starting player when playing online
  if ($opponent -eq [OpponentType]::online) {
    if ($isHost) {
      Send-Message -Stream $opponentStream -message $randomStart
    }
    else {
      $randomStart = [int](Receive-Message -Stream $opponentStream)
    }
  }

  $turn = [CellType]::x
  if ($randomStart -eq 1) {
    $turn = [CellType]::o
  }

  while ($state -eq [BoardState]::inProgress) {
    Clear-Host
    Write-Banner "TicTacToe"
    Write-Board $board
    Write-Banner  "Player $(Get-CellAsStr $turn)'s turn. " -NoTop
    Write-Banner "Enter a number between 1 and 9 to make your move." -NoTop
    Write-Banner "If you would like to exit, press 'q'." -NoTop 

    if ($opponent -eq [OpponentType]::local) {
      $playerInput = Read-Input -AllowedInput '1', '2', '3', '4', '5', '6', '7', '8', '9', 'q' -Prompt "Enter 1-9 or 'q' to quit"
    }
    elseif ($opponent -eq [OpponentType]::online) {
      if (($turn -eq [CellType]::x -and $isHost) -or ($turn -eq [CellType]::o -and !$isHost)) {
        $playerInput = Read-Input -AllowedInput '1', '2', '3', '4', '5', '6', '7', '8', '9', 'q' -Prompt "Enter 1-9 or 'q' to quit"
        Send-Message -Stream $opponentStream -Message $playerInput
      }
      else {
        Write-Banner "Waiting for position from opponent..." -NoTop
        $playerInput = Receive-Message -Stream $opponentStream
      }
    }
    else {
      if ($turn -eq [CellType]::x) {
        $playerInput = Read-Input -AllowedInput '1', '2', '3', '4', '5', '6', '7', '8', '9', 'q' -Prompt "Enter 1-9 or 'q' to quit"
      }
      else {
        $playerInput = Get-ComputerMove -Board $board -Turn $turn -Difficulty $computerDifficulty
      }
    }

    if ($playerInput -eq 'q') {
      Write-Banner "Player quit" 
      exit
    }

    $cell = [int]$playerInput - 1
    if ($board[$cell] -ne [CellType]::empty) {
      # if not the computer or online opponents turn, display message
      if (-not ($opponent -ne [OpponentType]::online -and $turn -eq [CellType]::o)) {
        Write-Banner "That cell is already taken."
        Start-Sleep 1
      }

      continue
    }

    $board[$cell] = $turn

    # get new state of board
    $state = Get-BoardState $board

    # switch turns
    $turn = Get-NextTurn $turn
  }

  Clear-Host
  Write-Banner "TicTacToe"
  Write-Board $board

  if ($state -eq [BoardState]::Draw) {
    Write-Banner "The game was a draw!" -NoTop 
  }
  elseif ($state -eq [BoardState]::xWon) {
    Write-Banner "The winner is $(Get-CellAsStr x)!" -NoTop 
  }
  else {
    Write-Banner "The winner is $(Get-CellAsStr o)!" -NoTop 
  }

  Write-Banner "If you want to play again, press 'r'." -NoTop
  Write-Banner "If you would like to exit, press 'q'." -NoTop

  $playerInput = ''
  if ($opponent -ne [OpponentType]::online -or $isHost) {
    $playerInput = Read-Input -AllowedInput 'r', 'q' -Prompt "Enter 'r' to play again or 'q' to quit"

    if ($isHost) {
      Send-Message -Stream $opponentStream -message $playerInput
    }
  }
  else {
    Write-Banner "Waiting for host to continue or quit..." -NoTop

    $playerInput = Receive-Message -Stream $opponentStream
  }

  # close online connections
  if ($playerInput -eq 'q') {
    Write-Banner "Player quit"

    if ($opponent -eq [OpponentType]::online) {
      $opponentStream.Close()
      $opponentConnection.Close()

      if ($isHost) {
        $server.Stop()
      }
    }

    exit
  }
  else {
    Start-Game 
  }
}

function New-Board {
  $value = [CellType]::empty

  return @(
    $value, $value, $value,
    $value, $value, $value,
    $value, $value, $value
  )
}

function Get-NextTurn {
  param (
    [Parameter(Mandatory = $true)]
    [CellType] 
    $turn
  )

  if ($turn -eq [CellType]::x) {
    return [CellType]::o
  }
  else {
    return [CellType]::x
  }
}

function Get-BoardState {
  param (
    [Parameter(Mandatory = $true)]
    [CellType[]]
    $board
  )
  
  $players = @([CellType]::x, [CellType]::o)
  $winPatterns = @(
    @(0, 1, 2),
    @(3, 4, 5),
    @(6, 7, 8),
    @(0, 3, 6),
    @(1, 4, 7),
    @(2, 5, 8),
    @(0, 4, 8),
    @(2, 4, 6)
  )

  foreach ($player in $players) {
    foreach ($winPattern in $winPatterns) {
      $count = 0
      foreach ($cell in $winPattern) {
        if ($board[$cell] -eq $player) {
          $count++
        }
      }

      # a player has won so return winner state
      if ($count -eq 3) {
        if ($player -eq [CellType]::x) {
          return [BoardState]::xWon
        }
        else {
          return [BoardState]::oWon
        }
      }
    }
  }

  # no winner so check for draw
  $emptyCells = Get-EmptyCells $board

  # if all cells are filled then return draw state as no win
  if ($emptyCells.Length -eq 0) {
    return [BoardState]::Draw
  }
  
  # otherwise return in progress state
  return [BoardState]::inProgress
}

# must return a random integer between 1 and 9, representing a cell on the board
function Get-ComputerMove {
  param (
    [Parameter(Mandatory = $true)]
    [CellType[]]
    $board,
    [CellType]
    $turn,
    [DifficultyType]
    $difficulty
  )

  Write-Host "Computer is thinking..."

  if ($difficulty -eq [DifficultyType]::easy) {
    $emptyCells = Get-EmptyCells $board
    $random = Get-Random -Minimum 0 -Maximum $emptyCells.Length

    return $emptyCells[$random] + 1
  }
  else {
    return Get-MinimaxMove -Board $board -Turn $turn -Difficulty $difficulty  
  }
}

function Get-MinimaxMove {
  param (
    [Parameter(Mandatory = $true)]
    [CellType[]]
    $board,
    [CellType]
    $turn,
    [DifficultyType]
    $difficulty
  )


  $emptyCells = Get-EmptyCells $board
  $maxScore = -2
  $move = -1
  $nextTurn = Get-NextTurn $turn

  # choose max depth based on difficulty
  $maxDepth = 9
  if ($difficulty -eq [DifficultyType]::medium) {
    $maxDepth = 4
  }

  # prevent computer from taking extremely long to choose first move
  if ($emptyCells.Length -ge 8) {  
    $maxDepth = 4
  }


  foreach ($emptyCell in $emptyCells) {
    $board[$emptyCell] = $turn
    $score = (Minimax -Board $board -Turn $nextTurn -Depth 1 -MaxDepth $maxDepth) * -1

    if ($score -gt $maxScore) {
      $maxScore = $score
      $move = $emptyCell
    }

    $board[$emptyCell] = [CellType]::empty
  }

  return $move + 1 # convert from 0-8 to 1-9
}

function Minimax {
  param (
    [Parameter(Mandatory = $true)]
    [CellType[]]
    $board,
    [Parameter(Mandatory = $true)]
    [CellType]
    $turn,
    [Parameter(Mandatory = $true)]
    [int]
    $depth,
    [Parameter(Mandatory = $true)]
    [int]
    $maxDepth
  )

  # Write-Host $depth

  $score = Get-Score $board $turn
  if ($null -ne $score) {
    return $score
  }
  elseif ($depth -eq $maxDepth) {
    return 0
  }

  $nextTurn = Get-NextTurn $turn
  $emptyCells = Get-EmptyCells $board

  # make move
  $scores = @()

  foreach ($emptyCell in $emptyCells) {
    $board[$emptyCell] = $turn
    $scores += (Minimax -Board $board -Turn $nextTurn -Depth ($depth + 1) -MaxDepth $maxDepth) * -1
    $board[$emptyCell] = [CellType]::empty
  }

  $maxScore = ($scores | Measure-Object -Maximum).Maximum

  return $maxScore
}

function Get-Score {
  param (
    [Parameter(Mandatory = $true)]
    [CellType[]]
    $board,
    [Parameter(Mandatory = $true)]
    [CellType]
    $turn
  )

  $state = Get-BoardState $board
  if ($state -eq [BoardState]::xWon ) {
    if ($turn -eq [CellType]::x) {
      return 1
    }
    else {
      return -1
    }
  }
  elseif ($state -eq [BoardState]::oWon) {
    if ($turn -eq [CellType]::o) {
      return 1
    }
    else {
      return -1
    }
  }
  elseif ($state -eq [BoardState]::draw) {
    return 0
  }
  else {
    return $null
  }
}

function Get-EmptyCells {
  param (
    [Parameter(Mandatory = $true)]
    [CellType[]]
    $board
  )

  $emptyCells = @()
  for ($i = 0; $i -lt $board.Length; $i++) {
    if ($board[$i] -eq [CellType]::empty) {
      $emptyCells += $i
    }
  }
  
  return $emptyCells
}

# Multiplayer functions
$serverPort = 8080

function New-Server {
  $server = New-Object System.Net.Sockets.TcpListener -ArgumentList $serverPort

  if ($null -eq $server) {
    Write-Error "Unable to create server"
    exit
  }
  
  try {
    $server.Start()
    Write-Banner "Server started"

    return $server
  }
  catch {
    Write-Error "Unable to start server, make sure nothing is listening on port $serverPort"
    exit
  }


}

function New-Client {
  param (
    [Parameter(Mandatory = $true)]
    [string]
    $server
  )

  $client = New-Object System.Net.Sockets.TcpClient -ArgumentList  $server, $serverPort
  return $client
}

function Wait-ForClientConnection {
  param (
    [Parameter(Mandatory = $true)]
    [System.Net.Sockets.TcpListener]
    $server
  )

  Clear-Host
  Write-Banner "Hostname: $(hostname)"
  Write-Banner "Get your opponent to enter the above hostname." -NoTop
  Write-Banner "Waiting for opponent to connect..." -NoTop

  $clientConnection = $server.AcceptTcpClient()
  if ($clientConnection -eq $null) {
    Write-Error "Client connection failed."
    exit 1
  }
  else {
    Write-Banner "Opponent connected." -NoTop
    Start-Sleep 1
  }

  return $clientConnection
}

function Send-Message {
  param (
    [Parameter(Mandatory = $true)]
    [System.Net.Sockets.NetworkStream]
    $stream,
    [Parameter(Mandatory = $true)]
    [string]
    $message
  )

  $data = [System.Text.Encoding]::ASCII.GetBytes($message)
  $stream.Write($data, 0, $data.Length)
}

function Receive-Message {
  param (
    [Parameter(Mandatory = $true)]
    [System.Net.Sockets.NetworkStream]
    $stream
  )

  $buffer = New-Object byte[] 1024

  while ($true) {
    $bytesRead = $stream.Read($buffer, 0, $buffer.Length)

    if ($bytesRead -eq 0) {
      break
    }
    else {
      $message = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
      break
    }
  }

  return $message
}


Start-Game