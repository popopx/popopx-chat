// Wave Interference Generator
// Superimposed sine waves creating moiré and interference patterns
(function() {
    var W = __WIDTH__;
    var H = __HEIGHT__;
    var seed = __SEED__;

    // Clear background
    __ctx__.setFillColor(0.01, 0.02, 0.04, 1);
    __ctx__.fillRect(0, 0, W, H);

    // Wave parameters
    var numWaves = 5 + Math.floor(Math.random() * 4);
    var waves = [];

    for (var w = 0; w < numWaves; w++) {
        waves.push({
            frequency: 0.01 + Math.random() * 0.03,
            amplitude: 20 + Math.random() * 60,
            phase: Math.random() * Math.PI * 2,
            speed: 0.5 + Math.random() * 1.5,
            color: [
                0.3 + Math.random() * 0.4,
                0.4 + Math.random() * 0.4,
                0.8 + Math.random() * 0.2,
                0.15 + Math.random() * 0.1
            ]
        });
    }

    // Render interference pattern pixel by pixel (coarse grid for performance)
    var resolution = 4; // Process every 4th pixel
    var cols = Math.ceil(W / resolution);
    var rows = Math.ceil(H / resolution);

    for (var y = 0; y < rows; y++) {
        for (var x = 0; x < cols; x++) {
            var px = x * resolution;
            var py = y * resolution;
            var totalAmplitude = 0;

            // Sum all wave contributions
            for (var w = 0; w < waves.length; w++) {
                var wave = waves[w];
                var dist = Math.sqrt(
                    Math.pow(px - W / 2, 2) + Math.pow(py - H / 2, 2)
                );
                var waveValue = Math.sin(dist * wave.frequency + wave.phase) * wave.amplitude;
                totalAmplitude += waveValue;
            }

            // Normalize and map to color
            var normalized = (totalAmplitude + numWaves * 60) / (numWaves * 120);
            normalized = Math.max(0, Math.min(1, normalized));

            // Color based on amplitude
            var r = 0.1 + normalized * 0.3;
            var g = 0.2 + normalized * 0.4;
            var b = 0.5 + normalized * 0.5;
            var a = 0.3 + normalized * 0.4;

            __ctx__.setFillColor(r, g, b, a);
            __ctx__.fillRect(px, py, resolution, resolution);
        }
    }

    // Add wave crest highlights
    for (var w = 0; w < waves.length; w++) {
        var wave = waves[w];
        __ctx__.beginPath();

        for (var x = 0; x < W; x += 2) {
            var dist = Math.sqrt(Math.pow(x - W / 2, 2) + Math.pow(H / 2 - H / 2, 2));
            var y = H / 2 + Math.sin(dist * wave.frequency + wave.phase) * wave.amplitude;

            if (x === 0) {
                __ctx__.moveToPoint(x, y);
            } else {
                __ctx__.addLineToPoint(x, y);
            }
        }

        __ctx__.setStrokeColor(wave.color[0], wave.color[1], wave.color[2], wave.color[3] * 2);
        __ctx__.setLineWidth(2);
        __ctx__.strokePath();
    }

    // Add central interference focal point glow
    var glowRadius = 80;
    for (var g = glowRadius; g > 0; g -= 5) {
        var alpha = 0.1 * (1 - g / glowRadius);
        __ctx__.setFillColor(0.5, 0.7, 1.0, alpha);
        __ctx__.fillCircle(W / 2, H / 2, g);
    }
})();
