// Cellular Automata Generator
// Wolfram-style 2D cellular automata with emergent complexity
(function() {
    var W = __WIDTH__;
    var H = __HEIGHT__;
    var seed = __SEED__;

    var cellSize = 4;
    var cols = Math.floor(W / cellSize);
    var rows = Math.floor(H / cellSize);

    // Initialize grid with random seed
    var grid = [];
    for (var y = 0; y < rows; y++) {
        grid[y] = [];
        for (var x = 0; x < cols; x++) {
            grid[y][x] = Math.random() > 0.7 ? 1 : 0;
        }
    }

    // Color palette - neon cyberpunk
    var aliveColors = [
        [0.0, 0.9, 0.9, 0.8],   // Cyan
        [0.9, 0.2, 0.6, 0.7],   // Magenta
        [0.4, 0.3, 0.9, 0.6],   // Purple
        [0.2, 0.8, 0.5, 0.5],   // Green
    ];

    // Clear background
    __ctx__.setFillColor(0.02, 0.02, 0.03, 1);
    __ctx__.fillRect(0, 0, W, H);

    // Evolution rules (simplified Game of Life variant)
    function countNeighbors(g, x, y) {
        var count = 0;
        for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
                if (dx === 0 && dy === 0) continue;
                var nx = (x + dx + cols) % cols;
                var ny = (y + dy + rows) % rows;
                count += g[ny][nx];
            }
        }
        return count;
    }

    // Render initial state
    for (var y = 0; y < rows; y++) {
        for (var x = 0; x < cols; x++) {
            if (grid[y][x] === 1) {
                var color = aliveColors[Math.floor(Math.random() * aliveColors.length)];
                __ctx__.setFillColor(color[0], color[1], color[2], color[3]);
                __ctx__.fillRect(x * cellSize, y * cellSize, cellSize, cellSize);
            }
        }
    }

    // Evolve and render
    var generations = 50;
    for (var gen = 0; gen < generations; gen++) {
        var newGrid = [];
        for (var y = 0; y < rows; y++) {
            newGrid[y] = [];
            for (var x = 0; x < cols; x++) {
                var neighbors = countNeighbors(grid, x, y);
                var alive = grid[y][x];

                // Rules: birth on 3, survive on 2-3, else die
                if (alive && (neighbors === 2 || neighbors === 3)) {
                    newGrid[y][x] = 1;
                } else if (!alive && neighbors === 3) {
                    newGrid[y][x] = 1;
                } else {
                    newGrid[y][x] = 0;
                }
            }
        }

        // Render new cells
        for (var y = 0; y < rows; y++) {
            for (var x = 0; x < cols; x++) {
                if (newGrid[y][x] === 1 && grid[y][x] === 0) {
                    // Newly born cell - bright color
                    var color = aliveColors[gen % aliveColors.length];
                    __ctx__.setFillColor(color[0], color[1], color[2], color[3]);
                    __ctx__.fillRect(x * cellSize, y * cellSize, cellSize, cellSize);
                } else if (newGrid[y][x] === 0 && grid[y][x] === 1) {
                    // Dying cell - fade out
                    __ctx__.setFillColor(0.1, 0.1, 0.15, 0.3);
                    __ctx__.fillRect(x * cellSize, y * cellSize, cellSize, cellSize);
                }
            }
        }

        grid = newGrid;
    }

    // Add subtle grid overlay
    __ctx__.setStrokeColor(0.1, 0.1, 0.15, 0.2);
    __ctx__.setLineWidth(0.5);
    for (var x = 0; x <= W; x += cellSize * 4) {
        __ctx__.beginPath();
        __ctx__.moveToPoint(x, 0);
        __ctx__.addLineToPoint(x, H);
        __ctx__.strokePath();
    }
    for (var y = 0; y <= H; y += cellSize * 4) {
        __ctx__.beginPath();
        __ctx__.moveToPoint(0, y);
        __ctx__.addLineToPoint(W, y);
        __ctx__.strokePath();
    }
})();
