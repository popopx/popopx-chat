// Circuit Board Generator
// Recursive right-angle paths with node dots, tech/geek aesthetic
(function() {
    var W = __WIDTH__;
    var H = __HEIGHT__;
    var seed = __SEED__;

    // Clear background
    __ctx__.setFillColor(0.03, 0.05, 0.08, 1);
    __ctx__.fillRect(0, 0, W, H);

    // Grid parameters
    var gridSize = 20;
    var cols = Math.floor(W / gridSize);
    var rows = Math.floor(H / gridSize);

    // Color palette - cyan/green tech colors
    var traceColor = [0.0, 0.8 + Math.random() * 0.2, 0.9 + Math.random() * 0.1, 0.6];
    var nodeColor = [0.2, 1.0, 0.8, 0.9];
    var viaColor = [0.0, 0.6, 0.7, 0.7];

    // Generate circuit traces
    var numTraces = 30 + Math.floor(Math.random() * 20);

    for (var t = 0; t < numTraces; t++) {
        var startX = Math.floor(Math.random() * cols) * gridSize;
        var startY = Math.floor(Math.random() * rows) * gridSize;
        var segments = 5 + Math.floor(Math.random() * 10);

        __ctx__.beginPath();
        __ctx__.moveToPoint(startX, startY);

        var x = startX, y = startY;
        var nodes = [{x: x, y: y}];

        for (var s = 0; s < segments; s++) {
            // Random direction (horizontal or vertical)
            var horizontal = Math.random() > 0.5;
            var length = (1 + Math.floor(Math.random() * 4)) * gridSize;

            if (horizontal) {
                x += (Math.random() > 0.5 ? 1 : -1) * length;
                x = Math.max(0, Math.min(W, x));
            } else {
                y += (Math.random() > 0.5 ? 1 : -1) * length;
                y = Math.max(0, Math.min(H, y));
            }

            __ctx__.addLineToPoint(x, y);
            nodes.push({x: x, y: y});
        }

        __ctx__.setStrokeColor(traceColor[0], traceColor[1], traceColor[2], traceColor[3]);
        __ctx__.setLineWidth(1.5);
        __ctx__.strokePath();

        // Add node dots at each junction
        for (var n = 0; n < nodes.length; n++) {
            var node = nodes[n];
            var radius = 2 + Math.random() * 2;
            __ctx__.setFillColor(nodeColor[0], nodeColor[1], nodeColor[2], nodeColor[3]);
            __ctx__.fillCircle(node.x, node.y, radius);
        }
    }

    // Add vias (connection points)
    var numVias = 50 + Math.floor(Math.random() * 30);
    for (var v = 0; v < numVias; v++) {
        var vx = Math.floor(Math.random() * cols) * gridSize;
        var vy = Math.floor(Math.random() * rows) * gridSize;
        var vRadius = 3 + Math.random() * 3;

        __ctx__.setFillColor(viaColor[0], viaColor[1], viaColor[2], viaColor[3]);
        __ctx__.fillCircle(vx, vy, vRadius);

        // Inner hole
        __ctx__.setFillColor(0.03, 0.05, 0.08, 1);
        __ctx__.fillCircle(vx, vy, vRadius * 0.4);
    }

    // Add subtle grid lines
    __ctx__.setStrokeColor(0.1, 0.3, 0.4, 0.1);
    __ctx__.setLineWidth(0.5);
    for (var gx = 0; gx <= W; gx += gridSize * 2) {
        __ctx__.beginPath();
        __ctx__.moveToPoint(gx, 0);
        __ctx__.addLineToPoint(gx, H);
        __ctx__.strokePath();
    }
    for (var gy = 0; gy <= H; gy += gridSize * 2) {
        __ctx__.beginPath();
        __ctx__.moveToPoint(0, gy);
        __ctx__.addLineToPoint(W, gy);
        __ctx__.strokePath();
    }
})();
