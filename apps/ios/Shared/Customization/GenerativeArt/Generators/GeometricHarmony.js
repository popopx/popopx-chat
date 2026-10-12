// Geometric Harmony Generator
// Golden ratio spirals and sacred geometry patterns
(function() {
    var W = __WIDTH__;
    var H = __HEIGHT__;
    var seed = __SEED__;

    // Clear background with deep space color
    __ctx__.setFillColor(0.02, 0.01, 0.04, 1);
    __ctx__.fillRect(0, 0, W, H);

    var cx = W / 2;
    var cy = H / 2;
    var phi = 1.618033988749895; // Golden ratio

    // Color palette - warm gold/purple
    var baseHue = (seed % 60) / 360;
    var colors = [
        [0.9 + 0.1 * Math.random(), 0.7 + 0.2 * Math.random(), 0.3 + 0.2 * Math.random(), 0.4],
        [0.6 + 0.2 * Math.random(), 0.3 + 0.2 * Math.random(), 0.8 + 0.2 * Math.random(), 0.3],
        [0.8 + 0.2 * Math.random(), 0.5 + 0.3 * Math.random(), 0.6 + 0.2 * Math.random(), 0.25]
    ];

    // Draw golden spiral
    var maxRadius = Math.min(W, H) * 0.45;
    var numSpirals = 3 + Math.floor(Math.random() * 3);

    for (var s = 0; s < numSpirals; s++) {
        __ctx__.beginPath();
        var startAngle = (s / numSpirals) * Math.PI * 2;
        var color = colors[s % colors.length];

        for (var angle = 0; angle < Math.PI * 8; angle += 0.05) {
            var radius = maxRadius * Math.pow(phi, -angle / (Math.PI * 2)) * Math.pow(phi, s * 0.3);
            var x = cx + Math.cos(angle + startAngle) * radius;
            var y = cy + Math.sin(angle + startAngle) * radius;

            if (angle === 0) {
                __ctx__.moveToPoint(x, y);
            } else {
                __ctx__.addLineToPoint(x, y);
            }
        }

        __ctx__.setStrokeColor(color[0], color[1], color[2], color[3]);
        __ctx__.setLineWidth(1.5);
        __ctx__.strokePath();
    }

    // Draw sacred geometry - flower of life pattern
    var numCircles = 6 + Math.floor(Math.random() * 3);
    var circleRadius = maxRadius * 0.15;

    for (var ring = 0; ring < 3; ring++) {
        var ringRadius = circleRadius * (ring + 1);
        var numInRing = ring === 0 ? 1 : 6 * ring;

        for (var i = 0; i < numInRing; i++) {
            var angle = (i / numInRing) * Math.PI * 2;
            var x = cx + Math.cos(angle) * ringRadius;
            var y = cy + Math.sin(angle) * ringRadius;

            __ctx__.beginPath();
            // Draw circle using line segments
            var segments = 60;
            for (var j = 0; j <= segments; j++) {
                var a = (j / segments) * Math.PI * 2;
                var px = x + Math.cos(a) * circleRadius;
                var py = y + Math.sin(a) * circleRadius;
                if (j === 0) {
                    __ctx__.moveToPoint(px, py);
                } else {
                    __ctx__.addLineToPoint(px, py);
                }
            }
            __ctx__.closePath();

            var color = colors[ring % colors.length];
            __ctx__.setStrokeColor(color[0], color[1], color[2], color[3] * 0.5);
            __ctx__.setLineWidth(1);
            __ctx__.strokePath();
        }
    }

    // Add central glow
    var gradientSteps = 20;
    for (var g = gradientSteps; g > 0; g--) {
        var radius = (g / gradientSteps) * circleRadius * 0.5;
        var alpha = 0.1 * (1 - g / gradientSteps);
        __ctx__.setFillColor(0.9, 0.7, 0.4, alpha);
        __ctx__.fillCircle(cx, cy, radius);
    }

    // Add outer ring decorations
    var numDots = 12 + Math.floor(Math.random() * 6);
    for (var d = 0; d < numDots; d++) {
        var angle = (d / numDots) * Math.PI * 2;
        var x = cx + Math.cos(angle) * maxRadius * 0.9;
        var y = cy + Math.sin(angle) * maxRadius * 0.9;
        var dotSize = 2 + Math.random() * 3;

        __ctx__.setFillColor(0.8, 0.6, 0.9, 0.6);
        __ctx__.fillCircle(x, y, dotSize);
    }
})();
