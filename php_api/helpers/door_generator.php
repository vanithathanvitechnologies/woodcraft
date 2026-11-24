<?php
require_once __DIR__ . '/constants.php';

function hexToRgbPhp(string $hex): array {
    $clean = ltrim($hex, '#');
    $num = hexdec($clean);
    return [($num >> 16) & 255, ($num >> 8) & 255, $num & 255];
}

function clampByte($v): int {
    return max(0, min(255, (int)round($v)));
}

function smoothstep(float $edge0, float $edge1, float $x): float {
    if ($edge1 <= $edge0) return $x >= $edge1 ? 1.0 : 0.0;
    $t = max(0.0, min(1.0, ($x - $edge0) / ($edge1 - $edge0)));
    return $t * $t * (3.0 - 2.0 * $t);
}

/**
 * Loads a PNG/JPG/WEBP image into a GD GdImage/resource normalized to $w x $h.
 */
function loadNormalizedDoorImage(string $absPath, int $w = 600, int $h = 800) {
    if (!is_file($absPath) || !function_exists('imagecreatefromstring')) {
        return null;
    }
    $bytes = @file_get_contents($absPath);
    if (!$bytes) return null;
    $src = @imagecreatefromstring($bytes);
    if (!$src) return null;

    $sw = imagesx($src);
    $sh = imagesy($src);
    if ($sw <= 0 || $sh <= 0) {
        imagedestroy($src);
        return null;
    }

    // Cover-crop into target aspect ratio so proportions are never distorted
    $targetAspect = $w / (float)$h;
    $srcAspect = $sw / (float)$sh;
    $cropX = 0;
    $cropY = 0;
    $cropW = $sw;
    $cropH = $sh;

    if ($srcAspect > $targetAspect) {
        $cropW = (int)round($sh * $targetAspect);
        $cropX = (int)floor(($sw - $cropW) / 2);
    } elseif ($srcAspect < $targetAspect) {
        $cropH = (int)round($sw / $targetAspect);
        $cropY = (int)floor(($sh - $cropH) / 2);
    }

    $dst = imagecreatetruecolor($w, $h);
    imagealphablending($dst, true);
    imagecopyresampled($dst, $src, 0, 0, $cropX, $cropY, $w, $h, $cropW, $cropH);
    imagedestroy($src);
    return $dst;
}

/**
 * Samples the wall background RGB from the top-left and top-right corners.
 */
function sampleCornerWallColor($im): array {
    $w = imagesx($im);
    $pts = [
        [6, 6], [16, 6], [6, 18], [16, 18],
        [$w - 7, 6], [$w - 17, 6], [$w - 7, 18], [$w - 17, 18],
    ];
    $sr = 0.0; $sg = 0.0; $sb = 0.0;
    foreach ($pts as [$x, $y]) {
        $rgb = imagecolorat($im, $x, $y);
        $sr += ($rgb >> 16) & 255;
        $sg += ($rgb >> 8) & 255;
        $sb += $rgb & 255;
    }
    $n = count($pts);
    return [$sr / $n, $sg / $n, $sb / $n];
}

/**
 * Computes color distance between a pixel and a reference wall color.
 */
function colorDist(int $r, int $g, int $b, array $ref): float {
    $dr = $r - $ref[0];
    $dg = $g - $ref[1];
    $db = $b - $ref[2];
    return sqrt($dr * $dr + $dg * $dg + $db * $db);
}

/**
 * Checks whether a pixel is warm wood vs neutral wall (used for bounding-box detection & sampling).
 */
function isWoodPixel(int $r, int $g, int $b, ?array $wallRef = null): bool {
    if ($wallRef !== null && colorDist($r, $g, $b, $wallRef) < 42.0) {
        return false;
    }
    $max = max($r, $g, $b);
    $min = min($r, $g, $b);
    $sat = $max - $min;
    $lum = 0.299 * $r + 0.587 * $g + 0.114 * $b;

    if ($lum > 185 && $sat < 42) return false;
    if ($g > $r + 6 && $sat > 12) return false;
    return ($r >= $b - 4) && ($lum < 215);
}

/**
 * Detects the bounding box of the wooden door/frame inside a 600x800 photo.
 * Uses the mid-section (y: 30%..80%) to measure the vertical pillar edges accurately
 * (ignoring flared top cornices!) and computes clean outer, dest-opening, and source-leaf rects.
 */
