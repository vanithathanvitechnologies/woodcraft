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
 * Detects metallic gold / antique brass pixels (deity plaques, bells, handles, peacock inlays)
 * returning a smooth protection weight 0.0..1.0 so wood-tone unification preserves bright brass!
 */
function brassProtectionWeight(int $r, int $g, int $b): float {
    $lum = 0.299 * $r + 0.587 * $g + 0.114 * $b;
    if ($lum < 118.0 || $r < 142 || $g < 108) return 0.0;
    $rb = $r - $b;
    if ($rb < 52) return 0.0;
    $gbRatio = ($g - $b) / max(1.0, (float)$rb);
    // Brass/gold is distinctly yellower (higher G relative to R-B span) & brighter than reddish-brown teak
    if ($gbRatio < 0.50) return 0.0;
    $wHue = smoothstep(0.50, 0.68, $gbRatio);
    $wLum = smoothstep(118.0, 158.0, $lum);
    $wSat = smoothstep(52.0, 92.0, (float)$rb);
    return $wHue * $wLum * $wSat;
}

/**
 * Converts RGB (0..255) to perceptual YCbCr for smooth wood-tone statistical color transfer.
 */
function rgbToYCbCr(float $r, float $g, float $b): array {
    $y  =  0.2990 * $r + 0.5870 * $g + 0.1140 * $b;
    $cb = -0.168736 * $r - 0.331264 * $g + 0.5000 * $b + 128.0;
    $cr =  0.5000 * $r - 0.418688 * $g - 0.081312 * $b + 128.0;
    return [$y, $cb, $cr];
}

/**
 * Converts YCbCr back to clamped RGB (0..255).
 */
function yCbCrToRgb(float $y, float $cb, float $cr): array {
    $c = $cb - 128.0;
    $d = $cr - 128.0;
    $r = $y + 1.4020 * $d;
    $g = $y - 0.344136 * $c - 0.714136 * $d;
    $b = $y + 1.7720 * $c;
    return [clampByte($r), clampByte($g), clampByte($b)];
}

/**
 * Computes statistical mean & std of YCbCr + mean RGB strictly on wood pixels
 * (ignoring studio background and metallic brass inlays) for seamless color transfer.
 */
