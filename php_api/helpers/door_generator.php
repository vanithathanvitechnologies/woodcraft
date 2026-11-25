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
 * Computes Euclidean RGB color distance between a pixel and a reference color.
 */
function colorDist(int $r, int $g, int $b, array $ref): float {
    $dr = $r - $ref[0];
    $dg = $g - $ref[1];
    $db = $b - $ref[2];
    return sqrt($dr * $dr + $dg * $dg + $db * $db);
}

/**
 * Checks whether a pixel is warm wood vs neutral white/cream backdrop.
 */
function isWoodPixel(int $r, int $g, int $b, ?array $wallRef = null): bool {
    if ($wallRef !== null && colorDist($r, $g, $b, $wallRef) < 38.0) {
        return false;
    }
    $max = max($r, $g, $b);
    $min = min($r, $g, $b);
    $sat = $max - $min;
    $lum = 0.299 * $r + 0.587 * $g + 0.114 * $b;

    if ($lum > 205 && $sat < 36) return false;
    if ($g > $r + 8 && $sat > 14) return false;
    return ($r >= $b - 6) && ($lum < 228);
}

/**
 * Detects the background color of a catalog/showroom image using perimeter points
 * while intentionally skipping the top-left corner (where catalog logos sit).
 */
function detectImageBackground($im): array {
    $w = imagesx($im);
    $h = imagesy($im);

    $pts = [
        [$w - 4, 4], [$w - 12, 4], [$w - 4, 14],
        [$w - 4, (int)($h * 0.25)], [$w - 4, (int)($h * 0.50)], [$w - 4, (int)($h * 0.75)],
        [4, $h - 5], [(int)($w * 0.50), $h - 5], [$w - 5, $h - 5],
        [4, (int)($h * 0.50)], [4, (int)($h * 0.75)],
    ];

    $rs = []; $gs = []; $bs = [];
    foreach ($pts as [$x, $y]) {
        $cx = max(0, min($w - 1, $x));
        $cy = max(0, min($h - 1, $y));
        $rgb = imagecolorat($im, $cx, $cy);
        $rs[] = ($rgb >> 16) & 255;
        $gs[] = ($rgb >> 8) & 255;
        $bs[] = $rgb & 255;
    }
    sort($rs); sort($gs); sort($bs);
    $mid = (int)floor(count($rs) / 2);
    $bg = [(float)$rs[$mid], (float)$gs[$mid], (float)$bs[$mid]];

    $lum = 0.299 * $bg[0] + 0.587 * $bg[1] + 0.114 * $bg[2];
    $sat = max($bg[0], $bg[1], $bg[2]) - min($bg[0], $bg[1], $bg[2]);

    $matching = 0;
    foreach ($pts as [$x, $y]) {
        $cx = max(0, min($w - 1, $x));
        $cy = max(0, min($h - 1, $y));
        $rgb = imagecolorat($im, $cx, $cy);
        if (colorDist(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $bg) < 36.0) {
            $matching++;
        }
    }

    // Uniform bright/neutral backdrop (catalog white or clean cream wall)
    $hasCleanBg = ($lum >= 178.0 && $sat <= 48.0 && $matching >= 6);
    return ['bg' => $bg, 'has_clean_bg' => $hasCleanBg];
}

/**
 * Loads a source catalog image at full resolution WITHOUT ever cover-cropping it,
 * isolates the complete wooden door/frame object (automatically removing detached
 * top-left header logos like "SURESH TIMBERS"), and measures exact inner opening,
 * crown, and pillar geometry.
 */