function detectDoorBounds($im): array {
    $w = imagesx($im);
    $h = imagesy($im);
    $wallRef = sampleCornerWallColor($im);

    // 1) Measure outer top/bottom across full height
    $rowScore = array_fill(0, $h, 0);
    for ($y = 0; $y < $h; $y += 4) {
        for ($x = 0; $x < $w; $x += 4) {
            $rgb = imagecolorat($im, $x, $y);
            if (isWoodPixel(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $wallRef)) {
                $rowScore[$y]++;
            }
        }
    }
    $rowThresh = (int)round(($w / 4) * 0.20);
    $top = 0;
    for ($y = 0; $y < $h; $y += 4) {
        if ($rowScore[$y] >= $rowThresh) { $top = $y; break; }
    }
    $bottom = $h - 1;
    for ($y = $h - 4; $y >= 0; $y -= 4) {
        if ($rowScore[$y] >= $rowThresh) { $bottom = $y; break; }
    }

    // 2) Measure left/right pillar edges in the middle 50% (y: 28%..78%) so top cornice overhang doesn't widen pillar bounds
    $midY0 = (int)round($h * 0.28);
    $midY1 = (int)round($h * 0.78);
    $midRows = max(1, (int)(($midY1 - $midY0) / 4));
    $colScore = array_fill(0, $w, 0);
    for ($y = $midY0; $y < $midY1; $y += 4) {
        for ($x = 0; $x < $w; $x += 4) {
            $rgb = imagecolorat($im, $x, $y);
            if (isWoodPixel(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $wallRef)) {
                $colScore[$x]++;
            }
        }
    }
    $colThresh = (int)round($midRows * 0.45);
    // Pick the WIDEST contiguous horizontal span of wood columns so side lamps/wall objects are ignored
    $bestLeft = 0; $bestRight = $w - 1; $bestWidth = 0;
    $inRun = false; $runStart = 0; $gapCount = 0;
    for ($x = 0; $x < $w; $x += 4) {
        if ($colScore[$x] >= $colThresh) {
            if (!$inRun) { $inRun = true; $runStart = $x; }
            $gapCount = 0;
        } else {
            if ($inRun) {
                $gapCount++;
                if ($gapCount >= 3) { // >= 12px gap ends the run
                    $runEnd = $x - ($gapCount * 4);
                    if (($runEnd - $runStart) > $bestWidth) {
                        $bestWidth = $runEnd - $runStart;
                        $bestLeft = $runStart;
                        $bestRight = $runEnd;
                    }
                    $inRun = false;
                }
            }
        }
    }
    if ($inRun) {
        $runEnd = $w - 1 - ($gapCount * 4);
        if (($runEnd - $runStart) > $bestWidth) {
            $bestWidth = $runEnd - $runStart;
            $bestLeft = $runStart;
            $bestRight = $runEnd;
        }
    }
    $left = $bestLeft;
    $right = $bestRight;

    // Sanity clamp for close-up / edge-to-edge photos
    if ($right - $left < (int)($w * 0.45)) {
        $left = (int)round($w * 0.12);
        $right = (int)round($w * 0.88);
    }
    if ($bottom - $top < (int)($h * 0.50)) {
        $top = (int)round($h * 0.04);
        $bottom = (int)round($h * 0.96);
    }

    $dw = $right - $left;
    $dh = $bottom - $top;

    // Destination opening sits snugly inside the frame pillars and above the threshold
    $dstInner = [
        'x' => $left + (int)round($dw * 0.165),
        'y' => $top + (int)round($dh * 0.235),
        'w' => max(80, (int)round($dw * 0.67)),
        'h' => max(120, (int)round($dh * 0.69)),
    ];

    // Source door-leaf cutout is slightly tighter horizontally/vertically so side pillars & threshold never bleed in
    $srcLeaves = [
        'x' => $left + (int)round($dw * 0.195),
        'y' => $top + (int)round($dh * 0.245),
        'w' => max(80, (int)round($dw * 0.61)),
        'h' => max(120, (int)round($dh * 0.655)),
    ];

    return [
        'wall' => $wallRef,
        'outer' => ['x' => $left, 'y' => $top, 'w' => $dw, 'h' => $dh],
        'inner' => $dstInner,
        'leaves' => $srcLeaves,
    ];
}

/**
 * Computes average RGB of wood pixels inside a rectangular region.
 */
function sampleAverageWoodColor($im, int $x0, int $y0, int $rw, int $rh, ?array $wallRef = null): array {
    $w = imagesx($im);
    $h = imagesy($im);
    $sumR = 0.0; $sumG = 0.0; $sumB = 0.0; $cnt = 0;

    $x1 = min($w - 1, $x0 + $rw);
    $y1 = min($h - 1, $y0 + $rh);
    for ($y = max(0, $y0); $y < $y1; $y += 4) {
        for ($x = max(0, $x0); $x < $x1; $x += 4) {
            $rgb = imagecolorat($im, $x, $y);
            $r = ($rgb >> 16) & 255;
            $g = ($rgb >> 8) & 255;
            $b = $rgb & 255;
            if (isWoodPixel($r, $g, $b, $wallRef)) {
                $sumR += $r; $sumG += $g; $sumB += $b; $cnt++;
            }
        }
    }
    if ($cnt < 20) return [138.0, 90.0, 48.0];
    return [$sumR / $cnt, $sumG / $cnt, $sumB / $cnt];
}

/**
 * Composites a cropped region from $srcImg into $dstImg at $dstRect
 * with smooth wood-color matching, feathered seams, optional recessed shadow,
 * and smooth corner-wall alpha cutout (for arches/crowns).
 */
