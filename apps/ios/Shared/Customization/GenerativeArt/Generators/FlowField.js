// Flow Field Generator
// Perlin noise-based flow field with 2000 particles creating organic curves
(function() {
    var W = __WIDTH__;
    var H = __HEIGHT__;
    var seed = __SEED__;

    // Simple seeded noise function
    function noise(x, y, s) {
        var n = Math.sin(x * 12.9898 + y * 78.233 + s * 45.164) * 43758.5453;
        return n - Math.floor(n);
    }

    function smoothNoise(x, y, s) {
        var ix = Math.floor(x), iy = Math.floor(y);
        var fx = x - ix, fy = y - iy;
        var ux = fx * fx * (3 - 2 * fx);
        var uy = fy * fy * (3 - 2 * fy);
        var a = noise(ix, iy, s);
        var b = noise(ix + 1, iy, s);
        var c = noise(ix, iy + 1, s);
        var d = noise(ix + 1, iy + 1, s);
        return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy;
    }

    // Clear background with dark color
    __ctx__.setFillColor(0.02, 0.02, 0.05, 1);
    __ctx__.fillRect(0, 0, W, H);

    // Flow field parameters
    var cols = 40, rows = 40;
    var cellW = W / cols, cellH = H / rows;
    var particles = [];
    var numParticles = 2000;
    var steps = 80;

    // Initialize particles
    for (var i = 0; i < numParticles; i++) {
        particles.push({
            x: Math.random() * W,
            y: Math.random() * H,
            vx: 0,
            vy: 0
        });
    }

    // Color palette based on seed
    var hueBase = (seed % 360) / 360;
    var colors = [
        [0.4 + 0.3 * Math.random(), 0.2 + 0.2 * Math.random(), 0.8 + 0.2 * Math.random(), 0.03],
        [0.2 + 0.2 * Math.random(), 0.5 + 0.3 * Math.random(), 0.9 + 0.1 * Math.random(), 0.02],
        [0.6 + 0.2 * Math.random(), 0.1 + 0.1 * Math.random(), 0.7 + 0.3 * Math.random(), 0.025]
    ];

    // Render flow field
    for (var step = 0; step < steps; step++) {
        __ctx__.beginPath();

        for (var i = 0; i < particles.length; i++) {
            var p = particles[i];
            var angle = smoothNoise(p.x * 0.008, p.y * 0.008, seed * 0.001) * Math.PI * 4;

            var nx = p.x + Math.cos(angle) * 2.5;
            var ny = p.y + Math.sin(angle) * 2.5;

            // Wrap around edges
            if (nx < 0) nx += W;
            if (nx >= W) nx -= W;
            if (ny < 0) ny += H;
            if (ny >= H) ny -= H;

            __ctx__.moveToPoint(p.x, p.y);
            __ctx__.addLineToPoint(nx, ny);

            p.x = nx;
            p.y = ny;
        }

        var color = colors[step % colors.length];
        __ctx__.setStrokeColor(color[0], color[1], color[2], color[3]);
        __ctx__.setLineWidth(0.5);
        __ctx__.strokePath();
    }

    // Add subtle glow dots at particle endpoints
    for (var i = 0; i < 200; i++) {
        var p = particles[Math.floor(Math.random() * particles.length)];
        var size = 1 + Math.random() * 2;
        __ctx__.setFillColor(0.6, 0.8, 1.0, 0.3 + Math.random() * 0.3);
        __ctx__.fillCircle(p.x, p.y, size);
    }
})();
