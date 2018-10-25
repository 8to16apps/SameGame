extends ColorRect

var gameOptions = {
	gameWidth = 800,		# game width, in pixels
	gameHeight = 800,	# game height, in pixels
	tileSize = 64,		# tile size, in pixels
	fieldSize = {		# field size, an object
		rows = 8,		# rows in the field, in units
		cols = 8			# columns in the field, in units
	},
	colors = ["#ff0000", "#00ff00", "#0000ff", "#ffff00"] # tile colors
}

var canPick = true;
var tilesArray = [];
var tilePool = [];
var filled = [];
var tweenCounter = 0;

onready var tile = preload("res://Tile.tscn");
onready var tween = $Tween;
onready var mover = $Mover;

func _ready():
	createLevel();
	pass

func _gui_input(event): # picktile
	# can the player pick a tile?
	if canPick && (event.button_mask & BUTTON_MASK_LEFT):
		# determining x and y position of the input inside tileGroup
		var posX = event.position.x;
		var posY = event.position.y;

		# transforming coordinates into actual rows and columns
		var pickedRow = floor(posY / gameOptions.tileSize);
		var pickedCol = floor(posX / gameOptions.tileSize);

		# checking if row and column are inside the actual game field
		if (pickedRow >= 0 && pickedCol >= 0 && pickedRow < gameOptions.fieldSize.rows && pickedCol < gameOptions.fieldSize.cols):
			# this is the tile we picked
			var pickedTile = tilesArray[pickedRow][pickedCol];

			# clean array
			filled.clear();

			# performing a flood fill on the selected tile
			# this will populate "filled" array
			floodFill(pickedTile.coordinate, pickedTile.value);

			# do we have more than one tile in the array?
			if ( filled.size() > 1):
				# ok, this is a valid move and player won't be able to pick another tile until all animations have been played
				canPick = false;

				# function to destroy selected tiles
				destroyTiles();

func createLevel():
	# canPick tells if we can pick a tile, we start with "true" has at the moment a tile can be picked
	canPick = true;

	# tiles are saved in an array called tilesArray
	tilesArray = [];

	# two loops to create a grid made by "gameOptions.fieldSize.rows" x "gameOptions.fieldSize.cols" columns
	for i in range(gameOptions.fieldSize.rows):
		tilesArray.append([]);
		for j in range(gameOptions.fieldSize.cols):
			# this function adds a tile at row "i" and column "j"
			addTile(i, j);

	# tilePool is the array which will contain removed tiles to be recycled
	tilePool = [];

func addTile(row,col):
	var newTile = tile.instance();
	add_child(newTile);

	var tileValue = randi() % gameOptions.colors.size();

	newTile.rect_position = Vector2( col*64, row*64 );
	newTile.color = Color( gameOptions.colors[tileValue] );

	var tileData = {
		tileSprite = newTile, # tile image
		isEmpty = false, # is it an empty tile? not at the moment
		coordinate = Vector2(col, row), # storing tile coordinate, useful during flood fill
		value = tileValue # the value (color) of the tile
	};

	tilesArray[row].append(tileData);

func floodFill( p, n ):
	if (p.x < 0 || p.y < 0 || p.x >= gameOptions.fieldSize.cols || p.y >= gameOptions.fieldSize.rows):
		return;

	if (!tilesArray[p.y][p.x].isEmpty && tilesArray[p.y][p.x].value == n && !pointInArray(p)):
		filled.push_back(p);
		floodFill(Vector2(p.x + 1, p.y), n);
		floodFill(Vector2(p.x - 1, p.y), n);
		floodFill(Vector2(p.x, p.y + 1), n);
		floodFill(Vector2(p.x, p.y - 1), n);

func pointInArray(p):
	for i in range( filled.size() ):
		if ( filled[i].x == p.x && filled[i].y == p.y):
			return true;
	return false;

func destroyTiles():
	# looping through the array
	for i in range(filled.size()):
		# fading tile out with a tween
		tween.interpolate_property(tilesArray[filled[i].y][filled[i].x].tileSprite,
			"modulate",
			Color(1, 1, 1, 1),
			Color(1, 1, 1, 0),
			0.3,
			Tween.TRANS_LINEAR,
			Tween.EASE_IN);

		# placing the sprite in the array of sprites to be recycled
		tilePool.push_back(tilesArray[filled[i].y][filled[i].x].tileSprite);

		# now the tile is empty
		tilesArray[filled[i].y][filled[i].x].isEmpty = true;

		tweenCounter += 1;
	tween.start();