function compositeRegionMatched(
    $dstImg,
    $srcImg,
    array $srcRect,
    array $dstRect,
    array $targetWoodRgb,
    int $feather = 14,
    bool $addRecessShadow = true,
    bool $isCrownOverlay = false,
    ?array $srcWallRef = null,
    ?array $dstWallRef = null
): void {
    $dw = max(1, (int)$dstRect['w']);
    $dh = max(1, (int)$dstRect['h']);
    $dx = (int)$dstRect['x'];
    $dy = (int)$dstRect['y'];

    $patch = imagecreatetruecolor($dw, $dh);
    imagecopyresampled(
        $patch,
        $srcImg,
        0, 0,
        (int)$srcRect['x'], (int)$srcRect['y'],
        $dw, $dh,
        max(1, (int)$srcRect['w']), max(1, (int)$srcRect['h'])
    );

    $srcWood = sampleAverageWoodColor($patch, 0, 0, $dw, $dh, $srcWallRef);
    $gainR = max(0.70, min(1.38, $targetWoodRgb[0] / max(20.0, $srcWood[0])));
    $gainG = max(0.70, min(1.38, $targetWoodRgb[1] / max(20.0, $srcWood[1])));
    $gainB = max(0.68, min(1.35, $targetWoodRgb[2] / max(20.0, $srcWood[2])));

    // Smooth blend toward target wood tone so source carving texture looks carved from the same timber
    $mix = 0.78;
    $gR = 1.0 + ($gainR - 1.0) * $mix;
    $gG = 1.0 + ($gainG - 1.0) * $mix;
    $gB = 1.0 + ($gainB - 1.0) * $mix;

    $canvasW = imagesx($dstImg);
    $canvasH = imagesy($dstImg);

    for ($py = 0; $py < $dh; $py++) {
        $cy = $dy + $py;
        if ($cy < 0 || $cy >= $canvasH) continue;

        $alphaY = 1.0;
        if ($isCrownOverlay) {
            if ($py > $dh - $feather) {
                $alphaY = smoothstep(0.0, (float)$feather, (float)($dh - $py));
            }
        } else {
            if ($py < $feather) $alphaY = min($alphaY, smoothstep(0.0, (float)$feather, (float)$py));
            if ($py > $dh - $feather) $alphaY = min($alphaY, smoothstep(0.0, (float)$feather, (float)($dh - $py)));
        }

        // Sample clean local wall color at same row on base canvas so old cornice corners erase cleanly behind curved arches
        $rowWallRgb = $dstWallRef;
        if ($isCrownOverlay && $dstWallRef !== null) {
            $sampleX = max(4, min($canvasW - 5, $dx - 14));
            $wRgb = imagecolorat($dstImg, $sampleX, $cy);
            $wr = ($wRgb >> 16) & 255;
            $wg = ($wRgb >> 8) & 255;
            $wb = $wRgb & 255;
            if (colorDist($wr, $wg, $wb, $dstWallRef) < 55.0) {
                $rowWallRgb = [(float)$wr, (float)$wg, (float)$wb];
            }
        }

        for ($px = 0; $px < $dw; $px++) {
            $cx = $dx + $px;
            if ($cx < 0 || $cx >= $canvasW) continue;

            $sRgb = imagecolorat($patch, $px, $py);
            $sr = ($sRgb >> 16) & 255;
            $sg = ($sRgb >> 8) & 255;
            $sb = $sRgb & 255;

            $alphaX = 1.0;
            if (!$isCrownOverlay) {
                if ($px < $feather) $alphaX = min($alphaX, smoothstep(0.0, (float)$feather, (float)$px));
                if ($px > $dw - $feather) $alphaX = min($alphaX, smoothstep(0.0, (float)$feather, (float)($dw - $px)));
            } else {
                if ($px < 10) $alphaX = min($alphaX, smoothstep(0.0, 10.0, (float)$px));
                if ($px > $dw - 10) $alphaX = min($alphaX, smoothstep(0.0, 10.0, (float)($dw - $px)));
            }

            if ($isCrownOverlay && $srcWallRef !== null && $rowWallRgb !== null) {
                // Smoothly replace the entire crown band: wood pixels get color-matched crown,
                // wall pixels around curved arch get cleanly filled with base wall color (erasing old cornice!)
                $dist = colorDist($sr, $sg, $sb, $srcWallRef);
                $woodAmt = smoothstep(38.0, 74.0, $dist);

                // Sample clean wall right at top edge (y=10) at same X for smooth horizontal light matching
                $topRgb = imagecolorat($dstImg, $cx, 10);
                $trw = ($topRgb >> 16) & 255; $tgw = ($topRgb >> 8) & 255; $tbw = $topRgb & 255;
                $localWall = (colorDist($trw, $tgw, $tbw, $dstWallRef) < 55.0)
                    ? [(float)$trw, (float)$tgw, (float)$tbw]
                    : $rowWallRgb;

                $nr = clampByte($sr * $gR) * $woodAmt + $localWall[0] * (1.0 - $woodAmt);
                $ng = clampByte($sg * $gG) * $woodAmt + $localWall[1] * (1.0 - $woodAmt);
                $nb = clampByte($sb * $gB) * $woodAmt + $localWall[2] * (1.0 - $woodAmt);

                $alpha = max(0.0, min(1.0, $alphaX * $alphaY));
                if ($alpha <= 0.002) continue;

                $dRgb = imagecolorat($dstImg, $cx, $cy);
                $dr = ($dRgb >> 16) & 255;
                $dg = ($dRgb >> 8) & 255;
                $db = $dRgb & 255;
                $or = clampByte($dr * (1.0 - $alpha) + $nr * $alpha);
                $og = clampByte($dg * (1.0 - $alpha) + $ng * $alpha);
                $ob = clampByte($db * (1.0 - $alpha) + $nb * $alpha);
                imagesetpixel($dstImg, $cx, $cy, ($or << 16) | ($og << 8) | $ob);
                continue;
            }

            $alpha = max(0.0, min(1.0, $alphaX * $alphaY));
            if ($alpha <= 0.002) continue;

            // Smoothly color-match all pixels inside the wooden patch (zero hard-cutoff speckles!)
            $nr = clampByte($sr * $gR);
            $ng = clampByte($sg * $gG);
            $nb = clampByte($sb * $gB);

            // Realistic recessed door-frame shadow along top, left & right edges
            if ($addRecessShadow) {
                $shadow = 1.0;
                if ($py < 12) $shadow = min($shadow, 0.72 + 0.28 * ($py / 12.0));
                if ($px < 10) $shadow = min($shadow, 0.76 + 0.24 * ($px / 10.0));
                if ($px > $dw - 10) $shadow = min($shadow, 0.76 + 0.24 * (($dw - $px) / 10.0));
                if ($shadow < 0.999) {
                    $nr = clampByte($nr * $shadow);
                    $ng = clampByte($ng * $shadow);
                    $nb = clampByte($nb * $shadow);
                }
            }

            if ($alpha >= 0.998) {
                imagesetpixel($dstImg, $cx, $cy, ($nr << 16) | ($ng << 8) | $nb);
            } else {
                $dRgb = imagecolorat($dstImg, $cx, $cy);
                $dr = ($dRgb >> 16) & 255;
                $dg = ($dRgb >> 8) & 255;
                $db = $dRgb & 255;
                $or = clampByte($dr * (1.0 - $alpha) + $nr * $alpha);
                $og = clampByte($dg * (1.0 - $alpha) + $ng * $alpha);
                $ob = clampByte($db * (1.0 - $alpha) + $nb * $alpha);
                imagesetpixel($dstImg, $cx, $cy, ($or << 16) | ($og << 8) | $ob);
            }
        }
    }

    imagedestroy($patch);
}