function extractDoorObject(string $absPath, array $meta = []): ?array {
    if (!is_file($absPath) || !function_exists('imagecreatefromstring')) {
        return null;
    }
    $bytes = @file_get_contents($absPath);
    if (!$bytes) return null;
    $src = @imagecreatefromstring($bytes);
    if (!$src) return null;

    $sw = imagesx($src);
    $sh = imagesy($src);
    if ($sw < 20 || $sh < 20) {
        imagedestroy($src);
        return null;
    }

    $bgInfo = detectImageBackground($src);
    $bg = $bgInfo['bg'];
    $hasCleanBg = $bgInfo['has_clean_bg'];

    $cropX0 = 0;
    $cropY0 = 0;
    $cropX1 = $sw - 1;
    $cropY1 = $sh - 1;
    $cleanGrid = null;
    $gridScale = 4;
    $gw = 0;
    $gh = 0;
    $mainCompId = 0;

    if ($hasCleanBg) {
        // 2D Connected-Component isolation on a fast downsampled grid:
        // Keeps 100% of the complete wooden door/frame (including tall arches & flared cornices)
        // while cleanly removing detached catalog header logos (e.g. top-left "SURESH TIMBERS")
        // even when a tall temple arch rises beside the logo!
        $gridScale = max(2, (int)floor(max($sw, $sh) / 210));
        $gw = (int)ceil($sw / $gridScale);
        $gh = (int)ceil($sh / $gridScale);
        $fgGrid = array_fill(0, $gw * $gh, 0);

        for ($gy = 0; $gy < $gh; $gy++) {
            $sy = min($sh - 1, $gy * $gridScale + (int)floor($gridScale / 2));
            for ($gx = 0; $gx < $gw; $gx++) {
                $sx = min($sw - 1, $gx * $gridScale + (int)floor($gridScale / 2));
                $rgb = imagecolorat($src, $sx, $sy);
                if (colorDist(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $bg) > 24.0) {
                    $fgGrid[$gy * $gw + $gx] = 1;
                }
            }
        }

        // 1-cell morphological dilation bridges tiny 2-4px bright reflections inside wood carvings
        $dilated = $fgGrid;
        for ($gy = 1; $gy < $gh - 1; $gy++) {
            $rowOff = $gy * $gw;
            for ($gx = 1; $gx < $gw - 1; $gx++) {
                if ($fgGrid[$rowOff + $gx] === 1) {
                    $dilated[$rowOff + $gx - 1] = 1;
                    $dilated[$rowOff + $gx + 1] = 1;
                    $dilated[$rowOff - $gw + $gx] = 1;
                    $dilated[$rowOff + $gw + $gx] = 1;
                }
            }
        }

        // Label connected components via BFS
        $labels = array_fill(0, $gw * $gh, 0);
        $compSizes = [];
        $compBoxes = [];
        $nextLabel = 1;
        $queue = new SplQueue();

        for ($i = 0; $i < $gw * $gh; $i++) {
            if ($dilated[$i] === 1 && $labels[$i] === 0) {
                $lbl = $nextLabel++;
                $labels[$i] = $lbl;
                $queue->enqueue($i);
                $size = 0;
                $minX = $gw; $maxX = 0; $minY = $gh; $maxY = 0;

                while (!$queue->isEmpty()) {
                    $idx = $queue->dequeue();
                    $size++;
                    $cx = $idx % $gw;
                    $cy = intdiv($idx, $gw);
                    if ($cx < $minX) $minX = $cx;
                    if ($cx > $maxX) $maxX = $cx;
                    if ($cy < $minY) $minY = $cy;
                    if ($cy > $maxY) $maxY = $cy;

                    if ($cx > 0 && $dilated[$idx - 1] === 1 && $labels[$idx - 1] === 0) {
                        $labels[$idx - 1] = $lbl; $queue->enqueue($idx - 1);
                    }
                    if ($cx + 1 < $gw && $dilated[$idx + 1] === 1 && $labels[$idx + 1] === 0) {
                        $labels[$idx + 1] = $lbl; $queue->enqueue($idx + 1);
                    }
                    if ($cy > 0 && $dilated[$idx - $gw] === 1 && $labels[$idx - $gw] === 0) {
                        $labels[$idx - $gw] = $lbl; $queue->enqueue($idx - $gw);
                    }
                    if ($cy + 1 < $gh && $dilated[$idx + $gw] === 1 && $labels[$idx + $gw] === 0) {
                        $labels[$idx + $gw] = $lbl; $queue->enqueue($idx + $gw);
                    }
                }
                $compSizes[$lbl] = $size;
                $compBoxes[$lbl] = [$minX, $minY, $maxX, $maxY];
            }
        }

        if (!empty($compSizes)) {
            arsort($compSizes);
            $mainCompId = (int)array_key_first($compSizes);
            [$bMinX, $bMinY, $bMaxX, $bMaxY] = $compBoxes[$mainCompId];

            $left = max(0, $bMinX * $gridScale);
            $top = max(0, $bMinY * $gridScale);
            $right = min($sw - 1, ($bMaxX + 1) * $gridScale);
            $bottom = min($sh - 1, ($bMaxY + 1) * $gridScale);

            // Refine bounding box edges to exact pixel precision using the main component mask
            if (($right - $left) >= (int)($sw * 0.22) && ($bottom - $top) >= (int)($sh * 0.28)) {
                $cropX0 = max(0, $left - 2);
                $cropY0 = max(0, $top - 2);
                $cropX1 = min($sw - 1, $right + 2);
                $cropY1 = min($sh - 1, $bottom + 2);
                $cleanGrid = $labels;
            }
        }
    }

    $ow = max(1, $cropX1 - $cropX0 + 1);
    $oh = max(1, $cropY1 - $cropY0 + 1);
    $obj = imagecreatetruecolor($ow, $oh);
    imagealphablending($obj, true);
    imagecopy($obj, $src, 0, 0, $cropX0, $cropY0, $ow, $oh);
    imagedestroy($src);

    // Erase any detached non-door components (e.g. header logo overlapping the crown's bounding box)
    if ($cleanGrid !== null && $mainCompId > 0) {
        $bgInt = (clampByte($bg[0]) << 16) | (clampByte($bg[1]) << 8) | clampByte($bg[2]);
        for ($oy = 0; $oy < $oh; $oy++) {
            $gy = min($gh - 1, intdiv($cropY0 + $oy, $gridScale));
            $rowOff = $gy * $gw;
            for ($ox = 0; $ox < $ow; $ox++) {
                $gx = min($gw - 1, intdiv($cropX0 + $ox, $gridScale));
                $lbl = $cleanGrid[$rowOff + $gx];
                if ($lbl !== 0 && $lbl !== $mainCompId) {
                    imagesetpixel($obj, $ox, $oy, $bgInt);
                }
            }
        }
    }

    // Strip residual exterior cool-gray/blue wall cutout slivers (e.g. pale marble/wall strips
    // left along the outer left, right, and top edges of catalog door photos)
    if ($hasCleanBg) {
        $bgInt = (clampByte($bg[0]) << 16) | (clampByte($bg[1]) << 8) | clampByte($bg[2]);
        $isExteriorWallHalo = function (int $r, int $g, int $b) use ($bg): bool {
            if (colorDist($r, $g, $b, $bg) <= 28.0) return true;
            $lum = 0.299 * $r + 0.587 * $g + 0.114 * $b;
            $sat = max($r, $g, $b) - min($r, $g, $b);
            // Cool blue-gray wall / shadow sliver: blue clearly exceeds red, not dark wood
            if ($b >= $r + 6 && $lum >= 55.0) return true;
            // Bright or mid-light neutral gray/off-white wall cutout rim
            if ($lum >= 162.0 && $sat <= 24.0 && $b >= $r - 5) return true;
            return false;
        };

        $maxEdgeScanX = min(56, (int)round($ow * 0.14));
        for ($oy = 0; $oy < $oh; $oy++) {
            // Walk inward from left outer edge
            $woodStreak = 0;
            for ($ox = 0; $ox < $maxEdgeScanX; $ox++) {
                $rgb = imagecolorat($obj, $ox, $oy);
                if ($isExteriorWallHalo(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255)) {
                    imagesetpixel($obj, $ox, $oy, $bgInt);
                    $woodStreak = 0;
                } else {
                    $woodStreak++;
                    if ($woodStreak >= 2) break;
                }
            }
            // Walk inward from right outer edge
            $woodStreak = 0;
            for ($ox = $ow - 1; $ox >= max(0, $ow - $maxEdgeScanX); $ox--) {
                $rgb = imagecolorat($obj, $ox, $oy);
                if ($isExteriorWallHalo(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255)) {
                    imagesetpixel($obj, $ox, $oy, $bgInt);
                    $woodStreak = 0;
                } else {
                    $woodStreak++;
                    if ($woodStreak >= 2) break;
                }
            }
        }
        // Walk downward from top outer edge to clear pale top wall/marble strips
        $maxEdgeScanY = min(36, (int)round($oh * 0.08));
        for ($ox = 0; $ox < $ow; $ox++) {
            $woodStreak = 0;
            for ($oy = 0; $oy < $maxEdgeScanY; $oy++) {
                $rgb = imagecolorat($obj, $ox, $oy);
                if ($isExteriorWallHalo(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255)) {
                    imagesetpixel($obj, $ox, $oy, $bgInt);
                    $woodStreak = 0;
                } else {
                    $woodStreak++;
                    if ($woodStreak >= 2) break;
                }
            }
        }

        // Re-tighten crop bounds after stripping exterior cool-wall slivers so outer bounds hug real wood
        $tL = $ow; $tR = 0; $tT = $oh; $tB = 0;
        for ($oy = 0; $oy < $oh; $oy += 2) {
            for ($ox = 0; $ox < $ow; $ox += 2) {
                $rgb = imagecolorat($obj, $ox, $oy);
                if (colorDist(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $bg) > 26.0) {
                    if ($ox < $tL) $tL = $ox;
                    if ($ox > $tR) $tR = $ox;
                    if ($oy < $tT) $tT = $oy;
                    if ($oy > $tB) $tB = $oy;
                }
            }
        }
        if ($tR - $tL > (int)($ow * 0.55) && $tB - $tT > (int)($oh * 0.65)) {
            $tL = max(0, $tL - 1);
            $tT = max(0, $tT - 1);
            $tR = min($ow - 1, $tR + 1);
            $tB = min($oh - 1, $tB + 1);
            $nw = max(1, $tR - $tL + 1);
            $nh = max(1, $tB - $tT + 1);
            if ($nw < $ow || $nh < $oh) {
                $trimmed = imagecreatetruecolor($nw, $nh);
                imagealphablending($trimmed, true);
                imagecopy($trimmed, $obj, 0, 0, $tL, $tT, $nw, $nh);
                imagedestroy($obj);
                $obj = $trimmed;
                $ow = $nw;
                $oh = $nh;
            }
        }
    }

    // 3) Analyze structure: Framed Door (pillars + crown) vs Pure Shutter Slab vs Landscape Material
    $aspect = $ow / (float)$oh;

    $measureRowSpan = function (int $y) use ($obj, $ow, $bg, $hasCleanBg): array {
        $y = max(0, min(imagesy($obj) - 1, $y));
        if (!$hasCleanBg) return [0, $ow - 1, $ow];
        $l = $ow; $r = 0; $fg = 0;
        for ($x = 0; $x < $ow; $x += 2) {
            $rgb = imagecolorat($obj, $x, $y);
            if (colorDist(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $bg) > 26.0) {
                if ($x < $l) $l = $x;
                if ($x > $r) $r = $x;
                $fg += 2;
            }
        }
        if ($r < $l) return [0, $ow - 1, 0];
        return [$l, $r, $fg];
    };

    $topSpan = $measureRowSpan((int)round($oh * 0.05));
    $crownSpan = $measureRowSpan((int)round($oh * 0.10));
    $midSpan1 = $measureRowSpan((int)round($oh * 0.45));
    $midSpan2 = $measureRowSpan((int)round($oh * 0.65));

    $topFill = $topSpan[2] / max(1.0, (float)$ow);
    $topOuterW = max($topSpan[1] - $topSpan[0], $crownSpan[1] - $crownSpan[0]);
    $midLeft = (int)round(($midSpan1[0] + $midSpan2[0]) / 2.0);
    $midRight = (int)round(($midSpan1[1] + $midSpan2[1]) / 2.0);
    $midOuterW = max(1, $midRight - $midLeft);

    $hasArchedCrown = $hasCleanBg && ($topFill < 0.86);
    $hasFlaredCrown = $hasCleanBg && ($topOuterW > $midOuterW * 1.035);
    $isLandscapeMaterial = ($aspect > 1.05);

    $titleLow = strtolower((string)($meta['title'] ?? '') . ' ' . (string)($meta['carving_style'] ?? ''));
    $metaSuggestsFrame = (
        strpos($titleLow, 'nilai') !== false ||
        strpos($titleLow, 'wood frame') !== false ||
        strpos($titleLow, 'pillar') !== false ||
        strpos($titleLow, 'crown') !== false
    );

    // Framed door detection (pillars/jambs around inner door leaf)
    $isFramed = !$isLandscapeMaterial && ($hasArchedCrown || $hasFlaredCrown || $aspect >= 0.60 || ($metaSuggestsFrame && $aspect >= 0.55));

    // 4) Detect inner door opening & crown/lintel boundary
    if ($isFramed) {
        // Detect symmetric pillar width using recessed vertical shadow + horizontal gradient inside y=36%..82%
        $yScan0 = (int)round($oh * 0.36);
        $yScan1 = (int)round($oh * 0.82);
        // Wide fluted double-door frames (aspect >= 0.74, e.g. #059) have sleeker side pillars (~11%–14%),
        // while tall temple Nilai frames (#001, #020) have wider carved pillars (~19%–24%).
        $priorCenter = ($aspect >= 0.74) ? 0.125 : 0.205;
        $minPct = ($aspect >= 0.74) ? 9 : 14;
        $maxPct = ($aspect >= 0.74) ? 20 : 28;
        $bestPillarFrac = $priorCenter;
        $bestScore = -1e9;

        for ($pct = $minPct; $pct <= $maxPct; $pct++) {
            $frac = $pct / 100.0;
            $xl = $midLeft + (int)round($midOuterW * $frac);
            $xr = $midRight - (int)round($midOuterW * $frac);
            if ($xl < 4 || $xr > $ow - 5 || $xr - $xl < (int)($midOuterW * 0.38)) continue;

            $darkSum = 0.0;
            $edgeSum = 0.0;
            $n = 0;
            for ($y = $yScan0; $y <= $yScan1; $y += 4) {
                $rgbL = imagecolorat($obj, $xl, $y);
                $lumL = 0.299 * (($rgbL >> 16) & 255) + 0.587 * (($rgbL >> 8) & 255) + 0.114 * ($rgbL & 255);
                $rgbL1 = imagecolorat($obj, max(0, $xl - 3), $y);
                $lumL1 = 0.299 * (($rgbL1 >> 16) & 255) + 0.587 * (($rgbL1 >> 8) & 255) + 0.114 * ($rgbL1 & 255);
                $rgbL2 = imagecolorat($obj, min($ow - 1, $xl + 3), $y);
                $lumL2 = 0.299 * (($rgbL2 >> 16) & 255) + 0.587 * (($rgbL2 >> 8) & 255) + 0.114 * ($rgbL2 & 255);

                $rgbR = imagecolorat($obj, $xr, $y);
                $lumR = 0.299 * (($rgbR >> 16) & 255) + 0.587 * (($rgbR >> 8) & 255) + 0.114 * ($rgbR & 255);
                $rgbR1 = imagecolorat($obj, max(0, $xr - 3), $y);
                $lumR1 = 0.299 * (($rgbR1 >> 16) & 255) + 0.587 * (($rgbR1 >> 8) & 255) + 0.114 * ($rgbR1 & 255);
                $rgbR2 = imagecolorat($obj, min($ow - 1, $xr + 3), $y);
                $lumR2 = 0.299 * (($rgbR2 >> 16) & 255) + 0.587 * (($rgbR2 >> 8) & 255) + 0.114 * ($rgbR2 & 255);

                // Recessed jamb shadow is darker than its neighbors and has sharp edge contrast
                $darkSum += (255.0 - $lumL) + (255.0 - $lumR);
                $edgeSum += abs($lumL2 - $lumL1) + abs($lumR1 - $lumR2);
                $n++;
            }
            if ($n > 0) {
                $prior = 1.0 - abs($frac - $priorCenter) * 1.8;
                $score = (($darkSum / $n) * 0.45 + ($edgeSum / $n) * 1.15) * max(0.60, $prior);
                if ($score > $bestScore) {
                    $bestScore = $score;
                    $bestPillarFrac = $frac;
                }
            }
        }

        $innerL = $midLeft + (int)round($midOuterW * $bestPillarFrac);
        $innerR = $midRight - (int)round($midOuterW * $bestPillarFrac);

        // Detect horizontal recessed lintel shadow line separating crown/header from door leaf
        $lintelMinY = (int)round($oh * ($hasArchedCrown ? 0.19 : 0.11));
        $lintelMaxY = (int)round($oh * ($hasArchedCrown ? 0.36 : 0.28));
        $bestLintelY = (int)round($oh * ($hasArchedCrown ? 0.24 : 0.16));
        $bestLintelScore = -1e9;

        for ($y = $lintelMinY; $y <= $lintelMaxY; $y += 2) {
            $darkSum = 0.0;
            $edgeSum = 0.0;
            $n = 0;
            for ($x = $innerL + 8; $x <= $innerR - 8; $x += 4) {
                $rgb = imagecolorat($obj, $x, $y);
                $lum = 0.299 * (($rgb >> 16) & 255) + 0.587 * (($rgb >> 8) & 255) + 0.114 * ($rgb & 255);
                $rgbUp = imagecolorat($obj, $x, max(0, $y - 3));
                $lumUp = 0.299 * (($rgbUp >> 16) & 255) + 0.587 * (($rgbUp >> 8) & 255) + 0.114 * ($rgbUp & 255);
                $rgbDn = imagecolorat($obj, $x, min($oh - 1, $y + 3));
                $lumDn = 0.299 * (($rgbDn >> 16) & 255) + 0.587 * (($rgbDn >> 8) & 255) + 0.114 * ($rgbDn & 255);
                $darkSum += (255.0 - $lum);
                $edgeSum += abs($lumDn - $lumUp);
                $n++;
            }
            if ($n > 0) {
                $score = ($darkSum / $n) * 0.55 + ($edgeSum / $n) * 1.15;
                if ($score > $bestLintelScore) {
                    $bestLintelScore = $score;
                    $bestLintelY = $y;
                }
            }
        }

        // Detect bottom threshold step if present (stay cleanly above plinth/floor step)
        $innerB = (int)round($oh * 0.945);
        $bestBotScore = -1e9;
        for ($y = (int)round($oh * 0.89); $y <= (int)round($oh * 0.985); $y += 2) {
            $darkSum = 0.0;
            $edgeSum = 0.0;
            $n = 0;
            for ($x = $innerL + 8; $x <= $innerR - 8; $x += 4) {
                $rgb = imagecolorat($obj, $x, $y);
                $lum = 0.299 * (($rgb >> 16) & 255) + 0.587 * (($rgb >> 8) & 255) + 0.114 * ($rgb & 255);
                $rgbUp = imagecolorat($obj, $x, max(0, $y - 3));
                $lumUp = 0.299 * (($rgbUp >> 16) & 255) + 0.587 * (($rgbUp >> 8) & 255) + 0.114 * ($rgbUp & 255);
                $rgbDn = imagecolorat($obj, $x, min($oh - 1, $y + 3));
                $lumDn = 0.299 * (($rgbDn >> 16) & 255) + 0.587 * (($rgbDn >> 8) & 255) + 0.114 * ($rgbDn & 255);
                $darkSum += (255.0 - $lum);
                $edgeSum += abs($lumDn - $lumUp);
                $n++;
            }
            if ($n > 0) {
                $score = ($darkSum / $n) * 0.45 + ($edgeSum / $n) * 1.0;
                if ($score > $bestBotScore) {
                    $bestBotScore = $score;
                    $innerB = $y;
                }
            }
        }

        $innerRect = [
            'x' => $innerL,
            'y' => $bestLintelY,
            'w' => max(60, $innerR - $innerL),
            'h' => max(100, $innerB - $bestLintelY),
        ];
        // Source leaf cutout inside a framed door (tiny 2% inset to avoid jamb shadow bleed)
        $srcLeafRect = [
            'x' => $innerRect['x'] + (int)round($innerRect['w'] * 0.025),
            'y' => $innerRect['y'] + (int)round($innerRect['h'] * 0.02),
            'w' => max(50, (int)round($innerRect['w'] * 0.95)),
            'h' => max(80, (int)round($innerRect['h'] * 0.96)),
        ];
        $crownBottomY = $bestLintelY;
    } else {
        // Pure door shutter / slab (NO outer Nilai frame) — keep 96% intact when used as leaf!
        $srcLeafRect = [
            'x' => (int)round($ow * 0.02),
            'y' => (int)round($oh * 0.02),
            'w' => max(50, (int)round($ow * 0.96)),
            'h' => max(80, (int)round($oh * 0.96)),
        ];
        // When a pure shutter serves as the outer frame border, nest inner carving cleanly inside its stiles/rails
        $innerRect = [
            'x' => (int)round($ow * 0.125),
            'y' => (int)round($oh * 0.095),
            'w' => max(50, (int)round($ow * 0.75)),
            'h' => max(80, (int)round($oh * 0.81)),
        ];
        $crownBottomY = (int)round($oh * 0.15);
    }

    return [
        'img' => $obj,
        'w' => $ow,
        'h' => $oh,
        'aspect' => $aspect,
        'bg' => $bg,
        'has_clean_bg' => $hasCleanBg,
        'is_framed' => $isFramed,
        'is_landscape' => $isLandscapeMaterial,
        'has_arched_crown' => $hasArchedCrown,
        'has_flared_crown' => $hasFlaredCrown,
        'mid_left' => $midLeft,
        'mid_right' => $midRight,
        'inner' => $innerRect,
        'leaf' => $srcLeafRect,
        'crown_bottom_y' => $crownBottomY,
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
    if ($cnt < 15) return [138.0, 90.0, 48.0];
    return [$sumR / $cnt, $sumG / $cnt, $sumB / $cnt];
}

/**
 * Blits an extracted object cleanly onto the crisp studio canvas with optional
 * white-background cleanup (turning off-white JPEG halos into pure canvas backdrop).
 */
function blitCleanObjectToCanvas($canvas, array $objData, int $dstX, int $dstY, int $dstW, int $dstH, array $canvasBg): void {
    $tmp = imagecreatetruecolor($dstW, $dstH);
    imagecopyresampled($tmp, $objData['img'], 0, 0, 0, 0, $dstW, $dstH, $objData['w'], $objData['h']);

    $cw = imagesx($canvas);
    $ch = imagesy($canvas);
    $hasCleanBg = $objData['has_clean_bg'];
    $srcBg = $objData['bg'];

    for ($py = 0; $py < $dstH; $py++) {
        $cy = $dstY + $py;
        if ($cy < 0 || $cy >= $ch) continue;
        for ($px = 0; $px < $dstW; $px++) {
            $cx = $dstX + $px;
            if ($cx < 0 || $cx >= $cw) continue;

            $rgb = imagecolorat($tmp, $px, $py);
            $r = ($rgb >> 16) & 255;
            $g = ($rgb >> 8) & 255;
            $b = $rgb & 255;

            if ($hasCleanBg) {
                $d = colorDist($r, $g, $b, $srcBg);
                if ($d <= 22.0) continue; // Keep pure crisp canvas backdrop
                if ($d < 44.0) {
                    $alpha = smoothstep(22.0, 44.0, $d);
                    $or = clampByte($canvasBg[0] * (1.0 - $alpha) + $r * $alpha);
                    $og = clampByte($canvasBg[1] * (1.0 - $alpha) + $g * $alpha);
                    $ob = clampByte($canvasBg[2] * (1.0 - $alpha) + $b * $alpha);
                    imagesetpixel($canvas, $cx, $cy, ($or << 16) | ($og << 8) | $ob);
                    continue;
                }
            }
            imagesetpixel($canvas, $cx, $cy, $rgb);
        }
    }
    imagedestroy($tmp);
}

/**
 * Composites a door shutter, center carving, or crown cleanly onto the canvas
 * with natural wood-tone harmonization, crisp anti-aliased seams, optional recessed
 * inner-jamb shadow, and clean background transparency for curved crowns.
 */
function compositeRegionClean(
    $dstImg,
    $srcImg,
    array $srcRect,
    array $dstRect,
    array $targetWoodRgb,
    int $feather = 8,
    bool $addRecessShadow = true,
    bool $isCrownOverlay = false,
    bool $srcHasCleanBg = false,
    ?array $srcBg = null,
    bool $roundedMask = false
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

    $srcWood = sampleAverageWoodColor($patch, 0, 0, $dw, $dh, $srcHasCleanBg ? $srcBg : null);
    $gainR = max(0.76, min(1.30, $targetWoodRgb[0] / max(22.0, $srcWood[0])));
    $gainG = max(0.76, min(1.30, $targetWoodRgb[1] / max(22.0, $srcWood[1])));
    $gainB = max(0.74, min(1.28, $targetWoodRgb[2] / max(22.0, $srcWood[2])));

    // Gentle wood-tone matching so source carving keeps its rich crisp highlights & brass glow
    $mix = $isCrownOverlay ? 0.72 : 0.62;
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
                if ($px < 4) $alphaX = min($alphaX, smoothstep(0.0, 4.0, (float)$px));
                if ($px > $dw - 4) $alphaX = min($alphaX, smoothstep(0.0, 4.0, (float)($dw - $px)));
            }

            $alpha = $alphaX * $alphaY;

            // Optional soft rounded vignette mask for center medallion blending
            if ($roundedMask) {
                $nx = ($px / max(1.0, (float)($dw - 1))) * 2.0 - 1.0;
                $ny = ($py / max(1.0, (float)($dh - 1))) * 2.0 - 1.0;
                $rad = pow(abs($nx), 4.0) + pow(abs($ny), 4.0);
                $alpha *= (1.0 - smoothstep(0.58, 1.02, $rad));
            }

            // Transparent cutout for curved/arched crowns over studio backdrop
            if ($isCrownOverlay && $srcHasCleanBg && $srcBg !== null) {
                $dist = colorDist($sr, $sg, $sb, $srcBg);
                $woodAmt = smoothstep(22.0, 48.0, $dist);
                $alpha *= $woodAmt;
            }

            if ($alpha <= 0.003) continue;

            $nr = clampByte($sr * $gR);
            $ng = clampByte($sg * $gG);
            $nb = clampByte($sb * $gB);

            // Subtle natural recessed frame shadow inside doorway jambs
            if ($addRecessShadow) {
                $shadow = 1.0;
                if ($py < 11) $shadow = min($shadow, 0.74 + 0.26 * ($py / 11.0));
                if ($px < 9) $shadow = min($shadow, 0.78 + 0.22 * ($px / 9.0));
                if ($px > $dw - 9) $shadow = min($shadow, 0.78 + 0.22 * (($dw - $px) / 9.0));
                if ($shadow < 0.999) {
                    $nr = clampByte($nr * $shadow);
                    $ng = clampByte($ng * $shadow);
                    $nb = clampByte($nb * $shadow);
                }
            }

            if ($alpha >= 0.996) {
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
 * Applies smooth, speckle-free wood-stain polish grading ONLY inside the wooden door,
 * leaving the crisp studio backdrop untouched.
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
        'Honey Gold Gloss'        => ['r' => 1.12, 'g' => 1.04, 'b' => 0.80, 'contrast' => 1.06, 'strength' => 0.62],
        'Dark Walnut Satin'       => ['r' => 0.66, 'g' => 0.58, 'b' => 0.52, 'contrast' => 1.05, 'strength' => 0.78],
        'Royal Rosewood Gloss'    => ['r' => 0.84, 'g' => 0.54, 'b' => 0.48, 'contrast' => 1.06, 'strength' => 0.78],
        'Antique Heritage Finish' => ['r' => 0.86, 'g' => 0.74, 'b' => 0.60, 'contrast' => 1.05, 'strength' => 0.68],
        'Natural PU Clear'        => ['r' => 1.04, 'g' => 1.02, 'b' => 0.96, 'contrast' => 1.04, 'strength' => 0.42],
    ];

    $p = $profiles[$polishShade] ?? $profiles['Natural Teak Matte'];
    $strength = (float)$p['strength'];

    $finishGain = [1.0, 1.0, 1.0];
    $hasFinish = false;
    if ($customFinishRgb !== null) {
        $baseWood = sampleAverageWoodColor($im, $outerRect['x'], $outerRect['y'], $outerRect['w'], $outerRect['h'], $wallRef);
        $finishGain = [
            max(0.74, min(1.28, $customFinishRgb[0] / max(22.0, $baseWood[0]))),
            max(0.74, min(1.28, $customFinishRgb[1] / max(22.0, $baseWood[1]))),
            max(0.72, min(1.26, $customFinishRgb[2] / max(22.0, $baseWood[2]))),
        ];
        $hasFinish = true;
    }

    if ($strength <= 0.01 && !$hasFinish) return;

    $w = imagesx($im);
    $h = imagesy($im);
    $contrast = (float)$p['contrast'];

    $bx0 = max(0, $outerRect['x'] - 24);
    $by0 = max(0, $outerRect['y'] - 24);
    $bx1 = min($w - 1, $outerRect['x'] + $outerRect['w'] + 24);
    $by1 = min($h - 1, $outerRect['y'] + $outerRect['h'] + 10);

    for ($y = $by0; $y <= $by1; $y++) {
        for ($x = $bx0; $x <= $bx1; $x++) {
            $rgb = imagecolorat($im, $x, $y);
            $r = ($rgb >> 16) & 255;
            $g = ($rgb >> 8) & 255;
            $b = $rgb & 255;

            $distFromWall = colorDist($r, $g, $b, $wallRef);
            $wallMask = smoothstep(26.0, 62.0, $distFromWall);
            if ($wallMask <= 0.002) continue;

            $warmth = (float)($r - $b);
            $lum = 0.299 * $r + 0.587 * $g + 0.114 * $b;
            $warmMask = ($lum < 95.0) ? 1.0 : smoothstep(-4.0, 18.0, $warmth);
            $mask = $wallMask * $warmMask;
            if ($mask <= 0.002) continue;

            $nr = (float)$r;
            $ng = (float)$g;
            $nb = (float)$b;

            if ($hasFinish) {
                $fMix = 0.42 * $mask;
                $nr = $nr * (1.0 + ($finishGain[0] - 1.0) * $fMix);
                $ng = $ng * (1.0 + ($finishGain[1] - 1.0) * $fMix);
                $nb = $nb * (1.0 + ($finishGain[2] - 1.0) * $fMix);
            }

            if ($strength > 0.01) {
                $s = $strength * $mask;
                $nr = $nr * (1.0 - $s) + ($nr * $p['r']) * $s;
                $ng = $ng * (1.0 - $s) + ($ng * $p['g']) * $s;
                $nb = $nb * (1.0 - $s) + ($nb * $p['b']) * $s;

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
 * Adds a subtle, natural studio contact shadow directly under the bottom of the door.
 */
function drawStudioFloorShadow($canvas, int $leftX, int $rightX, int $bottomY): void {
    $cw = imagesx($canvas);
    $ch = imagesy($canvas);
    $shadowH = min(14, max(4, $ch - $bottomY - 4));
    if ($shadowH < 4) return;

    $cx = ($leftX + $rightX) / 2.0;
    $halfW = max(20.0, ($rightX - $leftX) / 2.0 + 12.0);
    $x0 = max(0, (int)floor($cx - $halfW));
    $x1 = min($cw - 1, (int)ceil($cx + $halfW));

    for ($dy = 0; $dy < $shadowH; $dy++) {
        $y = $bottomY + $dy;
        if ($y < 0 || $y >= $ch) continue;
        $vy = 1.0 - ($dy / (float)$shadowH);
        $vy = $vy * $vy;
        for ($x = $x0; $x <= $x1; $x++) {
            $nx = abs($x - $cx) / $halfW;
            if ($nx >= 1.0) continue;
            $vx = 1.0 - ($nx * $nx);
            $alpha = 0.16 * $vy * $vx;
            $rgb = imagecolorat($canvas, $x, $y);
            $r = clampByte((($rgb >> 16) & 255) * (1.0 - $alpha));
            $g = clampByte((($rgb >> 8) & 255) * (1.0 - $alpha));
            $b = clampByte(($rgb & 255) * (1.0 - $alpha));
            imagesetpixel($canvas, $x, $y, ($r << 16) | ($g << 8) | $b);
        }
    }
}

/**
 * Enhances fine wood carving clarity, grain crispness, and brass highlight definition
 * using an edge-masked studio unsharp filter (zero haloing on the white studio backdrop!).
 */
function applyHdWoodClarity($canvas, array $bounds, array $canvasBg): void {
    if (!function_exists('imageconvolution')) return;

    $cw = imagesx($canvas);
    $ch = imagesy($canvas);
    $x0 = max(0, (int)$bounds['x'] - 4);
    $y0 = max(0, (int)$bounds['y'] - 4);
    $x1 = min($cw - 1, (int)$bounds['x'] + (int)$bounds['w'] + 4);
    $y1 = min($ch - 1, (int)$bounds['y'] + (int)$bounds['h'] + 4);
    $rw = $x1 - $x0 + 1;
    $rh = $y1 - $y0 + 1;
    if ($rw < 20 || $rh < 20) return;

    $sharp = imagecreatetruecolor($rw, $rh);
    imagecopy($sharp, $canvas, 0, 0, $x0, $y0, $rw, $rh);

    // Native C-level studio unsharp convolution kernel (preserves brightness, crisp carving relief)
    $kernel = [
        [ 0.0,  -0.55,  0.0],
        [-0.55,  3.20, -0.55],
        [ 0.0,  -0.55,  0.0],
    ];
    @imageconvolution($sharp, $kernel, 1.0, 0.0);

    // Blend sharpened wood detail strictly inside wooden regions so outer white borders stay halo-free
    for ($py = 0; $py < $rh; $py++) {
        $cy = $y0 + $py;
        for ($px = 0; $px < $rw; $px++) {
            $cx = $x0 + $px;
            $oRgb = imagecolorat($canvas, $cx, $cy);
            $or = ($oRgb >> 16) & 255;
            $og = ($oRgb >> 8) & 255;
            $ob = $oRgb & 255;

            $dist = colorDist($or, $og, $ob, $canvasBg);
            if ($dist <= 34.0) continue;

            // Smoothly ramp sharpening strength inside the door interior (zero halo on white border!)
            $mask = smoothstep(34.0, 82.0, $dist) * 0.72;
            if ($mask <= 0.01) continue;

            $sRgb = imagecolorat($sharp, $px, $py);
            $sr = ($sRgb >> 16) & 255;
            $sg = ($sRgb >> 8) & 255;
            $sb = $sRgb & 255;

            // Blend sharpened pixels + gentle studio clarity micro-contrast (+5%)
            $nr = $or * (1.0 - $mask) + $sr * $mask;
            $ng = $og * (1.0 - $mask) + $sg * $mask;
            $nb = $ob * (1.0 - $mask) + $sb * $mask;

            $c = 1.0 + 0.055 * $mask;
            $nr = clampByte((($nr - 115.0) * $c) + 115.0);
            $ng = clampByte((($ng - 90.0) * $c) + 90.0);
            $nb = clampByte((($nb - 65.0) * $c) + 65.0);

            imagesetpixel($canvas, $cx, $cy, ($nr << 16) | ($ng << 8) | $nb);
        }
    }

    imagedestroy($sharp);
}

/**
 * Optional Real Generative AI call via Google Gemini API (when GEMINI_API_KEY is set in config.php).
 * Explicitly mandates full-length uncropped framing with clean margins on all four sides.
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
        'text' => "Create a single ultra-sharp, crystal-clear straight-on architectural studio photograph (vertical 3:4 portrait) of ONE unified custom handcrafted Indian wooden door combining the reference images exactly as instructed: $promptText "
            . "STRICT FRAMING & CLARITY RULES: Show 100% of the ENTIRE door and full frame from the very top tip of the crown/arch down to the bottom floor threshold, centered with generous clean white/warm-cream studio margin on ALL FOUR SIDES (top, bottom, left, right). NEVER crop, cut off, or zoom into any part of the door, pillars, crown, or carvings. Crisp natural daylight, sharp fine wood carving details, zero text, zero logos, zero watermarks.",
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
 * High-clarity, zero-crop photorealistic door combiner & renderer for cPanel PHP + GD:
 *  1) Uses Gemini multimodal image AI if GEMINI_API_KEY is configured.
 *  2) Otherwise extracts the COMPLETE uncropped door/frame objects from the selected
 *     catalog photos (removing header logos, NEVER cover-cropping), places the outer
 *     frame structure on a crisp high-res 720x960 studio canvas with generous margins
 *     on all 4 sides, cleanly mounts Top Arch & Crown, nests Panel Layout / Center Carving
 *     inside the doorway with wood-tone matching & subtle recessed jamb shadow, and
 *     applies speckle-free polish grading.
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

    // 2. Zero-Crop Full-HD Clarity PHP GD Real-Photo Compositor
    $canvasW = 960;
    $canvasH = 1280;
    $canvasBg = [255.0, 255.0, 255.0];

    if (!empty($refDesigns) && function_exists('imagecreatetruecolor') && function_exists('imagecreatefromstring')) {
        $objs = [];
        foreach ($refDesigns as $d) {
            $did = (int)($d['id'] ?? 0);
            $rel = (string)($d['image_url'] ?? '');
            if ($rel !== '') {
                $abs = $uploadsRoot . DIRECTORY_SEPARATOR . ltrim(str_replace('/', DIRECTORY_SEPARATOR, $rel), '/\\');
                $extracted = extractDoorObject($abs, $d);
                if ($extracted !== null) {
                    $objs[$did] = $extracted;
                }
            }
        }

        if (!empty($objs)) {
            $ids = array_keys($objs);
            $elementMap = [];
            foreach ($refElements as $el) {
                $did = (int)($el['design_id'] ?? 0);
                $elName = strtolower(trim((string)($el['element'] ?? '')));
                if (isset($objs[$did]) && $elName !== '') {
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

            // Architectural base selection:
            // Frame Style is ALWAYS the outer structure; otherwise prefer a framed design,
            // then Panel Layout / Center Carving / Crown / first selected design.
            $baseId = $frameId;
            if ($baseId === null && $panelId !== null && $objs[$panelId]['is_framed']) {
                $baseId = $panelId;
            }
            if ($baseId === null && $crownId !== null && $objs[$crownId]['is_framed']) {
                $baseId = $crownId;
            }
            if ($baseId === null && $centerId !== null && $objs[$centerId]['is_framed']) {
                $baseId = $centerId;
            }
            if ($baseId === null) {
                $baseId = $panelId ?? $centerId ?? $crownId ?? $ids[0];
            }

            $base = $objs[$baseId];

            // Determine whether a separate Top Arch & Crown will be mounted atop the base
            $hasSeparateCrown = ($crownId !== null && $crownId !== $baseId && isset($objs[$crownId]));
            $crownAddsTopHeight = $hasSeparateCrown && !$base['is_framed'];

            // Crisp, balanced margins so the HD door fills almost the entire frame with ZERO clipping
            $padX = 36;
            $padBottom = 38;
            $padTop = $crownAddsTopHeight ? 230 : 38;

            $availW = $canvasW - $padX * 2;
            $availH = $canvasH - $padTop - $padBottom;

            // Uniform contain-fit scale (NEVER stretches, NEVER cover-crops!)
            $scale = min($availW / max(1.0, (float)$base['w']), $availH / max(1.0, (float)$base['h']));
            $dstBaseW = max(40, (int)round($base['w'] * $scale));
            $dstBaseH = max(40, (int)round($base['h'] * $scale));
            $dstBaseX = (int)round(($canvasW - $dstBaseW) / 2.0);
            // Sit nicely anchored near bottom margin when adding an overhead crown, else centered vertically
            $dstBaseY = $crownAddsTopHeight
                ? ($canvasH - $padBottom - $dstBaseH)
                : ($padTop + (int)round(($availH - $dstBaseH) / 2.0));

            // Create pure crisp white studio canvas
            $canvas = imagecreatetruecolor($canvasW, $canvasH);
            $bgCol = imagecolorallocate($canvas, (int)$canvasBg[0], (int)$canvasBg[1], (int)$canvasBg[2]);
            imagefilledrectangle($canvas, 0, 0, $canvasW, $canvasH, $bgCol);

            // Place the full, uncropped base door cleanly onto the studio canvas
            blitCleanObjectToCanvas($canvas, $base, $dstBaseX, $dstBaseY, $dstBaseW, $dstBaseH, $canvasBg);

            // Map base's coordinates onto canvas coordinates
            $mapRect = function (array $r) use ($dstBaseX, $dstBaseY, $scale): array {
                return [
                    'x' => $dstBaseX + (int)round($r['x'] * $scale),
                    'y' => $dstBaseY + (int)round($r['y'] * $scale),
                    'w' => max(20, (int)round($r['w'] * $scale)),
                    'h' => max(20, (int)round($r['h'] * $scale)),
                ];
            };

            $baseOuter = ['x' => $dstBaseX, 'y' => $dstBaseY, 'w' => $dstBaseW, 'h' => $dstBaseH];
            $baseInner = $mapRect($base['inner']);
            $baseLintelY = $dstBaseY + (int)round($base['crown_bottom_y'] * $scale);
            $baseMidLeftX = $dstBaseX + (int)round($base['mid_left'] * $scale);
            $baseMidRightX = $dstBaseX + (int)round($base['mid_right'] * $scale);
            $baseMidW = max(60, $baseMidRightX - $baseMidLeftX);

            // Sample target wood tone from the base door
            $baseWoodRgb = sampleAverageWoodColor(
                $canvas,
                $baseOuter['x'],
                $baseOuter['y'],
                $baseOuter['w'],
                $baseOuter['h'],
                $canvasBg
            );

            // Helper: choose source carving/shutter rect cleanly (NEVER slices single-leaf carvings in half!)
            $getCleanShutterRect = function (int $srcId) use ($objs, $base): array {
                $src = $objs[$srcId];
                // If both base and source are pure shutters (no pillars), nest source's inner carved panel
                // inside base's outer stiles/rails so borders don't double up!
                if (!$base['is_framed'] && !$src['is_framed']) {
                    return $src['inner'];
                }
                // Otherwise use the COMPLETE intact shutter leaf (96% of pure shutter, or inner leaf of framed door)
                return $src['leaf'];
            };

            // A) Panel Layout — fits cleanly inside the base doorway opening
            if ($panelId !== null && $panelId !== $baseId && isset($objs[$panelId]) && !$base['is_landscape']) {
                $srcObj = $objs[$panelId];
                $srcPanel = $getCleanShutterRect($panelId);
                compositeRegionClean(
                    $canvas,
                    $srcObj['img'],
                    $srcPanel,
                    $baseInner,
                    $baseWoodRgb,
                    7,
                    true,
                    false,
                    $srcObj['has_clean_bg'],
                    $srcObj['bg'],
                    false
                );
            }

            // B) Center Carving — fills doorway opening cleanly (or soft-blends into center if Panel Layout also set)
            if ($centerId !== null && $centerId !== $baseId && isset($objs[$centerId]) && !$base['is_landscape']) {
                $srcObj = $objs[$centerId];
                if ($panelId === null || $panelId === $baseId || $panelId === $centerId) {
                    $srcInner = $getCleanShutterRect($centerId);
                    compositeRegionClean(
                        $canvas,
                        $srcObj['img'],
                        $srcInner,
                        $baseInner,
                        $baseWoodRgb,
                        7,
                        true,
                        false,
                        $srcObj['has_clean_bg'],
                        $srcObj['bg'],
                        false
                    );
                } else {
                    // Both Panel Layout & Center Carving from two different designs:
                    // Blend center carving cleanly into the heart of the door leaf with soft rounded mask
                    $cLeaf = $srcObj['leaf'];
                    $srcMid = [
                        'x' => $cLeaf['x'] + (int)round($cLeaf['w'] * 0.08),
                        'y' => $cLeaf['y'] + (int)round($cLeaf['h'] * 0.10),
                        'w' => max(40, (int)round($cLeaf['w'] * 0.84)),
                        'h' => max(60, (int)round($cLeaf['h'] * 0.80)),
                    ];
                    $dstMid = [
                        'x' => $baseInner['x'] + (int)round($baseInner['w'] * 0.10),
                        'y' => $baseInner['y'] + (int)round($baseInner['h'] * 0.10),
                        'w' => max(40, (int)round($baseInner['w'] * 0.80)),
                        'h' => max(60, (int)round($baseInner['h'] * 0.80)),
                    ];
                    compositeRegionClean(
                        $canvas,
                        $srcObj['img'],
                        $srcMid,
                        $dstMid,
                        $baseWoodRgb,
                        18,
                        false,
                        false,
                        $srcObj['has_clean_bg'],
                        $srcObj['bg'],
                        true
                    );
                }
            }

            // C) Top Arch & Crown — cleanly replaces old crown or mounts flush atop unframed door, NEVER cut off!
            $finalTopY = $baseOuter['y'];
            $finalLeftX = $baseOuter['x'];
            $finalRightX = $baseOuter['x'] + $baseOuter['w'];

            if ($hasSeparateCrown && !$base['is_landscape']) {
                $cObj = $objs[$crownId];
                $srcCrownH = max(50, (int)round($cObj['crown_bottom_y'] * 1.04));
                $srcCrownH = min($cObj['h'], $srcCrownH);
                $srcCrown = [
                    'x' => 0,
                    'y' => 0,
                    'w' => $cObj['w'],
                    'h' => $srcCrownH,
                ];

                // Crown target width matches base's pillars/door width with subtle royal overhang (clamped safely inside canvas)
                $crownOverhang = $cObj['has_flared_crown'] ? 1.06 : 1.03;
                $targetCrownW = min($canvasW - 44, (int)round($baseMidW * $crownOverhang));
                $crownNaturalH = (int)round($targetCrownW * ($srcCrownH / max(1.0, (float)$cObj['w'])));

                if ($base['is_framed']) {
                    // Erase the base's existing crown cleanly above the lintel line so no old cornice peeks out
                    imagefilledrectangle($canvas, 0, 0, $canvasW - 1, max(0, $baseLintelY - 2), $bgCol);

                    // Fit crown height cleanly within [24 .. baseLintelY + overlap] so the crown tip is NEVER clipped!
                    $overlap = 10;
                    $maxCrownH = max(60, ($baseLintelY + $overlap) - 24);
                    $targetCrownH = min($maxCrownH, max(72, $crownNaturalH));
                    if ($crownNaturalH > $maxCrownH) {
                        // Scale width slightly to preserve crown proportions without squashing or clipping
                        $ratio = $maxCrownH / (float)$crownNaturalH;
                        $targetCrownW = max((int)round($baseMidW * 0.98), (int)round($targetCrownW * max(0.85, $ratio)));
                    }
                    $dstCrownX = (int)round(($baseMidLeftX + $baseMidRightX - $targetCrownW) / 2.0);
                    $dstCrownX = max(20, min($canvasW - 20 - $targetCrownW, $dstCrownX));
                    $dstCrownY = max(20, ($baseLintelY + $overlap) - $targetCrownH);
                } else {
                    // Mounting a crown directly on top of a pure door shutter
                    $overlap = 10;
                    $maxCrownH = max(60, ($dstBaseY + $overlap) - 24);
                    $targetCrownH = min($maxCrownH, max(72, $crownNaturalH));
                    $dstCrownX = (int)round(($dstBaseX + ($dstBaseW / 2.0)) - ($targetCrownW / 2.0));
                    $dstCrownX = max(20, min($canvasW - 20 - $targetCrownW, $dstCrownX));
                    $dstCrownY = max(20, ($dstBaseY + $overlap) - $targetCrownH);
                }

                $dstCrown = [
                    'x' => $dstCrownX,
                    'y' => $dstCrownY,
                    'w' => $targetCrownW,
                    'h' => $targetCrownH,
                ];

                compositeRegionClean(
                    $canvas,
                    $cObj['img'],
                    $srcCrown,
                    $dstCrown,
                    $baseWoodRgb,
                    12,
                    false,
                    true,
                    $cObj['has_clean_bg'],
                    $cObj['bg'],
                    false
                );

                $finalTopY = min($finalTopY, $dstCrownY);
                $finalLeftX = min($finalLeftX, $dstCrownX);
                $finalRightX = max($finalRightX, $dstCrownX + $targetCrownW);
            }

            // D) Sample Border/Polish Finish wood color if assigned to a separate design
            $finishWoodRgb = null;
            if ($finishId !== null && isset($objs[$finishId])) {
                $fObj = $objs[$finishId];
                $finishWoodRgb = sampleAverageWoodColor(
                    $fObj['img'],
                    0,
                    0,
                    $fObj['w'],
                    $fObj['h'],
                    $fObj['has_clean_bg'] ? $fObj['bg'] : null
                );
            }

            // E) Apply smooth speckle-free polish grading ONLY to wooden pixels
            $gradeBounds = [
                'x' => $finalLeftX,
                'y' => $finalTopY,
                'w' => max(40, $finalRightX - $finalLeftX),
                'h' => max(40, ($baseOuter['y'] + $baseOuter['h']) - $finalTopY),
            ];
            applyPolishShadeGrading($canvas, $polishShade, $gradeBounds, $canvasBg, $finishWoodRgb);

            // F) Apply HD wood-grain sharpening & studio micro-clarity (halo-free!)
            applyHdWoodClarity($canvas, $gradeBounds, $canvasBg);

            // G) Subtle studio floor contact shadow directly under the door base
            drawStudioFloorShadow($canvas, $baseMidLeftX, $baseMidRightX, $baseOuter['y'] + $baseOuter['h']);

            // H) Tight studio crop around the rendered door (+ crisp 26px breathing margin)
            //    so zero wasted whitespace shrinks the preview on screen!
            $outMarginX = 28;
            $outMarginTop = 26;
            $outMarginBot = 32;
            $trimX0 = max(0, $finalLeftX - $outMarginX);
            $trimY0 = max(0, $finalTopY - $outMarginTop);
            $trimX1 = min($canvasW - 1, $finalRightX + $outMarginX);
            $trimY1 = min($canvasH - 1, $baseOuter['y'] + $baseOuter['h'] + $outMarginBot);
            $trimW = max(120, $trimX1 - $trimX0 + 1);
            $trimH = max(160, $trimY1 - $trimY0 + 1);

            $finalImg = imagecreatetruecolor($trimW, $trimH);
            imagecopy($finalImg, $canvas, 0, 0, $trimX0, $trimY0, $trimW, $trimH);
            imagedestroy($canvas);

            imagepng($finalImg, $fullPath, 5);
            imagedestroy($finalImg);
            foreach ($objs as $o) {
                imagedestroy($o['img']);
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
        $bg = imagecolorallocate($im, 250, 248, 244);
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