func _on_Tween_tween_completed( object, key ):
	tweenCounter -= 1;
	# we don't know how many tiles we have already removed, so counting the tweens
	# currently in use is a good way, at the moment
	# if this was the last tween (we only have one tween running, this one)
	if tweenCounter == 0:
		tween.stop_all();
		# call fillVerticalHoles function to make tiles fall down
		fillVerticalHoles();

func fillVerticalHoles():
	# filled is a variable which tells us if we filled a hole
	var isFilled = false;

	# looping through the entire gamefield
	for i in range(gameOptions.fieldSize.rows - 2, -1, -1):
		for j in range(gameOptions.fieldSize.cols):
			# if we have a tile...
			if (!tilesArray[i][j].isEmpty):
				# let's count how many holes we can find below this tile
				var holesBelow = countSpacesBelow(i, j);

				# if holesBelow is greater than zero...
				if holesBelow > 0:
					# we filled a hole, or at least we are about to do it
					isFilled = true;

					# function to move down a tile at column "j" from "i" to "i + holesBelow" row
					moveDownTile(i, j, i + holesBelow, false);

	# if we looped trough all tiles but did not fill anything...
	if (!isFilled):
		# let's see if there are horizontal holes to fill
		canPick = true;

	# now it's time to reuse tiles saved in the pool (tilePool array),
	# let's start with a loop through each column
	for i in range(gameOptions.fieldSize.cols):
		# counting how many empty spaces we have in each column
		var topHoles = countSpacesBelow(-1, i);

		# then for each empty space...
		for j in range(topHoles - 1, -1, -1):
			# get the tile to be reused from the pool
			var reusedTile = tilePool.pop_front();

			# y position is above the field, to make tile "fall down"
			reusedTile.rect_position.y =  (j - topHoles) * gameOptions.tileSize;

			# x position is just the column
			reusedTile.rect_position.x = i * gameOptions.tileSize;

			# setting alpha back to 1
			reusedTile.modulate = Color(1,1,1,1);

			# setting a new tile value
			var tileValue = randi() % gameOptions.colors.size();

			# tinting the tile with the new color
			reusedTile.color = Color(gameOptions.colors[tileValue]);

			# setting the item with the new values
			tilesArray[j][i] = {
				tileSprite = reusedTile,
				isEmpty = false,
				coordinate = Vector2(i, j),
				value = tileValue
			}

			# and finally make the tile fall down
			moveDownTile(0, i, j, true);
	mover.start();

# function to count how many empty tiles we have under a given tile
func countSpacesBelow(row, col):
	var result = 0;
	for i in range(row + 1, gameOptions.fieldSize.rows):
		if (tilesArray[i][col].isEmpty):
			result += 1;
	return result;

# function to move down a tile
func moveDownTile(fromRow, fromCol, toRow, justMove):
	# a tile can be just moved (when it's a "new" tile falling from above) or
	# must be moved updating the game field (when it's an "old" tile falling down from its previous position)
	# "justMove" flag handles this operation
	if (!justMove):
		# saving the tile itself and its value in temporary variables
		var tileToMove = tilesArray[fromRow][fromCol].tileSprite;
		var tileValue = tilesArray[fromRow][fromCol].value;
		
		# adjusting tilesArray items actually creating the tile in the new position...
		tilesArray[toRow][fromCol] = {
			tileSprite = tileToMove,
			isEmpty = false,
			coordinate = Vector2(fromCol, toRow),
			value = tileValue
		}
		
		# the old place now is set to null
		tilesArray[fromRow][fromCol].isEmpty = true;
	
	# distance to travel, in pixels, by the tile
	var distanceToTravel = (toRow * gameOptions.tileSize) - tilesArray[toRow][fromCol].tileSprite.rect_position.y
	
	# a tween manages the movement
	mover.interpolate_property( tilesArray[toRow][fromCol].tileSprite,
		"rect_position",
		tilesArray[toRow][fromCol].tileSprite.rect_position,
		Vector2( tilesArray[toRow][fromCol].tileSprite.rect_position.x,  toRow * gameOptions.tileSize),
		distanceToTravel / 2000,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN);
	
	tweenCounter += 1;

# function which counts tiles in a column
func tilesInColumn(col):
	var result = 0;
	for i in range(gameOptions.fieldSize.rows):
		if (!tilesArray[i][col].isEmpty):
			result += 1;
	return result;


func _on_Mover_tween_completed( object, key ):
	tweenCounter -= 1;
	if tweenCounter == 0:
		mover.stop_all();
		canPick = true;