/**
 * Applies smooth, speckle-free wood-stain polish grading ONLY inside the door silhouette,
 * keeping walls, floor tiles, and wood grain highlights smooth and natural.
 */
function applyPolishShadeGrading(
    $im,
    string $polishShade,
    array $outerRect,
    array $wallRef,
    ?array $customFinishRgb = null
): void {
    $profiles = [
        'Natural Teak Matte'      => ['r' => 1.00, 'g' => 1.00, 'b' => 1.00, 'contrast' => 1.00, 'strength' => 0.0],
        'Honey Gold Gloss'        => ['r' => 1.12, 'g' => 1.04, 'b' => 0.80, 'contrast' => 1.07, 'strength' => 0.65],
        'Dark Walnut Satin'       => ['r' => 0.64, 'g' => 0.56, 'b' => 0.50, 'contrast' => 1.06, 'strength' => 0.80],
        'Royal Rosewood Gloss'    => ['r' => 0.82, 'g' => 0.52, 'b' => 0.46, 'contrast' => 1.08, 'strength' => 0.82],
        'Antique Heritage Finish' => ['r' => 0.84, 'g' => 0.72, 'b' => 0.58, 'contrast' => 1.06, 'strength' => 0.72],
        'Natural PU Clear'        => ['r' => 1.05, 'g' => 1.03, 'b' => 0.96, 'contrast' => 1.04, 'strength' => 0.45],
    ];

    $p = $profiles[$polishShade] ?? $profiles['Natural Teak Matte'];
    $strength = (float)$p['strength'];

    $finishGain = [1.0, 1.0, 1.0];
    $hasFinish = false;
    if ($customFinishRgb !== null) {
        $baseWood = sampleAverageWoodColor($im, $outerRect['x'], $outerRect['y'], $outerRect['w'], $outerRect['h'], $wallRef);
        $finishGain = [
            max(0.72, min(1.30, $customFinishRgb[0] / max(20.0, $baseWood[0]))),
            max(0.72, min(1.30, $customFinishRgb[1] / max(20.0, $baseWood[1]))),
            max(0.70, min(1.28, $customFinishRgb[2] / max(20.0, $baseWood[2]))),
        ];
        $hasFinish = true;
    }

    if ($strength <= 0.01 && !$hasFinish) return;

    $w = imagesx($im);
    $h = imagesy($im);
    $contrast = (float)$p['contrast'];

    // Expand outer rect slightly to cover flared top crown while still excluding wall/floor margins
    $bx0 = max(0, $outerRect['x'] - 48);
    $by0 = max(0, $outerRect['y'] - 10);
    $bx1 = min($w - 1, $outerRect['x'] + $outerRect['w'] + 48);
    $by1 = min($h - 1, $outerRect['y'] + $outerRect['h'] + 8);

    for ($y = $by0; $y <= $by1; $y++) {
        for ($x = $bx0; $x <= $bx1; $x++) {
            $rgb = imagecolorat($im, $x, $y);
            $r = ($rgb >> 16) & 255;
            $g = ($rgb >> 8) & 255;
            $b = $rgb & 255;

            // Smooth wood mask: smoothly fades to 0 near wall color (ZERO speckles or sharp edges!)
            $distFromWall = colorDist($r, $g, $b, $wallRef);
            $wallMask = smoothstep(32.0, 75.0, $distFromWall);
            if ($wallMask <= 0.002) continue;

            // Smooth warm-tone mask so cool gray floor tiles stay neutral
            $warmth = (float)($r - $b);
            $lum = 0.299 * $r + 0.587 * $g + 0.114 * $b;
            $warmMask = ($lum < 90.0) ? 1.0 : smoothstep(-4.0, 18.0, $warmth);
            $mask = $wallMask * $warmMask;
            if ($mask <= 0.002) continue;

            $nr = (float)$r;
            $ng = (float)$g;
            $nb = (float)$b;

            if ($hasFinish) {
                $fMix = 0.45 * $mask;
                $nr = $nr * (1.0 + ($finishGain[0] - 1.0) * $fMix);
                $ng = $ng * (1.0 + ($finishGain[1] - 1.0) * $fMix);
                $nb = $nb * (1.0 + ($finishGain[2] - 1.0) * $fMix);
            }

            if ($strength > 0.01) {
                $s = $strength * $mask;
                $tr = $nr * $p['r'];
                $tg = $ng * $p['g'];
                $tb = $nb * $p['b'];
                $nr = $nr * (1.0 - $s) + $tr * $s;
                $ng = $ng * (1.0 - $s) + $tg * $s;
                $nb = $nb * (1.0 - $s) + $tb * $s;

                if (abs($contrast - 1.0) > 0.005) {
                    $c = 1.0 + ($contrast - 1.0) * $mask;
                    $nr = (($nr - 110.0) * $c) + 110.0;
                    $ng = (($ng - 85.0) * $c) + 85.0;
                    $nb = (($nb - 60.0) * $c) + 60.0;
                }
            }

            imagesetpixel($im, $x, $y, (clampByte($nr) << 16) | (clampByte($ng) << 8) | clampByte($nb));
        }
    }
}

/**
 * Optional Real Generative AI call via Google Gemini API (when GEMINI_API_KEY is set in config.php).
 * Sends the actual selected catalog door images + combination prompt so Gemini renders a true AI hybrid door.
 */