function sampleWoodColorStats($im, int $x0, int $y0, int $rw, int $rh, ?array $wallRef = null): array {
    $w = imagesx($im);
    $h = imagesy($im);
    $ys = []; $cbs = []; $crs = [];
    $sumR = 0.0; $sumG = 0.0; $sumB = 0.0;

    $x1 = min($w - 1, $x0 + $rw);
    $y1 = min($h - 1, $y0 + $rh);
    $step = max(2, (int)floor(min($rw, $rh) / 85));

    for ($y = max(0, $y0); $y < $y1; $y += $step) {
        for ($x = max(0, $x0); $x < $x1; $x += $step) {
            $rgb = imagecolorat($im, $x, $y);
            $r = ($rgb >> 16) & 255;
            $g = ($rgb >> 8) & 255;
            $b = $rgb & 255;
            if (!isWoodPixel($r, $g, $b, $wallRef)) continue;
            if (brassProtectionWeight($r, $g, $b) > 0.35) continue;

            [$yy, $cb, $cr] = rgbToYCbCr((float)$r, (float)$g, (float)$b);
            // Ignore extreme pitch-black crevices or specular blown highlights when estimating base wood stain
            if ($yy < 26.0 || $yy > 218.0) continue;

            $ys[] = $yy;
            $cbs[] = $cb;
            $crs[] = $cr;
            $sumR += $r; $sumG += $g; $sumB += $b;
        }
    }

    $cnt = count($ys);
    if ($cnt < 20) {
        return [
            'rgb' => [138.0, 88.0, 48.0],
            'mY' => 98.0, 'sY' => 30.0,
            'mCb' => 101.0, 'sCb' => 8.0,
            'mCr' => 152.0, 'sCr' => 10.0,
        ];
    }

    $mY = array_sum($ys) / $cnt;
    $mCb = array_sum($cbs) / $cnt;
    $mCr = array_sum($crs) / $cnt;

    $vY = 0.0; $vCb = 0.0; $vCr = 0.0;
    for ($i = 0; $i < $cnt; $i++) {
        $vY  += ($ys[$i]  - $mY)  * ($ys[$i]  - $mY);
        $vCb += ($cbs[$i] - $mCb) * ($cbs[$i] - $mCb);
        $vCr += ($crs[$i] - $mCr) * ($crs[$i] - $mCr);
    }

    return [
        'rgb' => [$sumR / $cnt, $sumG / $cnt, $sumB / $cnt],
        'mY'  => $mY,  'sY'  => max(12.0, sqrt($vY / $cnt)),
        'mCb' => $mCb, 'sCb' => max(4.0,  sqrt($vCb / $cnt)),
        'mCr' => $mCr, 'sCr' => max(4.0,  sqrt($vCr / $cnt)),
    ];
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

        // Auto-level slightly tilted showroom door/frame photos (0.6°..6.5°) so thresholds & jambs sit dead-plumb!
        if (function_exists('imagerotate') && $ow >= 80 && $oh >= 120) {
            $sampleBottomY = function (int $sx0, int $sx1) use ($obj, $ow, $oh, $bg): ?float {
                $ys = [];
                $sx0 = max(0, min($ow - 1, $sx0));
                $sx1 = max($sx0, min($ow - 1, $sx1));
                for ($x = $sx0; $x <= $sx1; $x += 3) {
                    for ($y = $oh - 1; $y >= (int)round($oh * 0.72); $y--) {
                        $rgb = imagecolorat($obj, $x, $y);
                        if (colorDist(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $bg) > 30.0) {
                            $ys[] = $y;
                            break;
                        }
                    }
                }
                if (count($ys) < 6) return null;
                sort($ys);
                return (float)$ys[(int)floor(count($ys) / 2)];
            };

            $yBotL = $sampleBottomY((int)round($ow * 0.12), (int)round($ow * 0.30));
            $yBotR = $sampleBottomY((int)round($ow * 0.70), (int)round($ow * 0.88));
            if ($yBotL !== null && $yBotR !== null) {
                $dxSpan = max(20.0, $ow * 0.58);
                // Positive dy means right side is lower than left side -> rotate CCW (+) to level
                // Negative dy means right side is higher than left side -> rotate CW (-) to level
                $deg = rad2deg(atan2($yBotR - $yBotL, $dxSpan));
                if (abs($deg) >= 0.75 && abs($deg) <= 6.2) {
                    $rotBg = imagecolorallocate($obj, clampByte($bg[0]), clampByte($bg[1]), clampByte($bg[2]));
                    $rotated = @imagerotate($obj, $deg, $rotBg);
                    if ($rotated) {
                        imagedestroy($obj);
                        $obj = $rotated;
                        $ow = imagesx($obj);
                        $oh = imagesy($obj);
                    }
                }
            }
        }

        // Re-tighten crop bounds after stripping exterior cool-wall slivers & auto-leveling
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
        // First check if this is an EMPTY / HOLLOW wooden frame (white studio backdrop visible inside the doorway)
        $isHollowFrame = false;
        $hollowInner = null;
        if ($hasCleanBg) {
            $cx = (int)round($ow * 0.50);
            $cy = (int)round($oh * 0.58);
            $bgHits = 0;
            $totSamples = 0;
            for ($sy = (int)round($oh * 0.34); $sy <= (int)round($oh * 0.78); $sy += 6) {
                for ($sx = (int)round($ow * 0.34); $sx <= (int)round($ow * 0.66); $sx += 6) {
                    $rgb = imagecolorat($obj, $sx, $sy);
                    if (colorDist(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $bg) <= 32.0) {
                        $bgHits++;
                    }
                    $totSamples++;
                }
            }
            if ($totSamples > 10 && ($bgHits / (float)$totSamples) >= 0.58) {
                $isHollowFrame = true;
                // Trace exact inner opening from the hollow center to the surrounding wooden jambs
                $ls = []; $rs = [];
                for ($sy = (int)round($oh * 0.38); $sy <= (int)round($oh * 0.78); $sy += 6) {
                    for ($x = $cx; $x >= 2; $x--) {
                        $rgb = imagecolorat($obj, $x, $sy);
                        if (colorDist(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $bg) > 36.0) {
                            $ls[] = $x; break;
                        }
                    }
                    for ($x = $cx; $x < $ow - 2; $x++) {
                        $rgb = imagecolorat($obj, $x, $sy);
                        if (colorDist(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $bg) > 36.0) {
                            $rs[] = $x; break;
                        }
                    }
                }
                $ts = []; $bs = [];
                for ($sx = (int)round($ow * 0.36); $sx <= (int)round($ow * 0.64); $sx += 6) {
                    for ($y = $cy; $y >= 2; $y--) {
                        $rgb = imagecolorat($obj, $sx, $y);
                        if (colorDist(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $bg) > 36.0) {
                            $ts[] = $y; break;
                        }
                    }
                    $foundB = $oh - 2;
                    for ($y = $cy; $y < $oh - 2; $y++) {
                        $rgb = imagecolorat($obj, $sx, $y);
                        if (colorDist(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $bg) > 36.0) {
                            $foundB = $y; break;
                        }
                    }
                    $bs[] = $foundB;
                }
                if (count($ls) >= 4 && count($rs) >= 4 && count($ts) >= 4 && count($bs) >= 4) {
                    sort($ls); sort($rs); sort($ts); sort($bs);
                    $hL = max(4, $ls[(int)floor(count($ls) / 2)] - 2);
                    $hR = min($ow - 5, $rs[(int)floor(count($rs) / 2)] + 2);
                    $hT = max(8, $ts[(int)floor(count($ts) / 2)] - 2);
                    $hB = min($oh - 2, $bs[(int)floor(count($bs) / 2)] + 2);
                    if (($hR - $hL) >= (int)($ow * 0.35) && ($hB - $hT) >= (int)($oh * 0.45)) {
                        $hollowInner = ['x' => $hL, 'y' => $hT, 'w' => $hR - $hL, 'h' => $hB - $hT];
                    }
                }
            }
        }

        if ($hollowInner !== null) {
            $innerL = $hollowInner['x'];
            $innerR = $hollowInner['x'] + $hollowInner['w'];
            $bestLintelY = $hollowInner['y'];
            $innerB = $hollowInner['y'] + $hollowInner['h'];
        } else {
        // Detect symmetric pillar width using recessed vertical shadow valley + contrast inside y=36%..82%
        $yScan0 = (int)round($oh * 0.36);
        $yScan1 = (int)round($oh * 0.82);
        // Wide fluted double-door frames (aspect >= 0.74, e.g. #059) have sleeker side pillars (~11%–16%),
        // arched royal temple Nilai frames (#001, #017) have wide outer pillars (~22%–26%),
        // and rectangular carved Nilai frames (#019, wood-frame-1) have carved jambs (~17%–22%).
        if ($hasArchedCrown) {
            $priorCenter = 0.245;
            $minPct = 18;
            $maxPct = 28;
        } elseif ($aspect >= 0.74) {
            $priorCenter = 0.135;
            $minPct = 9;
            $maxPct = 19;
        } else {
            $priorCenter = 0.195;
            $minPct = 14;
            $maxPct = 23;
        }
        $bestPillarFrac = $priorCenter;
        $bestScore = -1e9;

        for ($pct = $minPct; $pct <= $maxPct; $pct++) {
            $frac = $pct / 100.0;
            $xl = $midLeft + (int)round($midOuterW * $frac);
            $xr = $midRight - (int)round($midOuterW * $frac);
            if ($xl < 4 || $xr > $ow - 5 || $xr - $xl < (int)($midOuterW * 0.36)) continue;

            $darkSum = 0.0;
            $edgeSum = 0.0;
            $valleySum = 0.0;
            $n = 0;
            for ($y = $yScan0; $y <= $yScan1; $y += 4) {
                $rgbL = imagecolorat($obj, $xl, $y);
                $lumL = 0.299 * (($rgbL >> 16) & 255) + 0.587 * (($rgbL >> 8) & 255) + 0.114 * ($rgbL & 255);
                $rgbL1 = imagecolorat($obj, max(0, $xl - 5), $y);
                $lumL1 = 0.299 * (($rgbL1 >> 16) & 255) + 0.587 * (($rgbL1 >> 8) & 255) + 0.114 * ($rgbL1 & 255);
                $rgbL2 = imagecolorat($obj, min($ow - 1, $xl + 5), $y);
                $lumL2 = 0.299 * (($rgbL2 >> 16) & 255) + 0.587 * (($rgbL2 >> 8) & 255) + 0.114 * ($rgbL2 & 255);

                $rgbR = imagecolorat($obj, $xr, $y);
                $lumR = 0.299 * (($rgbR >> 16) & 255) + 0.587 * (($rgbR >> 8) & 255) + 0.114 * ($rgbR & 255);
                $rgbR1 = imagecolorat($obj, max(0, $xr - 5), $y);
                $lumR1 = 0.299 * (($rgbR1 >> 16) & 255) + 0.587 * (($rgbR1 >> 8) & 255) + 0.114 * ($rgbR1 & 255);
                $rgbR2 = imagecolorat($obj, min($ow - 1, $xr + 5), $y);
                $lumR2 = 0.299 * (($rgbR2 >> 16) & 255) + 0.587 * (($rgbR2 >> 8) & 255) + 0.114 * ($rgbR2 & 255);

                // Recessed jamb shadow valley is darker than BOTH the pillar outside and shutter inside
                $vL = max(0.0, (($lumL1 + $lumL2) * 0.5) - $lumL);
                $vR = max(0.0, (($lumR1 + $lumR2) * 0.5) - $lumR);
                $darkSum += (255.0 - $lumL) + (255.0 - $lumR);
                $edgeSum += abs($lumL2 - $lumL1) + abs($lumR1 - $lumR2);
                $valleySum += $vL + $vR;
                $n++;
            }
            if ($n > 0) {
                $prior = 1.0 - abs($frac - $priorCenter) * 1.6;
                $score = (($darkSum / $n) * 0.35 + ($edgeSum / $n) * 0.85 + ($valleySum / $n) * 1.45) * max(0.60, $prior);
                if ($score > $bestScore) {
                    $bestScore = $score;
                    $bestPillarFrac = $frac;
                }
            }
        }

        $innerL = $midLeft + (int)round($midOuterW * $bestPillarFrac);
        $innerR = $midRight - (int)round($midOuterW * $bestPillarFrac);

        // Detect horizontal recessed lintel shadow VALLEY strictly below the top carved header/frieze
        // (prevents inner door from ever overlapping the top horizontal carved beam!)
        $lintelMinY = (int)round($oh * ($hasArchedCrown ? 0.21 : ($aspect >= 0.74 ? 0.12 : 0.165)));
        $lintelMaxY = (int)round($oh * ($hasArchedCrown ? 0.38 : 0.31));
        $bestLintelY = (int)round($oh * ($hasArchedCrown ? 0.26 : 0.19));
        $bestLintelScore = -1e9;

        for ($y = $lintelMinY; $y <= $lintelMaxY; $y += 2) {
            $darkSum = 0.0;
            $edgeSum = 0.0;
            $valleySum = 0.0;
            $n = 0;
            for ($x = $innerL + 8; $x <= $innerR - 8; $x += 4) {
                $rgb = imagecolorat($obj, $x, $y);
                $lum = 0.299 * (($rgb >> 16) & 255) + 0.587 * (($rgb >> 8) & 255) + 0.114 * ($rgb & 255);
                $rgbUp = imagecolorat($obj, $x, max(0, $y - 6));
                $lumUp = 0.299 * (($rgbUp >> 16) & 255) + 0.587 * (($rgbUp >> 8) & 255) + 0.114 * ($rgbUp & 255);
                $rgbDn = imagecolorat($obj, $x, min($oh - 1, $y + 8));
                $lumDn = 0.299 * (($rgbDn >> 16) & 255) + 0.587 * (($rgbDn >> 8) & 255) + 0.114 * ($rgbDn & 255);
                $valley = max(0.0, (($lumUp + $lumDn) * 0.5) - $lum);
                $darkSum += (255.0 - $lum);
                $edgeSum += abs($lumDn - $lumUp);
                $valleySum += $valley;
                $n++;
            }
            if ($n > 0) {
                $score = ($darkSum / $n) * 0.42 + ($edgeSum / $n) * 0.85 + ($valleySum / $n) * 1.55;
                if ($score > $bestLintelScore) {
                    $bestLintelScore = $score;
                    $bestLintelY = $y;
                }
            }
        }

        // Detect bottom threshold step if present (strictly 91%..98.5% so we NEVER stop early at an inner panel rail!)
        $innerB = (int)round($oh * 0.955);
        $bestBotScore = -1e9;
        for ($y = (int)round($oh * 0.915); $y <= (int)round($oh * 0.985); $y += 2) {
            $darkSum = 0.0;
            $edgeSum = 0.0;
            $valleySum = 0.0;
            $n = 0;
            for ($x = $innerL + 8; $x <= $innerR - 8; $x += 4) {
                $rgb = imagecolorat($obj, $x, $y);
                $lum = 0.299 * (($rgb >> 16) & 255) + 0.587 * (($rgb >> 8) & 255) + 0.114 * ($rgb & 255);
                $rgbUp = imagecolorat($obj, $x, max(0, $y - 6));
                $lumUp = 0.299 * (($rgbUp >> 16) & 255) + 0.587 * (($rgbUp >> 8) & 255) + 0.114 * ($rgbUp & 255);
                $rgbDn = imagecolorat($obj, $x, min($oh - 1, $y + 6));
                $lumDn = 0.299 * (($rgbDn >> 16) & 255) + 0.587 * (($rgbDn >> 8) & 255) + 0.114 * ($rgbDn & 255);
                $valley = max(0.0, (($lumUp + $lumDn) * 0.5) - $lum);
                $darkSum += (255.0 - $lum);
                $edgeSum += abs($lumDn - $lumUp);
                $valleySum += $valley;
                $n++;
            }
            if ($n > 0) {
                $score = ($darkSum / $n) * 0.40 + ($edgeSum / $n) * 0.85 + ($valleySum / $n) * 1.40;
                if ($score > $bestBotScore) {
                    $bestBotScore = $score;
                    $innerB = $y;
                }
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
 * Composites a door shutter, center carving, or crown seamlessly onto the canvas
 * using perceptual YCbCr statistical wood-tone & lighting unification (while preserving
 * authentic metallic gold/brass inlays), crisp rabbet bevel reveal, realistic directional
 * ambient-occlusion jamb shadows, and transparent outer background cutout for arches.
 */
function compositeRegionClean(
    $dstImg,
    $srcImg,
    array $srcRect,
    array $dstRect,
    array $targetWoodStats,
    int $feather = 6,
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

    $srcStats = sampleWoodColorStats($patch, 0, 0, $dw, $dh, $srcHasCleanBg ? $srcBg : null);
    // Support legacy 3-element RGB array fallback if passed
    if (!isset($targetWoodStats['mY'])) {
        [$tY, $tCb, $tCr] = rgbToYCbCr((float)$targetWoodStats[0], (float)$targetWoodStats[1], (float)$targetWoodStats[2]);
        $targetWoodStats = [
            'rgb' => $targetWoodStats,
            'mY' => $tY, 'sY' => $srcStats['sY'],
            'mCb' => $tCb, 'sCb' => $srcStats['sCb'],
            'mCr' => $tCr, 'sCr' => $srcStats['sCr'],
        ];
    }

    $scaleY  = max(0.80, min(1.24, $targetWoodStats['sY']  / max(10.0, $srcStats['sY'])));
    $scaleCb = max(0.70, min(1.25, $targetWoodStats['sCb'] / max(4.0,  $srcStats['sCb'])));
    $scaleCr = max(0.70, min(1.25, $targetWoodStats['sCr'] / max(4.0,  $srcStats['sCr'])));

    // Strong chroma unification (90%) + cohesive luminance matching (80%) makes all wood look carved from one log!
    $chromaMix = $isCrownOverlay ? 0.92 : 0.88;
    $lumaMix   = $isCrownOverlay ? 0.82 : 0.76;

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
                if ($px < 3) $alphaX = min($alphaX, smoothstep(0.0, 3.0, (float)$px));
                if ($px > $dw - 3) $alphaX = min($alphaX, smoothstep(0.0, 3.0, (float)($dw - $px)));
            }

            $alpha = $alphaX * $alphaY;

            // Optional soft rounded vignette mask
            if ($roundedMask) {
                $nx = ($px / max(1.0, (float)($dw - 1))) * 2.0 - 1.0;
                $ny = ($py / max(1.0, (float)($dh - 1))) * 2.0 - 1.0;
                $rad = pow(abs($nx), 4.0) + pow(abs($ny), 4.0);
                $alpha *= (1.0 - smoothstep(0.58, 1.02, $rad));
            }

            // Transparent cutout for curved/arched crowns over studio backdrop
            if ($isCrownOverlay && $srcHasCleanBg && $srcBg !== null) {
                $dist = colorDist($sr, $sg, $sb, $srcBg);
                $woodAmt = smoothstep(20.0, 44.0, $dist);
                $alpha *= $woodAmt;
            }

            if ($alpha <= 0.003) continue;

            // Perceptual YCbCr color & lighting transfer (preserves bright metallic gold/brass inlays)
            $brassW = brassProtectionWeight($sr, $sg, $sb);
            $woodWeight = 1.0 - $brassW * 0.88;

            [$yVal, $cbVal, $crVal] = rgbToYCbCr((float)$sr, (float)$sg, (float)$sb);
            $tY  = $targetWoodStats['mY']  + ($yVal  - $srcStats['mY'])  * $scaleY;
            $tCb = $targetWoodStats['mCb'] + ($cbVal - $srcStats['mCb']) * $scaleCb;
            $tCr = $targetWoodStats['mCr'] + ($crVal - $srcStats['mCr']) * $scaleCr;

            $effLuma = $lumaMix * $woodWeight;
            $effChroma = $chromaMix * $woodWeight;

            $fY  = $yVal  * (1.0 - $effLuma)   + $tY  * $effLuma;
            $fCb = $cbVal * (1.0 - $effChroma) + $tCb * $effChroma;
            $fCr = $crVal * (1.0 - $effChroma) + $tCr * $effChroma;

            [$nr, $ng, $nb] = yCbCrToRgb($fY, $fCb, $fCr);

            // Authentic architectural door-in-frame depth (NO harsh black wireframe outline!):
            //  - Smooth directional cast shadow from overhanging top lintel (18px) and side pillars (12px)
            //  - Subtle contact shadow along the bottom threshold (7px)
            if ($addRecessShadow) {
                $shadow = 1.0;
                if ($py < 18) {
                    $t = $py / 18.0;
                    $shadow = min($shadow, 0.62 + 0.38 * (1.0 - pow(1.0 - $t, 2.0)));
                }
                if ($px < 12) {
                    $t = $px / 12.0;
                    $shadow = min($shadow, 0.70 + 0.30 * (1.0 - pow(1.0 - $t, 1.9)));
                }
                if ($px > $dw - 12) {
                    $t = ($dw - 1 - $px) / 12.0;
                    $shadow = min($shadow, 0.70 + 0.30 * (1.0 - pow(1.0 - $t, 1.9)));
                }
                if ($py > $dh - 8) {
                    $t = ($dh - 1 - $py) / 8.0;
                    $shadow = min($shadow, 0.80 + 0.20 * $t);
                }
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
 * Draws a subtle realistic downward cast shadow directly beneath a seated crown/cornice
 * onto the top of the frame pillars and lintel so the crown looks physically mounted.
 */
function drawCrownSeatShadow($canvas, int $x0, int $x1, int $seatY, array $canvasBg, int $depth = 14): void {
    $cw = imagesx($canvas);
    $ch = imagesy($canvas);
    $x0 = max(0, $x0);
    $x1 = min($cw - 1, $x1);
    for ($dy = 0; $dy < $depth; $dy++) {
        $y = $seatY + $dy;
        if ($y < 0 || $y >= $ch) continue;
        $t = $dy / max(1.0, (float)$depth);
        $darken = 0.34 * pow(1.0 - $t, 1.8);
        for ($x = $x0; $x <= $x1; $x++) {
            $rgb = imagecolorat($canvas, $x, $y);
            $r = ($rgb >> 16) & 255;
            $g = ($rgb >> 8) & 255;
            $b = $rgb & 255;
            if (colorDist($r, $g, $b, $canvasBg) <= 28.0) continue;
            $f = 1.0 - $darken;
            imagesetpixel($canvas, $x, $y, (clampByte($r * $f) << 16) | (clampByte($g * $f) << 8) | clampByte($b * $f));
        }
    }
}

/**
 * Draws a crisp architectural 3D stepped wooden cornice cap along the top and bottom
 * of a flat/rectangular frieze header so even an unframed top band looks like a genuine
 * custom-carpentered Indian wooden temple entablature instead of a pasted square cutout.
 */
function drawArchitecturalCorniceMolding($canvas, int $x0, int $y0, int $w, int $h, array $woodRgb): void {
    $cw = imagesx($canvas);
    $ch = imagesy($canvas);

    $drawBar = function (int $bx0, int $by0, int $bw, int $bh, float $shadeBase) use ($canvas, $woodRgb, $cw, $ch): void {
        $bx1 = min($cw - 1, $bx0 + $bw - 1);
        $by1 = min($ch - 1, $by0 + $bh - 1);
        $bx0 = max(0, $bx0);
        $by0 = max(0, $by0);
        $rh = max(1, $by1 - $by0 + 1);
        for ($y = $by0; $y <= $by1; $y++) {
            $u = ($y - $by0) / (float)$rh;
            $bevel = 0.82 + 0.28 * sin($u * M_PI);
            if ($y === $by0) $bevel = 1.15;
            elseif ($y === $by1) $bevel = 0.52;
            for ($x = $bx0; $x <= $bx1; $x++) {
                $grain = sin($y * 0.55 + sin($x * 0.025) * 2.0) * 5.5;
                $r = clampByte($woodRgb[0] * $shadeBase * $bevel + $grain);
                $g = clampByte($woodRgb[1] * $shadeBase * $bevel + $grain * 0.82);
                $b = clampByte($woodRgb[2] * $shadeBase * $bevel + $grain * 0.65);
                imagesetpixel($canvas, $x, $y, ($r << 16) | ($g << 8) | $b);
            }
        }
    };

    // Stepped top crown cap (wider lip + middle cove + frieze border)
    $drawBar($x0 - 16, $y0 - 18, $w + 32, 10, 0.96);
    $drawBar($x0 - 10, $y0 - 8,  $w + 20, 9,  0.84);
    // Clean bottom architrave bead uniting crown seamlessly to pillar capitals
    $drawBar($x0 - 6,  $y0 + $h - 7, $w + 12, 9, 0.86);
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
 * Renders a photorealistic solid molded wooden Chowkhat / Nilai outer frame
 * around $innerRect using $woodRgb (used when an unframed shutter is assigned
 * as Frame Style alongside a different inner door leaf so zero old carvings
 * ever overlap or peek behind the new door).
 */
function drawCleanSolidWoodFrame($canvas, array $outerRect, array $innerRect, array $woodRgb): void {
    $ox1 = (int)$outerRect['x'];
    $oy1 = (int)$outerRect['y'];
    $ox2 = $ox1 + (int)$outerRect['w'] - 1;
    $oy2 = $oy1 + (int)$outerRect['h'] - 1;

    $ix1 = (int)$innerRect['x'];
    $iy1 = (int)$innerRect['y'];
    $ix2 = $ix1 + (int)$innerRect['w'] - 1;
    $iy2 = $iy1 + (int)$innerRect['h'] - 1;

    $cw = imagesx($canvas);
    $ch = imagesy($canvas);

    $fillGrainRect = function (int $x0, int $y0, int $x1, int $y1, bool $vertical) use ($canvas, $woodRgb, $cw, $ch): void {
        $x0 = max(0, $x0); $y0 = max(0, $y0);
        $x1 = min($cw - 1, $x1); $y1 = min($ch - 1, $y1);
        $w = max(1, $x1 - $x0 + 1);
        $h = max(1, $y1 - $y0 + 1);

        for ($y = $y0; $y <= $y1; $y++) {
            for ($x = $x0; $x <= $x1; $x++) {
                // Subtle natural wood grain & gentle 3D cylindrical molding shading
                $u = $vertical ? (($x - $x0) / (float)$w) : (($y - $y0) / (float)$h);
                $v = $vertical ? ($y - $y0) : ($x - $x0);
                // 3D stepped molding profile across rail width
                $profile = 0.86 + 0.22 * sin($u * M_PI);
                if ($u < 0.08 || $u > 0.92) $profile *= 0.72;
                elseif (($u > 0.24 && $u < 0.30) || ($u > 0.70 && $u < 0.76)) $profile *= 0.80;

                $gCoord = ($vertical ? $x : $y) * 0.42 + sin($v * 0.025) * 2.2;
                $grain = sin($gCoord) * 7.5 + sin($gCoord * 2.4) * 3.0;

                $r = clampByte($woodRgb[0] * $profile + $grain);
                $g = clampByte($woodRgb[1] * $profile + $grain * 0.82);
                $b = clampByte($woodRgb[2] * $profile + $grain * 0.65);
                imagesetpixel($canvas, $x, $y, ($r << 16) | ($g << 8) | $b);
            }
        }
    };

    // Left jamb, Right jamb, and Top lintel rail (clean solid wood, ZERO overlap!)
    $fillGrainRect($ox1, $oy1, $ix1, $oy2, true);
    $fillGrainRect($ix2, $oy1, $ox2, $oy2, true);
    $fillGrainRect($ox1, $oy1, $ox2, $iy1, false);

    // Crisp outer & inner molding shadow lines
    $darkCol = imagecolorallocate($canvas, clampByte($woodRgb[0] * 0.42), clampByte($woodRgb[1] * 0.42), clampByte($woodRgb[2] * 0.42));
    $hiCol   = imagecolorallocate($canvas, clampByte($woodRgb[0] * 1.18), clampByte($woodRgb[1] * 1.18), clampByte($woodRgb[2] * 1.15));
    imagerectangle($canvas, $ox1, $oy1, $ox2, $oy2, $darkCol);
    imagerectangle($canvas, $ox1 + 1, $oy1 + 1, $ox2 - 1, $oy2 - 1, $darkCol);
    imagerectangle($canvas, $ix1 - 1, $iy1 - 1, $ix2 + 1, $iy2, $darkCol);
    imageline($canvas, $ox1 + 4, $oy1 + 4, $ox2 - 4, $oy1 + 4, $hiCol);
    imageline($canvas, $ox1 + 4, $oy1 + 4, $ox1 + 4, $oy2 - 4, $hiCol);
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
    $apiKey = '';
    if (defined('GEMINI_API_KEY') && trim((string)GEMINI_API_KEY) !== '') {
        $apiKey = trim((string)GEMINI_API_KEY);
    } elseif (getenv('GEMINI_API_KEY')) {
        $apiKey = trim((string)getenv('GEMINI_API_KEY'));
    }
    if ($apiKey === '' || !function_exists('curl_init')) {
        return false;
    }

    $uploadsRoot = rtrim((string)($opts['uploads_root'] ?? dirname(__DIR__)), '/\\');
    $refDesigns = $opts['reference_designs'] ?? [];
    $refElements = $opts['reference_elements'] ?? [];
    $woodSpecies = (string)($opts['wood_species'] ?? 'Burma Teak');
    $polishShade = (string)($opts['polish_shade'] ?? 'Natural Teak Matte');
    $leafType = (string)($opts['leaf_type'] ?? 'Single Leaf');
    $category = (string)($opts['woodwork_category'] ?? 'Door');

    $roleByDesignId = [];
    foreach ($refElements as $el) {
        $did = (int)($el['design_id'] ?? 0);
        if ($did > 0 && !empty($el['element'])) {
            $roleByDesignId[$did] = (string)$el['element'];
        }
    }

    $parts = [];
    $roleInstructions = [];
    $imgNum = 0;

    foreach ($refDesigns as $d) {
        $did = (int)($d['id'] ?? 0);
        $rel = (string)($d['image_url'] ?? '');
        $abs = $uploadsRoot . DIRECTORY_SEPARATOR . ltrim(str_replace('/', DIRECTORY_SEPARATOR, $rel), '/\\');
        if (is_file($abs)) {
            $raw = @file_get_contents($abs);
            if ($raw) {
                $imgNum++;
                $role = $roleByDesignId[$did] ?? 'Reference Style';
                $mime = (stripos($abs, '.jpg') !== false || stripos($abs, '.jpeg') !== false) ? 'image/jpeg' : 'image/png';
                $parts[] = [
                    'text' => "Reference Image $imgNum [USE FOR: $role] — " . ($d['title'] ?? 'Catalog Door') . ':',
                ];
                $parts[] = [
                    'inline_data' => [
                        'mime_type' => $mime,
                        'data' => base64_encode($raw),
                    ],
                ];
                $roleInstructions[] = "- From Reference Image $imgNum, take ONLY the $role.";
            }
        }
    }

    if ($imgNum === 0) return false;

    $roleGuide = implode("\n", $roleInstructions);
    $parts[] = [
        'text' => "Generate ONE single ultra-realistic, crystal-clear, straight-on architectural studio product photograph (vertical 3:4 portrait) of ONE seamlessly handcrafted Indian solid wooden $leafType $category.\n\n"
            . "COMBINE THESE EXACT ELEMENTS FROM THE REFERENCE IMAGES:\n$roleGuide\n\n"
            . "SPECIFICATIONS: $promptText\n\n"
            . "CRITICAL REALISM & ANTI-COLLAGE RULES:\n"
            . "1. DO NOT paste, collage, or overlay mismatched cutouts on top of each other. Re-craft every part naturally into ONE unified, real physical wooden door built in a master workshop.\n"
            . "2. UNIFIED WOOD & LIGHTING: Match the outer frame, carved pillars, top crown/arch, door shutter, and carvings into ONE identical $woodSpecies wood species with consistent $polishShade finish, matching grain direction, and cohesive studio daylight.\n"
            . "3. EXACT ORIGINAL ARCHITECTURAL PERSPECTIVE: Perfectly straight, plumb, front-facing orthographic elevation (zero camera tilt). Recessed inner door shutter fits snugly inside the carved outer frame with authentic joinery shadows; top crown/arch rests seamlessly flush on the pillar capitals.\n"
            . "4. PRESERVE INTRICATE DETAILS: Keep the exact deity/floral/geometric carvings, quilted patterns, and metallic brass accents faithfully sharp and faithful to their source reference images.\n"
            . "5. CLEAN FULL-LENGTH FRAMING: Show 100% of the complete door from top crown tip to bottom floor threshold on a pure clean white studio backdrop with clean margin on all 4 sides. ZERO cropping, ZERO text, ZERO brand logos, ZERO watermarks.",
    ];

    $model = defined('GEMINI_IMAGE_MODEL') && GEMINI_IMAGE_MODEL ? GEMINI_IMAGE_MODEL : 'gemini-2.5-flash-image';
    $url = 'https://generativelanguage.googleapis.com/v1beta/models/' . rawurlencode($model) . ':generateContent?key=' . rawurlencode($apiKey);

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
 * Finds an available TrueType font file on Windows or Linux/cPanel servers.
 */
function findTtfFontPath(bool $bold = false): ?string {
    $candidates = $bold
        ? [
            __DIR__ . '/../assets/fonts/Inter-Bold.ttf',
            'C:\\Windows\\Fonts\\segoeuib.ttf',
            'C:\\Windows\\Fonts\\arialbd.ttf',
            '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
            '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf',
            '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
            '/usr/share/fonts/liberation/LiberationSans-Bold.ttf',
            '/usr/share/fonts/truetype/freefont/FreeSansBold.ttf',
        ]
        : [
            __DIR__ . '/../assets/fonts/Inter-Regular.ttf',
            'C:\\Windows\\Fonts\\segoeui.ttf',
            'C:\\Windows\\Fonts\\arial.ttf',
            '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
            '/usr/share/fonts/dejavu/DejaVuSans.ttf',
            '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
            '/usr/share/fonts/liberation/LiberationSans-Regular.ttf',
            '/usr/share/fonts/truetype/freefont/FreeSans.ttf',
        ];
    foreach ($candidates as $path) {
        if (is_file($path)) return $path;
    }
    return null;
}

/**
 * Draws a filled or stroked rounded rectangle cleanly on a GD canvas.
 */
function gdDrawRoundedRect($im, int $x1, int $y1, int $x2, int $y2, int $r, int $color, bool $filled = true, int $thickness = 2): void {
    $r = max(0, min($r, (int)(($x2 - $x1) / 2), (int)(($y2 - $y1) / 2)));
    if ($filled) {
        imagefilledrectangle($im, $x1 + $r, $y1, $x2 - $r, $y2, $color);
        imagefilledrectangle($im, $x1, $y1 + $r, $x2, $y2 - $r, $color);
        if ($r > 0) {
            imagefilledellipse($im, $x1 + $r, $y1 + $r, $r * 2, $r * 2, $color);
            imagefilledellipse($im, $x2 - $r, $y1 + $r, $r * 2, $r * 2, $color);
            imagefilledellipse($im, $x1 + $r, $y2 - $r, $r * 2, $r * 2, $color);
            imagefilledellipse($im, $x2 - $r, $y2 - $r, $r * 2, $r * 2, $color);
        }
        return;
    }
    for ($t = 0; $t < $thickness; $t++) {
        $ax1 = $x1 + $t; $ay1 = $y1 + $t; $ax2 = $x2 - $t; $ay2 = $y2 - $t;
        $ar = max(0, $r - $t);
        imageline($im, $ax1 + $ar, $ay1, $ax2 - $ar, $ay1, $color);
        imageline($im, $ax1 + $ar, $ay2, $ax2 - $ar, $ay2, $color);
        imageline($im, $ax1, $ay1 + $ar, $ax1, $ay2 - $ar, $color);
        imageline($im, $ax2, $ay1 + $ar, $ax2, $ay2 - $ar, $color);
        if ($ar > 0) {
            imagearc($im, $ax1 + $ar, $ay1 + $ar, $ar * 2, $ar * 2, 180, 270, $color);
            imagearc($im, $ax2 - $ar, $ay1 + $ar, $ar * 2, $ar * 2, 270, 360, $color);
            imagearc($im, $ax2 - $ar, $ay2 - $ar, $ar * 2, $ar * 2, 0, 90, $color);
            imagearc($im, $ax1 + $ar, $ay2 - $ar, $ar * 2, $ar * 2, 90, 180, $color);
        }
    }
}

/**
 * Draws a solid or dashed thick rectangular zone highlight on a GD image.
 */
function gdDrawZoneBox($im, int $x1, int $y1, int $x2, int $y2, int $color, int $thickness = 3, bool $dashed = false): void {
    if (!$dashed) {
        gdDrawRoundedRect($im, $x1, $y1, $x2, $y2, 8, $color, false, $thickness);
        return;
    }
    $dash = 14;
    $gap = 8;
    for ($t = 0; $t < $thickness; $t++) {
        $lx1 = $x1 + $t; $ly1 = $y1 + $t; $lx2 = $x2 - $t; $ly2 = $y2 - $t;
        for ($x = $lx1; $x < $lx2; $x += ($dash + $gap)) {
            $ex = min($lx2, $x + $dash);
            imageline($im, $x, $ly1, $ex, $ly1, $color);
            imageline($im, $x, $ly2, $ex, $ly2, $color);
        }
        for ($y = $ly1; $y < $ly2; $y += ($dash + $gap)) {
            $ey = min($ly2, $y + $dash);
            imageline($im, $lx1, $y, $lx1, $ey, $color);
            imageline($im, $lx2, $y, $lx2, $ey, $color);
        }
    }
}

/**
 * Draws a crisp thick anti-aliased line segment between two points (works reliably even with imageantialias).
 */
function gdDrawThickLine($im, int $x1, int $y1, int $x2, int $y2, int $color, int $thickness = 3): void {
    $dx = $x2 - $x1;
    $dy = $y2 - $y1;
    $len = sqrt($dx * $dx + $dy * $dy);
    if ($len < 0.5) return;
    $half = $thickness / 2.0;
    $nx = (-$dy / $len) * $half;
    $ny = ($dx / $len) * $half;
    $pts = [
        (int)round($x1 + $nx), (int)round($y1 + $ny),
        (int)round($x2 + $nx), (int)round($y2 + $ny),
        (int)round($x2 - $nx), (int)round($y2 - $ny),
        (int)round($x1 - $nx), (int)round($y1 - $ny),
    ];
    imagefilledpolygon($im, $pts, $color);
}

/**
 * Draws text using TrueType font if available (with automatic GD bitmap fallback).
 */
function gdDrawText($im, float $sizePt, int $x, int $y, int $color, string $text, ?string $fontPath, string $align = 'left'): void {
    if ($fontPath !== null && function_exists('imagettftext')) {
        $bbox = @imagettfbbox($sizePt, 0, $fontPath, $text);
        $tw = $bbox ? abs($bbox[2] - $bbox[0]) : 0;
        $drawX = $x;
        if ($align === 'center') $drawX = (int)round($x - $tw / 2.0);
        elseif ($align === 'right') $drawX = (int)round($x - $tw);
        @imagettftext($im, $sizePt, 0, $drawX, $y, $color, $fontPath, $text);
        return;
    }
    $gFont = $sizePt >= 14 ? 5 : ($sizePt >= 11 ? 4 : 3);
    $fw = imagefontwidth($gFont) * strlen($text);
    $drawX = $x;
    if ($align === 'center') $drawX = (int)round($x - $fw / 2.0);
    elseif ($align === 'right') $drawX = (int)round($x - $fw);
    imagestring($im, $gFont, $drawX, $y - imagefontheight($gFont), $text, $color);
}

/**
 * Word-wraps a string into lines that fit within $maxWidth px.
 */
function gdWrapText(string $text, float $sizePt, ?string $fontPath, int $maxWidth, int $maxLines = 2): array {
    $words = preg_split('/\s+/', trim($text)) ?: [];
    if (empty($words)) return [''];
    $lines = [];
    $current = '';

    $measure = function (string $s) use ($sizePt, $fontPath): int {
        if ($fontPath !== null && function_exists('imagettfbbox')) {
            $b = @imagettfbbox($sizePt, 0, $fontPath, $s);
            return $b ? (int)abs($b[2] - $b[0]) : strlen($s) * 8;
        }
        return strlen($s) * 7;
    };

    foreach ($words as $w) {
        $test = $current === '' ? $w : ($current . ' ' . $w);
        if ($measure($test) <= $maxWidth || $current === '') {
            $current = $test;
        } else {
            $lines[] = $current;
            $current = $w;
            if (count($lines) >= $maxLines - 1) {
                // Append remaining words into last line with ellipsis if too long
                break;
            }
        }
    }
    if ($current !== '') {
        // Check if we stopped early and append remaining words
        $usedCount = 0;
        foreach ($lines as $ln) $usedCount += count(preg_split('/\s+/', trim($ln)) ?: []);
        $rest = implode(' ', array_slice($words, $usedCount));
        if ($rest === '') $rest = $current;
        while ($measure($rest) > $maxWidth && strlen($rest) > 8) {
            $rest = rtrim(substr($rest, 0, -4)) . '...';
        }
        $lines[] = $rest;
    }
    return array_slice($lines, 0, $maxLines);
}

/**
 * Draws a numbered circular color badge with crisp white ring.
 */
function gdDrawBadgeCircle($im, int $cx, int $cy, int $radius, int $fillCol, int $whiteCol, string $label, ?string $boldFont): void {
    imagefilledellipse($im, $cx, $cy, ($radius + 3) * 2, ($radius + 3) * 2, $whiteCol);
    imagefilledellipse($im, $cx, $cy, $radius * 2, $radius * 2, $fillCol);
    $fontPt = max(10.0, $radius * 0.82);
    gdDrawText($im, $fontPt, $cx, (int)round($cy + $fontPt * 0.48), $whiteCol, $label, $boldFont, 'center');
}

/**
 * Renders the HD Pictorial 5-Combine-Elements Guide PNG matching the reference diagram:
 *  - Dark wood header banner
 *  - Center generated HD door with exact color-coded zone outlines & numbered badges (1..5)
 *  - Left (4 Top Arch & Crown, 1 Frame Style, 5 Panel Layout) & Right (2 Center Carving,
 *    3 Border / Polish Finish) callout cards containing each source catalog design's thumbnail,
 *    source title, and style breakdown, linked by crisp bent leader lines.
 */
function renderAnnotatedGuidePngPhp(
    $doorImg,
    array $regions,
    array $breakdown,
    array $sourceThumbImgs,
    string $category,
    string $guidePath
): bool {
    if (!function_exists('imagecreatetruecolor')) return false;

    $W = 1600;
    $H = 1180;
    $im = imagecreatetruecolor($W, $H);
    imagealphablending($im, true);
    if (function_exists('imageantialias')) {
        @imageantialias($im, true);
    }

    $fontBold = findTtfFontPath(true);
    $fontReg  = findTtfFontPath(false) ?? $fontBold;

    // Palette matching the reference pictorial diagram
    $creamBg    = imagecolorallocate($im, 250, 247, 242);
    $headerBg   = imagecolorallocate($im, 56, 30, 14);
    $white      = imagecolorallocate($im, 255, 255, 255);
    $creamSub   = imagecolorallocate($im, 236, 222, 204);
    $cardBorder = imagecolorallocate($im, 226, 217, 204);
    $textDark   = imagecolorallocate($im, 42, 24, 12);
    $textMuted  = imagecolorallocate($im, 108, 92, 78);
    $thumbBg    = imagecolorallocate($im, 252, 250, 247);

    $elemColors = [
        'frame'  => imagecolorallocate($im, 37, 99, 235),  // 1 Blue
        'center' => imagecolorallocate($im, 234, 88, 12),  // 2 Orange
        'border' => imagecolorallocate($im, 147, 51, 234), // 3 Purple
        'crown'  => imagecolorallocate($im, 220, 38, 38),  // 4 Red
        'panel'  => imagecolorallocate($im, 22, 163, 74),  // 5 Green
    ];

    // 1) Backdrop & dark wood header banner
    imagefilledrectangle($im, 0, 0, $W, $H, $creamBg);
    imagefilledrectangle($im, 0, 0, $W, 96, $headerBg);

    gdDrawText($im, 24, (int)($W / 2), 46, $white, "Custom $category — 5 Combine Elements Guide", $fontBold, 'center');
    gdDrawText($im, 12, (int)($W / 2), 76, $creamSub, 'Each color highlights the exact area & source catalog frame picked when combining designs', $fontReg, 'center');

    // 2) Center Generated HD Door Showcase Container
    $boxX0 = 448; $boxY0 = 114; $boxX1 = 1152; $boxY1 = 1114;
    gdDrawRoundedRect($im, $boxX0, $boxY0, $boxX1, $boxY1, 18, $white, true);
    gdDrawRoundedRect($im, $boxX0, $boxY0, $boxX1, $boxY1, 18, $cardBorder, false, 2);

    $dw = imagesx($doorImg);
    $dh = imagesy($doorImg);
    $pad = 12;
    $availW = ($boxX1 - $boxX0) - $pad * 2;
    $availH = ($boxY1 - $boxY0) - $pad * 2;
    $scale = min($availW / max(1.0, (float)$dw), $availH / max(1.0, (float)$dh));
    $drawW = (int)round($dw * $scale);
    $drawH = (int)round($dh * $scale);
    $drawX = $boxX0 + (int)round((($boxX1 - $boxX0) - $drawW) / 2.0);
    $drawY = $boxY0 + (int)round((($boxY1 - $boxY0) - $drawH) / 2.0);

    imagecopyresampled($im, $doorImg, $drawX, $drawY, 0, 0, $drawW, $drawH, $dw, $dh);

    // Map normalized 0..1 regions onto exact pixel rects on the center door
    $mapZone = function (string $key) use ($regions, $drawX, $drawY, $drawW, $drawH): array {
        $r = $regions[$key] ?? ['x' => 0.1, 'y' => 0.1, 'w' => 0.8, 'h' => 0.8];
        $x1 = $drawX + (int)round($r['x'] * $drawW);
        $y1 = $drawY + (int)round($r['y'] * $drawH);
        $x2 = $x1 + max(24, (int)round($r['w'] * $drawW));
        $y2 = $y1 + max(24, (int)round($r['h'] * $drawH));
        return [$x1, $y1, $x2, $y2];
    };

    $byKey = [];
    foreach ($breakdown as $item) {
        $byKey[$item['key']] = $item;
    }

    // Draw color-coded zone boxes on the center door (same layering as attached guide!)
    $zCrown  = $mapZone('crown');
    $zFrame  = $mapZone('frame');
    $zPanel  = $mapZone('panel');
    $zCenter = $mapZone('center');
    $zBorder = $mapZone('border');

    if (isset($byKey['frame']))  gdDrawZoneBox($im, $zFrame[0], $zFrame[1], $zFrame[2], $zFrame[3], $elemColors['frame'], 3, true);
    if (isset($byKey['panel']))  gdDrawZoneBox($im, $zPanel[0], $zPanel[1], $zPanel[2], $zPanel[3], $elemColors['panel'], 3, true);
    if (isset($byKey['center'])) gdDrawZoneBox($im, $zCenter[0], $zCenter[1], $zCenter[2], $zCenter[3], $elemColors['center'], 3, false);
    if (isset($byKey['border'])) gdDrawZoneBox($im, $zBorder[0], $zBorder[1], $zBorder[2], $zBorder[3], $elemColors['border'], 3, false);
    if (isset($byKey['crown']))  gdDrawZoneBox($im, $zCrown[0], $zCrown[1], $zCrown[2], $zCrown[3], $elemColors['crown'], 3, false);

    // Badge coordinates right on the door zones
    $crownCx = (int)round(($zCrown[0] + $zCrown[2]) / 2.0);
    $crownCy = (int)round(($zCrown[1] + $zCrown[3]) / 2.0);
    $frameBadgeX = $zFrame[0] + max(18, (int)round(($zPanel[0] - $zFrame[0]) * 0.55));
    $frameBadgeY = (int)round($zFrame[1] + ($zFrame[3] - $zFrame[1]) * 0.44);
    $panelBadgeX = $zPanel[0] + max(24, (int)round(($zPanel[2] - $zPanel[0]) * 0.22));
    $panelBadgeY = $zPanel[3] - 20;
    $centerBadgeX = (int)round(($zCenter[0] + $zCenter[2]) / 2.0);
    $centerBadgeY = (int)round(($zCenter[1] + $zCenter[3]) / 2.0);
    $borderBadgeX = (int)round(($zBorder[0] + $zBorder[2]) / 2.0);
    $borderBadgeY = $zBorder[3] - 26;

    // Leader line target dots on the door edges
    $targets = [
        'crown'  => [$zCrown[0] + 18, $crownCy],
        'frame'  => [$zFrame[0], (int)round($zFrame[1] + ($zFrame[3] - $zFrame[1]) * 0.34)],
        'panel'  => [$zPanel[0] + 8, $zPanel[3] - 46],
        'center' => [$zCenter[2] - 8, (int)round($zCenter[1] + ($zCenter[3] - $zCenter[1]) * 0.35)],
        'border' => [$zBorder[2], (int)round(($zBorder[1] + $zBorder[3]) / 2.0)],
    ];

    // Left & Right Callout Card slots matching attached guide layout
    $cardSlots = [
        'crown'  => ['side' => 'left',  'x1' => 26,   'y1' => 142, 'x2' => 414,  'y2' => 332],
        'frame'  => ['side' => 'left',  'x1' => 26,   'y1' => 478, 'x2' => 414,  'y2' => 668],
        'panel'  => ['side' => 'left',  'x1' => 26,   'y1' => 826, 'x2' => 414,  'y2' => 1016],
        'center' => ['side' => 'right', 'x1' => 1186, 'y1' => 296, 'x2' => 1574, 'y2' => 486],
        'border' => ['side' => 'right', 'x1' => 1186, 'y1' => 708, 'x2' => 1574, 'y2' => 898],
    ];

    foreach ($cardSlots as $key => $slot) {
        if (!isset($byKey[$key])) continue;
        $item = $byKey[$key];
        $col = $elemColors[$key];
        $x1 = $slot['x1']; $y1 = $slot['y1']; $x2 = $slot['x2']; $y2 = $slot['y2'];
        $midY = (int)round(($y1 + $y2) / 2.0);
        [$tx, $ty] = $targets[$key];

        // Bent leader line connecting card to exact target point on the door
        if ($slot['side'] === 'left') {
            $elbowX = $x2 + 28;
            gdDrawThickLine($im, $x2, $midY, $elbowX, $midY, $col, 3);
            gdDrawThickLine($im, $elbowX, $midY, $tx, $ty, $col, 3);
        } else {
            $elbowX = $x1 - 28;
            gdDrawThickLine($im, $x1, $midY, $elbowX, $midY, $col, 3);
            gdDrawThickLine($im, $elbowX, $midY, $tx, $ty, $col, 3);
        }
        // White-ringed target dot on door
        imagefilledellipse($im, $tx, $ty, 16, 16, $white);
        imagefilledellipse($im, $tx, $ty, 10, 10, $col);

        // Callout card container
        gdDrawRoundedRect($im, $x1, $y1, $x2, $y2, 14, $white, true);
        gdDrawRoundedRect($im, $x1, $y1, $x2, $y2, 14, $col, false, 3);

        // Mini source catalog thumbnail on the left inside the card
        $thX = $x1 + 14;
        $thY = $y1 + 16;
        $thW = 86;
        $thH = ($y2 - $y1) - 32;
        gdDrawRoundedRect($im, $thX, $thY, $thX + $thW, $thY + $thH, 8, $thumbBg, true);
        gdDrawRoundedRect($im, $thX, $thY, $thX + $thW, $thY + $thH, 8, $cardBorder, false, 1);

        $did = (int)($item['design_id'] ?? 0);
        if (isset($sourceThumbImgs[$did])) {
            $tImg = $sourceThumbImgs[$did];
            $tw = imagesx($tImg);
            $th = imagesy($tImg);
            $ts = min(($thW - 8) / max(1.0, (float)$tw), ($thH - 8) / max(1.0, (float)$th));
            $tdw = max(8, (int)round($tw * $ts));
            $tdh = max(8, (int)round($th * $ts));
            $tdx = $thX + (int)round(($thW - $tdw) / 2.0);
            $tdy = $thY + (int)round(($thH - $tdh) / 2.0);
            imagecopyresampled($im, $tImg, $tdx, $tdy, 0, 0, $tdw, $tdh, $tw, $th);
        }

        // Badge + Element title + Source catalog name + Craft description
        $txtX = $thX + $thW + 14;
        $txtMaxW = ($x2 - 14) - $txtX;
        gdDrawBadgeCircle($im, $txtX + 14, $y1 + 32, 14, $col, $white, (string)$item['number'], $fontBold);
        gdDrawText($im, 13.5, $txtX + 36, $y1 + 38, $textDark, (string)$item['label'], $fontBold, 'left');

        $srcPrefix = !empty($item['is_explicit']) ? 'From: ' : 'Base: ';
        $srcLines = gdWrapText($srcPrefix . (string)($item['design_title'] ?? ''), 10.5, $fontBold, $txtMaxW, 2);
        $curY = $y1 + 66;
        foreach ($srcLines as $ln) {
            gdDrawText($im, 10.5, $txtX, $curY, $col, $ln, $fontBold, 'left');
            $curY += 20;
        }

        $descLines = gdWrapText((string)($item['description'] ?? ''), 9.5, $fontReg, $txtMaxW, 2);
        $curY += 6;
        foreach ($descLines as $ln) {
            gdDrawText($im, 9.5, $txtX, $curY, $textMuted, $ln, $fontReg, 'left');
            $curY += 18;
        }
    }

    // Numbered circular badges right on top of the center door zones
    if (isset($byKey['crown']))  gdDrawBadgeCircle($im, $crownCx, $crownCy, 18, $elemColors['crown'], $white, '4', $fontBold);
    if (isset($byKey['frame']))  gdDrawBadgeCircle($im, $frameBadgeX, $frameBadgeY, 18, $elemColors['frame'], $white, '1', $fontBold);
    if (isset($byKey['panel']))  gdDrawBadgeCircle($im, $panelBadgeX, $panelBadgeY, 18, $elemColors['panel'], $white, '5', $fontBold);
    if (isset($byKey['center'])) gdDrawBadgeCircle($im, $centerBadgeX, $centerBadgeY, 18, $elemColors['center'], $white, '2', $fontBold);
    if (isset($byKey['border'])) gdDrawBadgeCircle($im, $borderBadgeX, $borderBadgeY, 18, $elemColors['border'], $white, '3', $fontBold);

    // Bottom legend footer bar
    gdDrawText(
        $im,
        11,
        (int)($W / 2),
        1152,
        $textMuted,
        'WoodCraft AI Combiner Reference  |  1 Frame Style  •  2 Center Carving  •  3 Border / Polish Finish  •  4 Top Arch & Crown  •  5 Panel Layout',
        $fontReg,
        'center'
    );

    $ok = imagepng($im, $guidePath, 5);
    imagedestroy($im);
    return (bool)$ok;
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

    // Pre-extract source objects so both Gemini AI and the built-in compositor can share
    // accurate breakdown metadata, source thumbnails, and companion HD pictorial guides!
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

        // Resolve element assignments strictly in selection order (latest selection wins)
        $ids = array_keys($objs);
        $frameId = null;
        $crownId = null;
        $panelId = null;
        $centerId = null;
        $finishId = null;
        $latestLeafId = null;
        $latestLeafRole = null;

        foreach ($refElements as $el) {
            $did = (int)($el['design_id'] ?? 0);
            $elName = strtolower(trim((string)($el['element'] ?? '')));
            if (!isset($objs[$did]) || $elName === '') continue;

            if (strpos($elName, 'frame') !== false) {
                $frameId = $did;
            } elseif (strpos($elName, 'arch') !== false || strpos($elName, 'crown') !== false || strpos($elName, 'top') !== false) {
                $crownId = $did;
            } elseif (strpos($elName, 'panel') !== false || strpos($elName, 'layout') !== false) {
                $panelId = $did;
                $latestLeafId = $did;
                $latestLeafRole = 'panel';
            } elseif (strpos($elName, 'center') !== false || strpos($elName, 'carving') !== false || strpos($elName, 'medallion') !== false || strpos($elName, 'bell') !== false) {
                $centerId = $did;
                $latestLeafId = $did;
                $latestLeafRole = 'center';
            } elseif (strpos($elName, 'polish') !== false || strpos($elName, 'finish') !== false || strpos($elName, 'border') !== false) {
                $finishId = $did;
            }
        }

        // 1. Try real Gemini multimodal generative AI first if GEMINI_API_KEY is configured!
        if (!empty($objs) && $promptText !== '' && tryGeminiAiCombine($opts, $promptText, $fullPath)) {
            $gemObj = extractDoorObject($fullPath, ['title' => $category]);
            $gemIm = @imagecreatefrompng($fullPath);
            $gw = $gemIm ? imagesx($gemIm) : 960;
            $gh = $gemIm ? imagesy($gemIm) : 1280;

            $normGem = function (int $x, int $y, int $w, int $h) use ($gw, $gh): array {
                $nx = max(0.0, min(0.95, $x / max(1.0, (float)$gw)));
                $ny = max(0.0, min(0.95, $y / max(1.0, (float)$gh)));
                $nw = max(0.04, min(1.0 - $nx, $w / max(1.0, (float)$gw)));
                $nh = max(0.04, min(1.0 - $ny, $h / max(1.0, (float)$gh)));
                return ['x' => round($nx, 4), 'y' => round($ny, 4), 'w' => round($nw, 4), 'h' => round($nh, 4)];
            };

            if ($gemObj !== null) {
                $in = $gemObj['inner'];
                $cw = $gemObj['w'];
                $ch = $gemObj['h'];
                $cTop = max(48, (int)$gemObj['crown_bottom_y']);
                $cInX = (int)round($in['w'] * 0.08);
                $cInY = (int)round($in['h'] * 0.08);
                $bW = max(24, (int)round($in['w'] * 0.11));
                $bH = max(80, (int)round($in['h'] * 0.34));
                $gScaleX = $gw / max(1.0, (float)$cw);
                $gScaleY = $gh / max(1.0, (float)$ch);
                $elementRegions = [
                    'crown'  => $normGem(0, 0, $gw, (int)round($cTop * $gScaleY)),
                    'frame'  => $normGem(0, (int)round($cTop * $gScaleY * 0.88), $gw, max(80, $gh - (int)round($cTop * $gScaleY * 0.88))),
                    'panel'  => $normGem((int)round($in['x'] * $gScaleX), (int)round($in['y'] * $gScaleY), (int)round($in['w'] * $gScaleX), (int)round($in['h'] * $gScaleY)),
                    'center' => $normGem((int)round(($in['x'] + $cInX) * $gScaleX), (int)round(($in['y'] + $cInY) * $gScaleY), max(40, (int)round(($in['w'] - $cInX * 2) * $gScaleX)), max(60, (int)round(($in['h'] - $cInY * 2) * $gScaleY))),
                    'border' => $normGem((int)round(($in['x'] + $in['w'] - $bW * 0.55) * $gScaleX), (int)round(($in['y'] + $in['h'] - $bH - $in['h'] * 0.08) * $gScaleY), (int)round($bW * $gScaleX), (int)round($bH * $gScaleY)),
                ];
                imagedestroy($gemObj['img']);
            } else {
                $elementRegions = [
                    'crown'  => ['x' => 0.05, 'y' => 0.03, 'w' => 0.90, 'h' => 0.17],
                    'frame'  => ['x' => 0.07, 'y' => 0.18, 'w' => 0.86, 'h' => 0.78],
                    'panel'  => ['x' => 0.21, 'y' => 0.20, 'w' => 0.58, 'h' => 0.73],
                    'center' => ['x' => 0.27, 'y' => 0.26, 'w' => 0.46, 'h' => 0.60],
                    'border' => ['x' => 0.74, 'y' => 0.62, 'w' => 0.08, 'h' => 0.26],
                ];
            }

            $designById = [];
            foreach ($refDesigns as $d) $designById[(int)($d['id'] ?? 0)] = $d;
            $baseFallback = $frameId ?? $crownId ?? $latestLeafId ?? $ids[0];
            $leafFallback = $latestLeafId ?? $baseFallback;
            $mkItem = function (int $num, string $key, string $label, string $colorHex, ?int $explicitId, int $fallbackId, string $desc) use ($designById): array {
                $eid = $explicitId ?? $fallbackId;
                $d = $designById[$eid] ?? ['id' => $eid, 'title' => "Design #$eid", 'image_url' => ''];
                return [
                    'number' => $num, 'key' => $key, 'label' => $label, 'color' => $colorHex,
                    'design_id' => $eid, 'design_title' => (string)($d['title'] ?? "Design #$eid"),
                    'design_image_url' => (string)($d['image_url'] ?? ''),
                    'is_explicit' => ($explicitId !== null), 'description' => $desc,
                ];
            };
            $elementBreakdown = [
                $mkItem(1, 'frame',  'Frame Style',            '#2563EB', $frameId, $baseFallback, 'Full outer wooden frame & left/right carved pillars'),
                $mkItem(2, 'center', 'Center Carving',         '#EA580C', $latestLeafRole === 'center' ? $latestLeafId : null, $leafFallback, 'Main carving artwork inside the door leaf'),
                $mkItem(3, 'border', 'Border / Polish Finish', '#9333EA', $finishId, $baseFallback, "$polishShade wood tone, shine & inner border molding"),
                $mkItem(4, 'crown',  'Top Arch & Crown',       '#DC2626', $crownId, $baseFallback, 'Top arch, temple carving & crown header only'),
                $mkItem(5, 'panel',  'Panel Layout',           '#16A34A', $latestLeafRole === 'panel' ? $latestLeafId : null, $leafFallback, 'Full inner door shutter & panel layout'),
            ];

            $guideFilename = preg_replace('/\.png$/i', '-guide.png', $filename);
            $guidePath = rtrim($outputDir, '/\\') . DIRECTORY_SEPARATOR . $guideFilename;
            $thumbImgs = [];
            foreach ($objs as $did => $o) $thumbImgs[$did] = $o['img'];
            $guideOk = $gemIm ? renderAnnotatedGuidePngPhp($gemIm, $elementRegions, $elementBreakdown, $thumbImgs, $category, $guidePath) : false;

            $outputAspect = round($gw / max(1.0, (float)$gh), 4);
            $metaFilename = preg_replace('/\.png$/i', '-meta.json', $filename);
            $metaPath = rtrim($outputDir, '/\\') . DIRECTORY_SEPARATOR . $metaFilename;
            @file_put_contents($metaPath, json_encode([
                'element_regions' => $elementRegions,
                'element_breakdown' => $elementBreakdown,
                'output_aspect' => $outputAspect,
                'ai_guide_image_url' => $guideOk ? ('/uploads/ai-outputs/' . $guideFilename) : null,
            ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));

            if ($gemIm) imagedestroy($gemIm);
            foreach ($objs as $o) imagedestroy($o['img']);

            return [
                'filename' => $filename,
                'full_path' => $fullPath,
                'guide_filename' => $guideOk ? $guideFilename : null,
                'guide_full_path' => $guideOk ? $guidePath : null,
                'element_regions' => $elementRegions,
                'element_breakdown' => $elementBreakdown,
                'output_aspect' => $outputAspect,
                'engine' => 'gemini-multimodal-ai',
            ];
        }

        if (!empty($objs)) {

            // ZERO-OVERLAP ARCHITECTURAL COMPOSITION:
            //  1) If Frame Style is a REAL framed door with outer pillars (is_framed = true),
            //     use its real carved pillars/frame as the base, and cleanly REPLACE 100% of
            //     its inner doorway with ONLY the single latest inner shutter ($latestLeafId).
            //  2) If Frame Style is an UNFRAMED shutter (e.g. #071) AND a different inner door
            //     ($latestLeafId, e.g. #074) is selected: NEVER paste #074 on top of #071's
            //     carvings! Instead, completely remove #071's face and build a clean solid
            //     molded wooden frame in #071's exact wood finish surrounding #074 cleanly!
            //  3) If no Frame Style was selected: prefer a real framed design (e.g. framed crown)
            //     as outer frame; otherwise show ONLY the latest selected clean door ($latestLeafId)
            //     with ZERO previous shutter left underneath!
            $useCleanMoldedFrame = false;
            $frameToneId = null;

            if ($frameId !== null && $objs[$frameId]['is_framed']) {
                $baseId = $frameId;
            } elseif ($frameId !== null && !$objs[$frameId]['is_framed'] && $latestLeafId !== null && $latestLeafId !== $frameId) {
                // Unframed shutter assigned as Frame Style + a different inner leaf selected:
                // Use the latest leaf cleanly inside a freshly crafted solid molded wood frame!
                $baseId = $latestLeafId;
                $useCleanMoldedFrame = true;
                $frameToneId = $frameId;
            } elseif ($frameId !== null) {
                $baseId = $frameId;
            } elseif ($crownId !== null && $objs[$crownId]['is_framed']) {
                $baseId = $crownId;
            } elseif ($latestLeafId !== null) {
                $baseId = $latestLeafId;
            } else {
                $baseId = $crownId ?? $finishId ?? $ids[0];
            }

            $base = $objs[$baseId];

            // Determine whether a separate Top Arch & Crown will be mounted atop the base
            $hasSeparateCrown = ($crownId !== null && $crownId !== $baseId && isset($objs[$crownId]));
            $crownAddsTopHeight = $hasSeparateCrown && (!$base['is_framed'] || $useCleanMoldedFrame);

            // Create pure crisp white studio canvas
            $canvas = imagecreatetruecolor($canvasW, $canvasH);
            $bgCol = imagecolorallocate($canvas, (int)$canvasBg[0], (int)$canvasBg[1], (int)$canvasBg[2]);
            imagefilledrectangle($canvas, 0, 0, $canvasW, $canvasH, $bgCol);

            // Crisp, balanced margins so the HD door fills almost the entire frame with ZERO clipping
            $padX = 36;
            $padBottom = 38;
            $padTop = $crownAddsTopHeight ? 230 : 38;
            $availW = $canvasW - $padX * 2;
            $availH = $canvasH - $padTop - $padBottom;

            if ($useCleanMoldedFrame && !$base['is_landscape']) {
                // Clean solid molded wood frame around the COMPLETE uncropped latest door leaf
                // (ZERO old carvings or studs peeking out behind the door!)
                $frameJambW = 54;
                $frameHeadH = 44;
                $innerAvailW = max(120, $availW - $frameJambW * 2);
                $innerAvailH = max(180, $availH - $frameHeadH);
                $scale = min($innerAvailW / max(1.0, (float)$base['w']), $innerAvailH / max(1.0, (float)$base['h']));

                $leafW = max(60, (int)round($base['w'] * $scale));
                $leafH = max(100, (int)round($base['h'] * $scale));
                $dstBaseW = $leafW + $frameJambW * 2;
                $dstBaseH = $leafH + $frameHeadH;
                $dstBaseX = (int)round(($canvasW - $dstBaseW) / 2.0);
                $dstBaseY = $crownAddsTopHeight
                    ? ($canvasH - $padBottom - $dstBaseH)
                    : ($padTop + (int)round(($availH - $dstBaseH) / 2.0));

                $baseOuter = ['x' => $dstBaseX, 'y' => $dstBaseY, 'w' => $dstBaseW, 'h' => $dstBaseH];
                $baseInner = [
                    'x' => $dstBaseX + $frameJambW,
                    'y' => $dstBaseY + $frameHeadH,
                    'w' => $leafW,
                    'h' => $leafH,
                ];
                $baseLintelY = $dstBaseY + $frameHeadH;
                $baseMidLeftX = $dstBaseX;
                $baseMidRightX = $dstBaseX + $dstBaseW;
                $baseMidW = $dstBaseW;

                // Sample rich wood stats from the selected Frame Style design for the clean molded Chowkhat frame
                $fToneObj = $objs[$frameToneId ?? $baseId];
                $baseWoodStats = sampleWoodColorStats(
                    $fToneObj['img'],
                    0,
                    0,
                    $fToneObj['w'],
                    $fToneObj['h'],
                    $fToneObj['has_clean_bg'] ? $fToneObj['bg'] : null
                );
                $baseWoodRgb = $baseWoodStats['rgb'];

                drawCleanSolidWoodFrame($canvas, $baseOuter, $baseInner, $baseWoodRgb);

                // Place the COMPLETE latest selected door leaf cleanly inside the molded frame
                compositeRegionClean(
                    $canvas,
                    $base['img'],
                    $base['leaf'],
                    $baseInner,
                    $baseWoodStats,
                    2,
                    true,
                    false,
                    $base['has_clean_bg'],
                    $base['bg'],
                    false
                );
            } else {
                // Standard contain-fit placement of the base architectural structure (NEVER cover-crops!)
                $scale = min($availW / max(1.0, (float)$base['w']), $availH / max(1.0, (float)$base['h']));
                $dstBaseW = max(40, (int)round($base['w'] * $scale));
                $dstBaseH = max(40, (int)round($base['h'] * $scale));
                $dstBaseX = (int)round(($canvasW - $dstBaseW) / 2.0);
                $dstBaseY = $crownAddsTopHeight
                    ? ($canvasH - $padBottom - $dstBaseH)
                    : ($padTop + (int)round(($availH - $dstBaseH) / 2.0));

                // Place the full, uncropped base door cleanly onto the studio canvas
                blitCleanObjectToCanvas($canvas, $base, $dstBaseX, $dstBaseY, $dstBaseW, $dstBaseH, $canvasBg);

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

                // Sample full perceptual wood stats strictly from the outer frame pillars so inner shutter
                // and mounted crown harmonize seamlessly into ONE identical solid-wood stain & exposure!
                $pillarSampleW = max(24, $baseInner['x'] - $baseMidLeftX);
                $baseWoodStats = sampleWoodColorStats(
                    $canvas,
                    $baseMidLeftX,
                    $baseInner['y'],
                    $pillarSampleW,
                    $baseInner['h'],
                    $canvasBg
                );
                if ($baseWoodStats['mY'] < 32.0) {
                    $baseWoodStats = sampleWoodColorStats(
                        $canvas,
                        $baseOuter['x'],
                        $baseOuter['y'],
                        $baseOuter['w'],
                        $baseOuter['h'],
                        $canvasBg
                    );
                }
                $baseWoodRgb = $baseWoodStats['rgb'];

                // CLEAN 100% REPLACEMENT OF INNER DOORWAY OPENING:
                // Only the SINGLE latest selected inner door ($latestLeafId) is placed recessed inside $baseInner.
                // Completely wipes the previous inner door first, harmonizes wood tone via YCbCr transfer,
                // and casts realistic overhead lintel & pillar recess shadows so it sits INSIDE the frame!
                if ($latestLeafId !== null && $latestLeafId !== $baseId && isset($objs[$latestLeafId]) && !$base['is_landscape']) {
                    $srcObj = $objs[$latestLeafId];
                    $srcLeafRect = $srcObj['leaf'];

                    // Fill interior opening cleanly with matching deep wood shadow (no stark black border!)
                    $wipeCol = imagecolorallocate(
                        $canvas,
                        clampByte($baseWoodRgb[0] * 0.45),
                        clampByte($baseWoodRgb[1] * 0.45),
                        clampByte($baseWoodRgb[2] * 0.45)
                    );
                    imagefilledrectangle(
                        $canvas,
                        $baseInner['x'] + 2,
                        $baseInner['y'] + 2,
                        $baseInner['x'] + $baseInner['w'] - 3,
                        $baseInner['y'] + $baseInner['h'] - 3,
                        $wipeCol
                    );

                    // Soft 5px feather at jamb edges blends the shutter organically into the real carved pillars
                    compositeRegionClean(
                        $canvas,
                        $srcObj['img'],
                        $srcLeafRect,
                        $baseInner,
                        $baseWoodStats,
                        5,
                        true,
                        false,
                        $srcObj['has_clean_bg'],
                        $srcObj['bg'],
                        false
                    );
                }
            }

            // C) Top Arch & Crown — architecturally seated flush onto pillar capitals (NEVER pasted like a floating block!)
            $finalTopY = $baseOuter['y'];
            $finalLeftX = $baseOuter['x'];
            $finalRightX = $baseOuter['x'] + $baseOuter['w'];

            if ($hasSeparateCrown && !$base['is_landscape']) {
                $cObj = $objs[$crownId];
                $cHasRealCrown = ($cObj['has_arched_crown'] || $cObj['has_flared_crown'] || $cObj['is_framed']);

                // Measure the ACTUAL horizontal wood span of the base pillars right where the crown seats
                $seatMeasureY = ($base['is_framed'] && !$useCleanMoldedFrame)
                    ? min($canvasH - 1, $baseLintelY + 14)
                    : min($canvasH - 1, $baseOuter['y'] + 16);
                $seatL = $baseMidLeftX;
                $seatR = $baseMidRightX;
                $scanL = $canvasW; $scanR = 0;
                for ($sx = max(0, $baseOuter['x'] - 10); $sx <= min($canvasW - 1, $baseOuter['x'] + $baseOuter['w'] + 10); $sx += 2) {
                    $rgb = imagecolorat($canvas, $sx, $seatMeasureY);
                    if (colorDist(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $canvasBg) > 30.0) {
                        if ($sx < $scanL) $scanL = $sx;
                        if ($sx > $scanR) $scanR = $sx;
                    }
                }
                if ($scanR - $scanL >= (int)($baseMidW * 0.72)) {
                    $seatL = $scanL;
                    $seatR = $scanR;
                }
                $seatW = max(80, $seatR - $seatL);
                $seatCenterX = ($seatL + $seatR) / 2.0;

                if ($cHasRealCrown) {
                    // Genuine arched/flared/framed crown: take cleanly up to its lintel bottom
                    $srcCrownH = max(50, min($cObj['h'], (int)round($cObj['crown_bottom_y'] * 1.02)));
                    $srcCrown = ['x' => 0, 'y' => 0, 'w' => $cObj['w'], 'h' => $srcCrownH];
                    $crownOverhang = $cObj['has_flared_crown'] ? 1.05 : 1.02;
                } else {
                    // Unframed flat door picked as crown: NEVER paste a giant raw panel slab!
                    // Extract ONLY its crisp top rail/decorative frieze band (11% height) and wrap in 3D stepped teak cornice molding!
                    $srcTopInset = (int)round($cObj['h'] * 0.015);
                    $srcCrownH = max(36, min((int)round($cObj['h'] * 0.13), (int)round($cObj['crown_bottom_y'] * 0.82)));
                    $srcCrown = [
                        'x' => (int)round($cObj['w'] * 0.03),
                        'y' => $srcTopInset,
                        'w' => max(40, (int)round($cObj['w'] * 0.94)),
                        'h' => $srcCrownH,
                    ];
                    $crownOverhang = 1.02;
                }

                $targetCrownW = min($canvasW - 56, (int)round($seatW * $crownOverhang));
                $crownNaturalH = (int)round($targetCrownW * ($srcCrown['h'] / max(1.0, (float)$srcCrown['w'])));

                if ($base['is_framed'] && !$useCleanMoldedFrame) {
                    // Erase the base's existing crown cleanly above the lintel seat so zero old cornice sticks out
                    $seatY = max(48, $baseLintelY);
                    imagefilledrectangle($canvas, 0, 0, $canvasW - 1, max(0, $seatY - 1), $bgCol);

                    $maxCrownH = max(56, $seatY - 34);
                    $minCrownH = $cHasRealCrown ? 74 : 58;
                    $capCrownH = $cHasRealCrown ? $maxCrownH : min($maxCrownH, 108);
                    $targetCrownH = min($capCrownH, max($minCrownH, $crownNaturalH));
                    if ($cHasRealCrown && $crownNaturalH > $maxCrownH) {
                        $ratio = $maxCrownH / (float)$crownNaturalH;
                        $targetCrownW = max((int)round($seatW * 0.99), (int)round($targetCrownW * max(0.88, $ratio)));
                    }
                    $dstCrownX = (int)round($seatCenterX - ($targetCrownW / 2.0));
                    $dstCrownX = max(24, min($canvasW - 24 - $targetCrownW, $dstCrownX));
                    // Seat crown snugly 6px onto the top lintel/pillar capitals so zero micro-gap appears
                    $dstCrownY = max(24, $seatY - $targetCrownH + 6);
                } else {
                    $seatY = max(48, $dstBaseY + ($useCleanMoldedFrame ? 10 : 6));
                    $maxCrownH = max(56, $seatY - 34);
                    $minCrownH = $cHasRealCrown ? 74 : 58;
                    $capCrownH = $cHasRealCrown ? $maxCrownH : min($maxCrownH, 108);
                    $targetCrownH = min($capCrownH, max($minCrownH, $crownNaturalH));
                    $dstCrownX = (int)round($seatCenterX - ($targetCrownW / 2.0));
                    $dstCrownX = max(24, min($canvasW - 24 - $targetCrownW, $dstCrownX));
                    $dstCrownY = max(24, $seatY - $targetCrownH + 6);
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
                    $baseWoodStats,
                    6,
                    false,
                    true,
                    $cObj['has_clean_bg'],
                    $cObj['bg'],
                    false
                );

                // For flat frieze headers, add sculpted 3D stepped teak cornice cap & architrave bead
                $crownTopBound = $dstCrownY;
                if (!$cHasRealCrown) {
                    drawArchitecturalCorniceMolding($canvas, $dstCrownX, $dstCrownY, $targetCrownW, $targetCrownH, $baseWoodRgb);
                    $crownTopBound = max(10, $dstCrownY - 18);
                    $finalLeftX = min($finalLeftX, max(10, $dstCrownX - 16));
                    $finalRightX = max($finalRightX, min($canvasW - 10, $dstCrownX + $targetCrownW + 16));
                } else {
                    $finalLeftX = min($finalLeftX, $dstCrownX);
                    $finalRightX = max($finalRightX, $dstCrownX + $targetCrownW);
                }

                // When replacing a framed base's original crown, update $finalTopY to the NEW crown's exact top!
                if ($base['is_framed'] && !$useCleanMoldedFrame) {
                    $finalTopY = $crownTopBound;
                } else {
                    $finalTopY = min($finalTopY, $crownTopBound);
                }

                // Cast soft architectural overhang shadow directly beneath the seated crown onto the pillars & lintel
                drawCrownSeatShadow($canvas, $seatL, $seatR, $dstCrownY + $targetCrownH - 2, $canvasBg, 14);
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

            // H) Measure exact real non-white door bounds so zero wasted top/side whitespace remains,
            //    then apply a tight, crisp studio crop (+ 26px breathing margin)!
            $realL = $canvasW; $realR = 0; $realT = $canvasH; $realB = 0;
            for ($cy = 0; $cy < $canvasH; $cy += 3) {
                for ($cx = 0; $cx < $canvasW; $cx += 3) {
                    $rgb = imagecolorat($canvas, $cx, $cy);
                    if (colorDist(($rgb >> 16) & 255, ($rgb >> 8) & 255, $rgb & 255, $canvasBg) > 22.0) {
                        if ($cx < $realL) $realL = $cx;
                        if ($cx > $realR) $realR = $cx;
                        if ($cy < $realT) $realT = $cy;
                        if ($cy > $realB) $realB = $cy;
                    }
                }
            }
            if ($realR > $realL + 80 && $realB > $realT + 120) {
                $finalLeftX = $realL;
                $finalRightX = $realR;
                $finalTopY = $realT;
                $finalBotY = $realB;
            } else {
                $finalBotY = $baseOuter['y'] + $baseOuter['h'];
            }

            $outMarginX = 28;
            $outMarginTop = 26;
            $outMarginBot = 28;
            $trimX0 = max(0, $finalLeftX - $outMarginX);
            $trimY0 = max(0, $finalTopY - $outMarginTop);
            $trimX1 = min($canvasW - 1, $finalRightX + $outMarginX);
            $trimY1 = min($canvasH - 1, $finalBotY + $outMarginBot);
            $trimW = max(120, $trimX1 - $trimX0 + 1);
            $trimH = max(160, $trimY1 - $trimY0 + 1);

            $finalImg = imagecreatetruecolor($trimW, $trimH);
            imagecopy($finalImg, $canvas, 0, 0, $trimX0, $trimY0, $trimW, $trimH);
            imagedestroy($canvas);

            imagepng($finalImg, $fullPath, 5);

            // I) Compute exact normalized 0..1 architectural zone coordinates on the final HD door
            $normBox = function (int $x, int $y, int $w, int $h) use ($trimX0, $trimY0, $trimW, $trimH): array {
                $nx = max(0.0, min(0.95, ($x - $trimX0) / (float)$trimW));
                $ny = max(0.0, min(0.95, ($y - $trimY0) / (float)$trimH));
                $nw = max(0.04, min(1.0 - $nx, $w / (float)$trimW));
                $nh = max(0.04, min(1.0 - $ny, $h / (float)$trimH));
                return [
                    'x' => round($nx, 4),
                    'y' => round($ny, 4),
                    'w' => round($nw, 4),
                    'h' => round($nh, 4),
                ];
            };

            $crownZoneH = max(48, ($baseLintelY - $finalTopY));
            $frameTopY = $base['is_framed'] ? max($finalTopY + (int)round($crownZoneH * 0.85), $baseLintelY - 8) : $baseOuter['y'];
            $centerInsetX = (int)round($baseInner['w'] * 0.08);
            $centerInsetY = (int)round($baseInner['h'] * 0.08);
            $borderStripW = max(24, (int)round($baseInner['w'] * 0.11));
            $borderStripH = max(80, (int)round($baseInner['h'] * 0.34));

            $elementRegions = [
                'crown'  => $normBox($finalLeftX, $finalTopY, max(60, $finalRightX - $finalLeftX), $crownZoneH),
                'frame'  => $normBox($baseMidLeftX, $frameTopY, max(60, $baseMidRightX - $baseMidLeftX), max(80, ($baseOuter['y'] + $baseOuter['h']) - $frameTopY)),
                'panel'  => $normBox($baseInner['x'], $baseInner['y'], $baseInner['w'], $baseInner['h']),
                'center' => $normBox(
                    $baseInner['x'] + $centerInsetX,
                    $baseInner['y'] + $centerInsetY,
                    max(40, $baseInner['w'] - $centerInsetX * 2),
                    max(60, $baseInner['h'] - $centerInsetY * 2)
                ),
                'border' => $normBox(
                    $baseInner['x'] + $baseInner['w'] - (int)round($borderStripW * 0.55),
                    $baseInner['y'] + $baseInner['h'] - $borderStripH - (int)round($baseInner['h'] * 0.08),
                    $borderStripW,
                    $borderStripH
                ),
            ];

            // Build accurate source metadata lookup for all 5 combine elements
            $designById = [];
            foreach ($refDesigns as $d) {
                $designById[(int)($d['id'] ?? 0)] = $d;
            }
            $buildBreakdownItem = function (int $num, string $key, string $label, string $colorHex, ?int $explicitId, int $fallbackId, string $desc) use ($designById): array {
                $effectiveId = $explicitId ?? $fallbackId;
                $d = $designById[$effectiveId] ?? ['id' => $effectiveId, 'title' => "Design #$effectiveId", 'image_url' => ''];
                return [
                    'number' => $num,
                    'key' => $key,
                    'label' => $label,
                    'color' => $colorHex,
                    'design_id' => $effectiveId,
                    'design_title' => (string)($d['title'] ?? "Design #$effectiveId"),
                    'design_image_url' => (string)($d['image_url'] ?? ''),
                    'is_explicit' => ($explicitId !== null),
                    'description' => $desc,
                ];
            };

            $effectiveLeafId = $latestLeafId ?? $baseId;
            $effectiveFrameFallback = $frameToneId ?? $baseId;

            $elementBreakdown = [
                $buildBreakdownItem(1, 'frame',  'Frame Style',            '#2563EB', $frameId,        $effectiveFrameFallback, 'Full outer wooden frame & left/right carved pillars'),
                $buildBreakdownItem(2, 'center', 'Center Carving',         '#EA580C', $latestLeafRole === 'center' ? $latestLeafId : null, $effectiveLeafId, 'Main carving artwork inside the door leaf'),
                $buildBreakdownItem(3, 'border', 'Border / Polish Finish', '#9333EA', $finishId,       $effectiveFrameFallback, "$polishShade wood tone, shine & inner border molding"),
                $buildBreakdownItem(4, 'crown',  'Top Arch & Crown',       '#DC2626', $crownId,        $baseId,                 'Top arch, temple carving & crown header only'),
                $buildBreakdownItem(5, 'panel',  'Panel Layout',           '#16A34A', $latestLeafRole === 'panel' ? $latestLeafId : null,  $effectiveLeafId, 'Full inner door shutter & panel layout'),
            ];

            // J) Render companion HD Pictorial Breakdown Guide PNG matching the reference diagram
            $guideFilename = preg_replace('/\.png$/i', '-guide.png', $filename);
            $guidePath = rtrim($outputDir, '/\\') . DIRECTORY_SEPARATOR . $guideFilename;
            $thumbImgs = [];
            foreach ($objs as $did => $o) {
                $thumbImgs[$did] = $o['img'];
            }
            $guideOk = renderAnnotatedGuidePngPhp(
                $finalImg,
                $elementRegions,
                $elementBreakdown,
                $thumbImgs,
                $category,
                $guidePath
            );

            $outputAspect = round($trimW / max(1.0, (float)$trimH), 4);
            $metaFilename = preg_replace('/\.png$/i', '-meta.json', $filename);
            $metaPath = rtrim($outputDir, '/\\') . DIRECTORY_SEPARATOR . $metaFilename;
            @file_put_contents($metaPath, json_encode([
                'element_regions' => $elementRegions,
                'element_breakdown' => $elementBreakdown,
                'output_aspect' => $outputAspect,
                'ai_guide_image_url' => $guideOk ? ('/uploads/ai-outputs/' . $guideFilename) : null,
            ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));

            imagedestroy($finalImg);
            foreach ($objs as $o) {
                imagedestroy($o['img']);
            }

            return [
                'filename' => $filename,
                'full_path' => $fullPath,
                'guide_filename' => $guideOk ? $guideFilename : null,
                'guide_full_path' => $guideOk ? $guidePath : null,
                'element_regions' => $elementRegions,
                'element_breakdown' => $elementBreakdown,
                'output_aspect' => $outputAspect,
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
