<?php

const PRODUCTION_STAGES = [
    ['number' => 1, 'name' => 'Pending / New Job', 'short' => 'New Job'],
    ['number' => 2, 'name' => 'Timber Cutting', 'short' => 'Cutting'],
    ['number' => 3, 'name' => 'Frame Fabrication', 'short' => 'Frame'],
    ['number' => 4, 'name' => 'Carving / CNC Work', 'short' => 'Carving'],
    ['number' => 5, 'name' => 'Door Assembly', 'short' => 'Assembly'],
    ['number' => 6, 'name' => 'Sanding & Polishing', 'short' => 'Polishing'],
    ['number' => 7, 'name' => 'Quality Check', 'short' => 'QC'],
    ['number' => 8, 'name' => 'Completed / Ready for Delivery', 'short' => 'Ready'],
];

const WOODWORK_CATEGORIES = [
    'Door',
    'Wood Frames',
    'Hard Wood',
];

const WOOD_SPECIES = [
    ['name' => 'Burma Teak', 'multiplier' => 1.45, 'colorHex' => '#8B5A2B'],
    ['name' => 'Ghana Teak', 'multiplier' => 1.25, 'colorHex' => '#9C6631'],
    ['name' => 'Nilambur Teak', 'multiplier' => 1.35, 'colorHex' => '#7A4924'],
    ['name' => 'Indian Rosewood', 'multiplier' => 1.50, 'colorHex' => '#4E2A1E'],
    ['name' => 'Mahogany', 'multiplier' => 1.15, 'colorHex' => '#6E2E22'],
    ['name' => 'Sal Wood', 'multiplier' => 1.00, 'colorHex' => '#A67B5B'],
    ['name' => 'Vengai Wood', 'multiplier' => 1.20, 'colorHex' => '#8C4A27'],
];

const POLISH_SHADES = [
    ['name' => 'Natural Teak Matte', 'hex' => '#9E6B3B'],
    ['name' => 'Honey Gold Gloss', 'hex' => '#C68B3C'],
    ['name' => 'Dark Walnut Satin', 'hex' => '#4A2C1D'],
    ['name' => 'Royal Rosewood Gloss', 'hex' => '#3D1E18'],
    ['name' => 'Antique Heritage Finish', 'hex' => '#633C22'],
    ['name' => 'Natural PU Clear', 'hex' => '#B4834D'],
];

function getStageName(int $stageNumber): string {
    foreach (PRODUCTION_STAGES as $s) {
        if ($s['number'] === $stageNumber) return $s['name'];
    }
    return 'Pending / New Job';
}

function getWoodMultiplier(string $species): float {
    foreach (WOOD_SPECIES as $w) {
        if ($w['name'] === $species) return (float)$w['multiplier'];
    }
    return 1.2;
}

function getPolishHex(string $polish, string $species): string {
    foreach (POLISH_SHADES as $p) {
        if ($p['name'] === $polish) return $p['hex'];
    }
    foreach (WOOD_SPECIES as $w) {
        if ($w['name'] === $species) return $w['colorHex'];
    }
    return '#8B5A2B';
}