function tryGeminiAiCombine(array $opts, string $promptText, string $fullPath): bool {
    if (!defined('GEMINI_API_KEY') || trim((string)GEMINI_API_KEY) === '' || !function_exists('curl_init')) {
        return false;
    }

    $uploadsRoot = rtrim((string)($opts['uploads_root'] ?? dirname(__DIR__)), '/\\');
    $refDesigns = $opts['reference_designs'] ?? [];
    $parts = [];

    foreach ($refDesigns as $idx => $d) {
        $rel = (string)($d['image_url'] ?? '');
        $abs = $uploadsRoot . DIRECTORY_SEPARATOR . ltrim(str_replace('/', DIRECTORY_SEPARATOR, $rel), '/\\');
        if (is_file($abs)) {
            $raw = @file_get_contents($abs);
            if ($raw) {
                $mime = (stripos($abs, '.jpg') !== false || stripos($abs, '.jpeg') !== false) ? 'image/jpeg' : 'image/png';
                $parts[] = [
                    'text' => 'Reference Image ' . ($idx + 1) . ' (Design #' . $d['id'] . ' - ' . ($d['title'] ?? 'Catalog Door') . '):',
                ];
                $parts[] = [
                    'inline_data' => [
                        'mime_type' => $mime,
                        'data' => base64_encode($raw),
                    ],
                ];
            }
        }
    }

    $parts[] = [
        'text' => "Create a single ultra-realistic straight-on architectural showroom photograph (vertical 3:4 portrait, natural daylight against a warm cream wall, zero text or watermarks) of ONE unified custom handcrafted Indian wooden door combining the reference images exactly as instructed: $promptText",
    ];

    $model = defined('GEMINI_IMAGE_MODEL') && GEMINI_IMAGE_MODEL ? GEMINI_IMAGE_MODEL : 'gemini-2.5-flash-image';
    $url = 'https://generativelanguage.googleapis.com/v1beta/models/' . rawurlencode($model) . ':generateContent?key=' . rawurlencode((string)GEMINI_API_KEY);

    $payload = json_encode([
        'contents' => [['parts' => $parts]],
        'generationConfig' => [
            'responseModalities' => ['IMAGE', 'TEXT'],
        ],
    ]);

    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => $payload,
        CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 45,
        CURLOPT_CONNECTTIMEOUT => 10,
    ]);
    $resp = curl_exec($ch);
    $httpCode = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode !== 200 || !$resp) return false;
    $json = json_decode($resp, true);
    $candidates = $json['candidates'] ?? [];
    foreach ($candidates as $cand) {
        foreach (($cand['content']['parts'] ?? []) as $p) {
            $inline = $p['inlineData'] ?? $p['inline_data'] ?? null;
            if ($inline && !empty($inline['data'])) {
                $imgBytes = base64_decode($inline['data']);
                if ($imgBytes && strlen($imgBytes) > 4000) {
                    if (function_exists('imagecreatefromstring')) {
                        $gd = @imagecreatefromstring($imgBytes);
                        if ($gd) {
                            imagepng($gd, $fullPath);
                            imagedestroy($gd);
                            return true;
                        }
                    }
                    file_put_contents($fullPath, $imgBytes);
                    return true;
                }
            }
        }
    }
    return false;
}

/**
 * Photorealistic door combiner & renderer for cPanel PHP + GD:
 *  1) Uses Gemini multimodal image AI if GEMINI_API_KEY is configured.
 *  2) Otherwise composites the ACTUAL selected catalog reference photos (Frame Style,
 *     Top Arch & Crown, Center Carving, Panel Layout, Border / Polish Finish) with
 *     wood-tone matching, recessed shadows, feathered seams, and smooth polish grading.
 *  3) Falls back to procedural GD door rendering only if no reference photos exist on disk.
 */
function renderDoorPngPhp(array $opts): array {
    $woodSpecies = $opts['wood_species'] ?? 'Burma Teak';
    $polishShade = $opts['polish_shade'] ?? 'Natural Teak Matte';
    $leafType = $opts['leaf_type'] ?? 'Single Leaf';
    $category = $opts['woodwork_category'] ?? 'Door';
    $outputDir = $opts['output_dir'];
    $prefix = $opts['prefix'] ?? 'ai-combined';
    $uploadsRoot = rtrim((string)($opts['uploads_root'] ?? dirname(__DIR__)), '/\\');
    $refDesigns = is_array($opts['reference_designs'] ?? null) ? $opts['reference_designs'] : [];
    $refElements = is_array($opts['reference_elements'] ?? null) ? $opts['reference_elements'] : [];
    $promptText = (string)($opts['prompt_text'] ?? '');

    if (!is_dir($outputDir)) {
        mkdir($outputDir, 0755, true);
    }

    $filename = $prefix . '-' . time() . '-' . random_int(1000, 9999) . '.png';
    $fullPath = rtrim($outputDir, '/\\') . DIRECTORY_SEPARATOR . $filename;

    // 1. Try real Gemini multimodal AI generation if API key is configured
    if (!empty($refDesigns) && $promptText !== '' && tryGeminiAiCombine($opts, $promptText, $fullPath)) {
        return [
            'filename' => $filename,
            'full_path' => $fullPath,
            'engine' => 'gemini-multimodal-ai',
        ];
    }

    // 2. Photorealistic PHP GD Real-Photo Compositor using the actual selected catalog images
    $w = 600;
    $h = 800;
    if (!empty($refDesigns) && function_exists('imagecreatetruecolor') && function_exists('imagecreatefromstring')) {
        $loadedImgs = [];
        $boundsById = [];

        foreach ($refDesigns as $d) {
            $did = (int)($d['id'] ?? 0);
            $rel = (string)($d['image_url'] ?? '');
            if ($rel !== '') {
                $abs = $uploadsRoot . DIRECTORY_SEPARATOR . ltrim(str_replace('/', DIRECTORY_SEPARATOR, $rel), '/\\');
                $gd = loadNormalizedDoorImage($abs, $w, $h);
                if ($gd) {
                    $loadedImgs[$did] = $gd;
                    $boundsById[$did] = detectDoorBounds($gd);
                }
            }
        }

        if (!empty($loadedImgs)) {
            $ids = array_keys($loadedImgs);
            $elementMap = [];
            foreach ($refElements as $el) {
                $did = (int)($el['design_id'] ?? 0);
                $elName = strtolower(trim((string)($el['element'] ?? '')));
                if (isset($loadedImgs[$did]) && $elName !== '') {
                    $elementMap[$elName] = $did;
                }
            }

            $findByKeyword = function (array $keywords) use ($elementMap): ?int {
                foreach ($elementMap as $name => $did) {
                    foreach ($keywords as $kw) {
                        if (strpos($name, $kw) !== false) return $did;
                    }
                }
                return null;
            };

            $frameId  = $findByKeyword(['frame']);
            $crownId  = $findByKeyword(['arch', 'crown', 'top']);
            $panelId  = $findByKeyword(['panel', 'layout']);
            $centerId = $findByKeyword(['center', 'carving', 'medallion', 'bell']);
            $finishId = $findByKeyword(['polish', 'finish', 'border']);

            // Choose the BASE canvas cleanly so Frame Style (side pillars) NEVER leaks Top Arch & Crown!
            // Priority for base canvas:
            //  1) If a design is assigned Center Carving or Panel Layout, use it as base (so its top crown stays intact
            //     unless another design is explicitly assigned Top Arch & Crown!)
            //  2) Otherwise fall back to Frame Style, Crown, or first selected design.
            $baseId = $centerId ?? $panelId ?? $frameId ?? $crownId ?? $ids[0];

            // Start canvas with the chosen base photo
            $canvas = imagecreatetruecolor($w, $h);
            imagecopy($canvas, $loadedImgs[$baseId], 0, 0, 0, 0, $w, $h);
            $baseBounds = $boundsById[$baseId];
            $baseOuter = $baseBounds['outer'];
            $baseInner = $baseBounds['inner'];
            $baseWall  = $baseBounds['wall'];

            // Sample target wood color from the base door
            $baseWoodRgb = sampleAverageWoodColor(
                $canvas,
                $baseOuter['x'],
                $baseOuter['y'],
                $baseOuter['w'],
                max(60, (int)round($baseOuter['h'] * 0.35)),
                $baseWall
            );

            // 1) Frame Style (Left & Right carved side pillars + outer vertical frame ONLY — keeps top crown untouched!)
            if ($frameId !== null && $frameId !== $baseId && isset($loadedImgs[$frameId])) {
                $fBounds = $boundsById[$frameId];
                $fOuter = $fBounds['outer'];
                $fInner = $fBounds['inner'];

                $srcPillarTop = max($fOuter['y'], $fInner['y'] - 20);
                $srcPillarBot = min($fOuter['y'] + $fOuter['h'], $fInner['y'] + $fInner['h'] + 22);
                $srcPillarH   = max(100, $srcPillarBot - $srcPillarTop);

                $dstPillarTop = max($baseOuter['y'], $baseInner['y'] - 20);
                $dstPillarBot = min($baseOuter['y'] + $baseOuter['h'], $baseInner['y'] + $baseInner['h'] + 20);
                $dstPillarH   = max(100, $dstPillarBot - $dstPillarTop);

                // Left pillar strip (inset 4px from outer wall edge so no wall sliver carries over)
                $srcLeftPillar = [
                    'x' => $fOuter['x'] + 4,
                    'y' => $srcPillarTop,
                    'w' => max(28, $fInner['x'] - $fOuter['x'] - 4),
                    'h' => $srcPillarH,
                ];
                $dstLeftPillar = [
                    'x' => $baseOuter['x'] + 2,
                    'y' => $dstPillarTop,
                    'w' => max(28, $baseInner['x'] - $baseOuter['x'] - 2),
                    'h' => $dstPillarH,
                ];
                compositeRegionMatched($canvas, $loadedImgs[$frameId], $srcLeftPillar, $dstLeftPillar, $baseWoodRgb, 8, false, false, $fBounds['wall']);

                // Right pillar strip (inset 6px from outer wall edge so no wall sliver carries over)
                $fInnerRight = $fInner['x'] + $fInner['w'];
                $bInnerRight = $baseInner['x'] + $baseInner['w'];
                $srcRightPillar = [
                    'x' => $fInnerRight,
                    'y' => $srcPillarTop,
                    'w' => max(28, ($fOuter['x'] + $fOuter['w']) - $fInnerRight - 6),
                    'h' => $srcPillarH,
                ];
                $dstRightPillar = [
                    'x' => $bInnerRight,
                    'y' => $dstPillarTop,
                    'w' => max(28, ($baseOuter['x'] + $baseOuter['w']) - $bInnerRight - 4),
                    'h' => $dstPillarH,
                ];
                compositeRegionMatched($canvas, $loadedImgs[$frameId], $srcRightPillar, $dstRightPillar, $baseWoodRgb, 8, false, false, $fBounds['wall']);
            }

            // 2) Top Arch & Crown ONLY (cleanly replaces top arch/cornice while erasing old cornice corners!)
            if ($crownId !== null && $crownId !== $baseId && isset($loadedImgs[$crownId])) {
                $cBounds = $boundsById[$crownId];
                $cOuter = $cBounds['outer'];
                $cInner = $cBounds['inner'];
                $srcCrownH = max(90, ($cInner['y'] - $cOuter['y']) + 6);
                $dstCrownH = max(90, ($baseInner['y'] - $baseOuter['y']) + 6);
                $srcCrown = [
                    'x' => $cOuter['x'],
                    'y' => max(0, $cOuter['y'] - 8),
                    'w' => max(80, $cOuter['w'] - 4),
                    'h' => $srcCrownH + 8,
                ];
                // Erase wider old cornice wings using clean wall directly below the cornice at each exact X column!
                $clearLeft = max(0, $baseOuter['x'] - 56);
                $clearRight = min($w - 1, $baseOuter['x'] + $baseOuter['w'] + 56);
                $clearBot = $baseInner['y'] - 4;
                $sampleWallY = min($h - 10, $baseInner['y'] + 45);
                for ($cx = $clearLeft; $cx <= $clearRight; $cx++) {
                    if ($cx >= $baseOuter['x'] && $cx <= $baseOuter['x'] + $baseOuter['w']) continue;
                    // Sample clean wall vertically aligned at ($cx, $sampleWallY) & ($cx, 12)
                    $bRgb = imagecolorat($canvas, $cx, $sampleWallY);
                    $br = ($bRgb >> 16) & 255; $bg = ($bRgb >> 8) & 255; $bb = $bRgb & 255;
                    $tRgb = imagecolorat($canvas, $cx, 12);
                    $tr = ($tRgb >> 16) & 255; $tg = ($tRgb >> 8) & 255; $tb = $tRgb & 255;
                    if (colorDist($br, $bg, $bb, $baseWall) > 65.0) { $br = $tr; $bg = $tg; $bb = $tb; }
                    for ($cy = 14; $cy < $clearBot; $cy++) {
                        $t = ($cy - 14) / (float)max(1, $clearBot - 14);
                        $wr = clampByte($tr * (1.0 - $t) + $br * $t);
                        $wg = clampByte($tg * (1.0 - $t) + $bg * $t);
                        $wb = clampByte($tb * (1.0 - $t) + $bb * $t);
                        imagesetpixel($canvas, $cx, $cy, ($wr << 16) | ($wg << 8) | $wb);
                    }
                }
                $dstCrownFit = [
                    'x' => max(0, $baseOuter['x'] - 2),
                    'y' => max(0, $baseOuter['y'] - 8),
                    'w' => min($w - max(0, $baseOuter['x'] - 2), $baseOuter['w'] + 4),
                    'h' => $dstCrownH + 8,
                ];
                compositeRegionMatched($canvas, $loadedImgs[$crownId], $srcCrown, $dstCrownFit, $baseWoodRgb, 18, false, true, $cBounds['wall'], $baseWall);
            }

            // Helper to extract Single Leaf vs Double Leaf inner region cleanly without side pillars or floor
            $getLeavesSourceRect = function (int $srcId) use ($boundsById, $leafType): array {
                $lv = $boundsById[$srcId]['leaves'];
                if ($leafType === 'Single Leaf') {
                    return [
                        'x' => $lv['x'] + (int)round($lv['w'] * 0.03),
                        'y' => $lv['y'],
                        'w' => (int)round($lv['w'] * 0.46),
                        'h' => $lv['h'],
                    ];
                }
                return $lv;
            };

            // 3) Panel Layout (Full inner double-leaf shutter opening)
            if ($panelId !== null && $panelId !== $baseId && isset($loadedImgs[$panelId])) {
                $srcPanel = $getLeavesSourceRect($panelId);
                compositeRegionMatched($canvas, $loadedImgs[$panelId], $srcPanel, $baseInner, $baseWoodRgb, 12, true, false, $boundsById[$panelId]['wall']);
            }

            // 4) Center Carving (Inner door carving leaves or center medallion overlay if Panel Layout also replaced)
            if ($centerId !== null && $centerId !== $baseId && isset($loadedImgs[$centerId])) {
                if ($panelId === null || $panelId === $baseId) {
                    $srcInner = $getLeavesSourceRect($centerId);
                    compositeRegionMatched($canvas, $loadedImgs[$centerId], $srcInner, $baseInner, $baseWoodRgb, 12, true, false, $boundsById[$centerId]['wall']);
                } else {
                    $cLv = $boundsById[$centerId]['leaves'];
                    $srcMid = [
                        'x' => $cLv['x'] + (int)round($cLv['w'] * 0.06),
                        'y' => $cLv['y'] + (int)round($cLv['h'] * 0.08),
                        'w' => (int)round($cLv['w'] * 0.88),
                        'h' => (int)round($cLv['h'] * 0.72),
                    ];
                    $dstMid = [
                        'x' => $baseInner['x'] + (int)round($baseInner['w'] * 0.06),
                        'y' => $baseInner['y'] + (int)round($baseInner['h'] * 0.08),
                        'w' => (int)round($baseInner['w'] * 0.88),
                        'h' => (int)round($baseInner['h'] * 0.72),
                    ];
                    compositeRegionMatched($canvas, $loadedImgs[$centerId], $srcMid, $dstMid, $baseWoodRgb, 20, false, false, $boundsById[$centerId]['wall']);
                }
            }

            // Sample Border/Polish Finish wood color if assigned to a design
            $finishWoodRgb = null;
            if ($finishId !== null && isset($loadedImgs[$finishId])) {
                $fBounds = $boundsById[$finishId];
                $fOut = $fBounds['outer'];
                $finishWoodRgb = sampleAverageWoodColor($loadedImgs[$finishId], $fOut['x'], $fOut['y'], $fOut['w'], $fOut['h'], $fBounds['wall']);
            }

            // Apply smooth, speckle-free polish shade grading ONLY to the wooden door silhouette
            applyPolishShadeGrading($canvas, $polishShade, $baseOuter, $baseWall, $finishWoodRgb);

            imagepng($canvas, $fullPath, 6);
            imagedestroy($canvas);
            foreach ($loadedImgs as $res) {
                imagedestroy($res);
            }

            return [
                'filename' => $filename,
                'full_path' => $fullPath,
                'engine' => 'php-real-photo-combiner',
            ];
        }
    }

    // 3. Fallback procedural renderer (only used when no catalog photo exists on disk)
    $hex = getPolishHex($polishShade, $woodSpecies);
    [$r, $g, $b] = hexToRgbPhp($hex);
    $isDouble = ($leafType === 'Double Leaf');
    $isPooja = stripos($category, 'pooja') !== false;

    $fw = 420;
    $fh = 640;

    if (function_exists('imagecreatetruecolor')) {
        $im = imagecreatetruecolor($fw, $fh);
        $bg = imagecolorallocate($im, 242, 237, 230);
        imagefilledrectangle($im, 0, 0, $fw, $fh, $bg);

        $frameCol = imagecolorallocate($im, clampByte($r * 0.72), clampByte($g * 0.72), clampByte($b * 0.72));
        $baseCol = imagecolorallocate($im, $r, $g, $b);
        $darkCol = imagecolorallocate($im, clampByte($r * 0.45), clampByte($g * 0.45), clampByte($b * 0.45));
        $lightCol = imagecolorallocate($im, clampByte($r * 1.2), clampByte($g * 1.2), clampByte($b * 1.2));
        $brassCol = imagecolorallocate($im, 212, 175, 55);

        imagefilledrectangle($im, 42, 32, 378, 600, $frameCol);
        imagerectangle($im, 42, 32, 378, 600, $darkCol);
        imagefilledrectangle($im, 32, 20, 388, 36, $darkCol);
        imagefilledrectangle($im, 70, 60, 350, 592, $baseCol);
        imagerectangle($im, 70, 60, 350, 592, $darkCol);

        for ($x = 74; $x < 348; $x += 6) {
            $grainCol = imagecolorallocate($im, clampByte($r * 0.94), clampByte($g * 0.94), clampByte($b * 0.94));
            imageline($im, $x, 62, $x, 590, $grainCol);
        }

        $drawLeaf = function (int $lx, int $ly, int $lw, int $lh, bool $rightLeaf) use ($im, $darkCol, $lightCol, $brassCol, $isPooja) {
            $pad = 14;
            $pw = $lw - $pad * 2;
            $h1 = (int)($lh * 0.34);
            $h2 = (int)($lh * 0.28);
            $h3 = $lh - $h1 - $h2 - $pad * 4;
            $panels = [
                [$ly + $pad, $h1],
                [$ly + $pad * 2 + $h1, $h2],
                [$ly + $pad * 3 + $h1 + $h2, $h3],
            ];
            foreach ($panels as $idx => [$py, $ph]) {
                if ($ph < 20) continue;
                imagerectangle($im, $lx + $pad, $py, $lx + $pad + $pw, $py + $ph, $darkCol);
                imagerectangle($im, $lx + $pad + 4, $py + 4, $lx + $pad + $pw - 4, $py + $ph - 4, $lightCol);
                $cx = (int)($lx + $lw / 2);
                $cy = (int)($py + $ph / 2);
                if ($isPooja && $idx === 0) {
                    for ($row = 0; $row < 3; $row++) {
                        for ($col = 0; $col < 3; $col++) {
                            $bx = (int)($lx + $pad + 18 + $col * (($pw - 36) / 2));
                            $by = (int)($py + 22 + $row * (($ph - 44) / 2));
                            imagefilledellipse($im, $bx, $by, 12, 12, $brassCol);
                        }
                    }
                } elseif ($idx <= 1) {
                    imagefilledellipse($im, $cx, $cy, (int)($pw * 0.62), (int)($ph * 0.58), $darkCol);
                    imagefilledellipse($im, $cx, $cy, (int)($pw * 0.45), (int)($ph * 0.42), $lightCol);
                    imagefilledellipse($im, $cx, $cy, (int)($pw * 0.20), (int)($ph * 0.20), $brassCol);
                }
            }
            $hx = $rightLeaf ? ($lx + 10) : ($lx + $lw - 18);
            $hy = (int)($ly + $lh * 0.52);
            imagefilledrectangle($im, $hx, $hy - 26, $hx + 8, $hy + 26, $brassCol);
        };

        if ($isDouble) {
            $drawLeaf(70, 60, 138, 532, false);
            $drawLeaf(212, 60, 138, 532, true);
            imagefilledrectangle($im, 207, 60, 213, 592, $darkCol);
        } else {
            $drawLeaf(70, 60, 280, 532, false);
        }

        imagepng($im, $fullPath);
        imagedestroy($im);
    } else {
        $pngW = 160;
        $pngH = 240;
        $raw = '';
        for ($y = 0; $y < $pngH; $y++) {
            $raw .= "\x00";
            for ($x = 0; $x < $pngW; $x++) {
                $isFrame = ($x < 18 || $x > $pngW - 18 || $y < 18 || $y > $pngH - 12);
                $pr = $isFrame ? clampByte($r * 0.7) : $r;
                $pg = $isFrame ? clampByte($g * 0.7) : $g;
                $pb = $isFrame ? clampByte($b * 0.7) : $b;
                $raw .= chr($pr) . chr($pg) . chr($pb);
            }
        }
        $ihdr = pack('N2C5', $pngW, $pngH, 8, 2, 0, 0, 0);
        $idat = gzcompress($raw, 6);
        $chunk = function ($type, $data) {
            return pack('N', strlen($data)) . $type . $data . pack('N', crc32($type . $data));
        };
        $png = "\x89PNG\r\n\x1a\n" . $chunk('IHDR', $ihdr) . $chunk('IDAT', $idat) . $chunk('IEND', '');
        file_put_contents($fullPath, $png);
    }

    return [
        'filename' => $filename,
        'full_path' => $fullPath,
        'engine' => 'php-procedural-fallback',
    ];
}
