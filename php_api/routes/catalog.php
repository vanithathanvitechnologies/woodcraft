<?php
require_once __DIR__ . '/../helpers/door_generator.php';

function saveUploadedCatalogImages(array $files): array {
    $allowedExts = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
    $targetDir = __DIR__ . '/../uploads/catalog';
    if (!is_dir($targetDir)) {
        mkdir($targetDir, 0755, true);
    }

    $uploadedUrls = [];
    if (isset($files['name']) && is_array($files['name'])) {
        for ($i = 0; $i < count($files['name']); $i++) {
            if (($files['error'][$i] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_OK) {
                $ext = strtolower(pathinfo((string)$files['name'][$i], PATHINFO_EXTENSION) ?: 'jpg');
                if (!in_array($ext, $allowedExts, true)) {
                    $ext = 'jpg';
                }
                $fname = 'catalog-' . time() . '-' . random_int(1000, 9999) . '.' . $ext;
                if (move_uploaded_file($files['tmp_name'][$i], "$targetDir/$fname")) {
                    $uploadedUrls[] = "/uploads/catalog/$fname";
                }
            }
        }
    } elseif (($files['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_OK) {
        $ext = strtolower(pathinfo((string)$files['name'], PATHINFO_EXTENSION) ?: 'jpg');
        if (!in_array($ext, $allowedExts, true)) {
            $ext = 'jpg';
        }
        $fname = 'catalog-' . time() . '-' . random_int(1000, 9999) . '.' . $ext;
        if (move_uploaded_file($files['tmp_name'], "$targetDir/$fname")) {
            $uploadedUrls[] = "/uploads/catalog/$fname";
        }
    }

    return $uploadedUrls;
}

function handleCatalogRoutes(string $method, array $segments): void {
    $pdo = getDb();

    // POST /api/catalog/ai-combine (Sales, Owner, Admin)
    if ($method === 'POST' && ($segments[0] ?? '') === 'ai-combine') {
        requireRoles(['admin', 'owner', 'sales']);
        $body = getJsonBody();
        $refIds = $body['reference_design_ids'] ?? [];
        $refElements = $body['reference_elements'] ?? [];

        if (!is_array($refIds) || count($refIds) < 1 || count($refIds) > 5) {
            jsonResponse(['success' => false, 'message' => 'Select between 1 and 5 catalog reference designs'], 400);
        }

        $placeholders = implode(',', array_fill(0, count($refIds), '?'));
        $stmt = $pdo->prepare("SELECT id, title, base_price, image_url, carving_style, wood_species FROM design_catalog WHERE id IN ($placeholders)");
        $stmt->execute($refIds);
        $refDesigns = $stmt->fetchAll();

        $category = (string)($body['woodwork_category'] ?? 'Door');
        $width = (float)($body['width_inches'] ?? 36);
        $height = (float)($body['height_inches'] ?? 84);
        $frameSection = (string)($body['frame_section'] ?? '5 x 3 inch');
        $thickness = (string)($body['door_thickness'] ?? '1.75 inch (45mm)');
        $leafType = (string)($body['leaf_type'] ?? 'Single Leaf');
        $woodSpecies = (string)($body['wood_species'] ?? 'Burma Teak');
        $carvingPattern = (string)($body['carving_pattern'] ?? '');
        $polishShade = (string)($body['polish_shade'] ?? 'Natural Teak Matte');
        $hardware = (string)($body['hardware'] ?? 'Antique Brass Handle & Mortise Lock');
        $customNotes = (string)($body['custom_notes'] ?? '');
        $qty = max(1, (int)($body['quantity'] ?? 1));

        $titleById = [];
        foreach ($refDesigns as $d) {
            $titleById[(int)$d['id']] = (string)($d['title'] ?? ('Design #' . $d['id']));
        }
        $elSummary = [];
        foreach ($refElements as $el) {
            $did = (int)($el['design_id'] ?? 0);
            $dLabel = $titleById[$did] ?? ('Design #' . $did);
            $elSummary[] = ($el['element'] ?? 'Element') . ' from ' . $dLabel;
        }
        $promptUsed = "Unified $leafType $category ({$width}\" x {$height}\", $frameSection frame, $thickness) in $woodSpecies with $polishShade finish, $hardware"
            . ($carvingPattern !== '' ? ", carving: $carvingPattern" : '')
            . (!empty($elSummary) ? ', combining ' . implode(', ', $elSummary) : '')
            . ($customNotes !== '' ? ". Notes: $customNotes" : '.');

        $rendered = renderDoorPngPhp([
            'wood_species' => $woodSpecies,
            'polish_shade' => $polishShade,
            'leaf_type' => $leafType,
            'woodwork_category' => $category,
            'reference_designs' => $refDesigns,
            'reference_elements' => $refElements,
            'prompt_text' => $promptUsed,
            'uploads_root' => dirname(__DIR__),
            'output_dir' => __DIR__ . '/../uploads/ai-outputs',
            'prefix' => 'ai-combined',
        ]);

        $avgBase = 28000;
        if (count($refDesigns) > 0) {
            $sum = 0;
            foreach ($refDesigns as $d) $sum += (float)$d['base_price'];
            $avgBase = $sum / count($refDesigns);
        }

        $areaSqFt = ($width * $height) / 144.0;
        $areaFactor = max(0.8, $areaSqFt / 21.0);
        $woodMult = getWoodMultiplier($woodSpecies);
        $leafMult = ($leafType === 'Double Leaf') ? 1.45 : 1.0;
        $hardwareCost = 4500;
        $polishCost = 3500;
        $unitCost = (int)round($avgBase * $areaFactor * $woodMult * $leafMult + $hardwareCost + $polishCost);

        jsonResponse([
            'success' => true,
            'ai_output_image_url' => '/uploads/ai-outputs/' . $rendered['filename'],
            'ai_guide_image_url' => !empty($rendered['guide_filename']) ? ('/uploads/ai-outputs/' . $rendered['guide_filename']) : null,
            'element_regions' => $rendered['element_regions'] ?? null,
            'element_breakdown' => $rendered['element_breakdown'] ?? [],
            'output_aspect' => $rendered['output_aspect'] ?? 0.75,
            'prompt_used' => $promptUsed,
            'engine' => $rendered['engine'] ?? 'php-real-photo-combiner',
            'reference_designs' => $refDesigns,
            'cost_estimate' => [
                'area_sqft' => round($areaSqFt, 2),
                'unit_cost' => $unitCost,
                'hardware_cost' => $hardwareCost,
                'polish_cost' => $polishCost,
                'quantity' => $qty,
                'total_estimated_cost' => $unitCost * $qty,
            ],
        ]);
    }

    $id = isset($segments[0]) && is_numeric($segments[0]) ? (int)$segments[0] : null;

    // GET /api/catalog (Sales, Owner, Admin)
    if ($method === 'GET' && $id === null) {
        requireRoles(['admin', 'owner', 'sales']);
        $sql = 'SELECT * FROM design_catalog WHERE 1=1';
        $params = [];

        if (($_GET['include_archived'] ?? '') !== 'true') {
            $sql .= ' AND is_archived = 0';
        }
        if (!empty($_GET['category']) && $_GET['category'] !== 'All') {
            $sql .= ' AND LOWER(TRIM(category)) = LOWER(TRIM(?))';
            $params[] = $_GET['category'];
        }
        if (!empty($_GET['wood_species']) && $_GET['wood_species'] !== 'All') {
            $sql .= ' AND wood_species = ?';
            $params[] = $_GET['wood_species'];
        }
        if (($_GET['trending'] ?? '') === 'true') {
            $sql .= ' AND is_trending = 1';
        }
        if (!empty($_GET['search'])) {
            $sql .= ' AND (title LIKE ? OR carving_style LIKE ? OR tags LIKE ? OR wood_species LIKE ? OR category LIKE ?)';
            $like = '%' . trim($_GET['search']) . '%';
            array_push($params, $like, $like, $like, $like, $like);
        }

        $sql .= ' ORDER BY is_trending DESC, created_at DESC';
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        jsonResponse(['success' => true, 'designs' => $stmt->fetchAll()]);
    }

    // POST /api/catalog (Admin / Owner ONLY — supports multipart file upload and JSON)
    if ($method === 'POST' && $id === null) {
        $authUser = requireRoles(['admin', 'owner']);
        $isMultipart = !empty($_POST) || !empty($_FILES);
        $data = $isMultipart ? $_POST : getJsonBody();

        $title = trim((string)($data['title'] ?? ''));
        if (!$title) jsonResponse(['success' => false, 'message' => 'Design title is required'], 400);

        $uploadedUrls = !empty($_FILES['images']) ? saveUploadedCatalogImages($_FILES['images']) : [];

        $primaryImage = $uploadedUrls[0] ?? trim((string)($data['image_url'] ?? ''));
        if ($primaryImage === '') {
            jsonResponse(['success' => false, 'message' => 'Please upload a design photo'], 400);
        }
        $extraImages = array_slice($uploadedUrls, 1);
        $isTrending = (!empty($data['is_trending']) && $data['is_trending'] !== '0' && $data['is_trending'] !== 'false') ? 1 : 0;
        $category = trim((string)($data['category'] ?? 'Door')) ?: 'Door';

        $ins = $pdo->prepare(
            'INSERT INTO design_catalog (title, category, carving_style, wood_species, base_price, image_url, additional_images, tags, description, is_trending, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
        );
        $ins->execute([
            $title,
            $category,
            trim((string)($data['carving_style'] ?? '')),
            trim((string)($data['wood_species'] ?? 'Burma Teak')) ?: 'Burma Teak',
            (float)($data['base_price'] ?? 25000),
            $primaryImage,
            json_encode($extraImages),
            trim((string)($data['tags'] ?? '')),
            trim((string)($data['description'] ?? '')),
            $isTrending,
            $authUser['id'],
        ]);

        $get = $pdo->prepare('SELECT * FROM design_catalog WHERE id = ?');
        $get->execute([(int)$pdo->lastInsertId()]);
        jsonResponse(['success' => true, 'design' => $get->fetch()], 201);
    }

    // PUT /api/catalog/:id or POST /api/catalog/:id (Admin / Owner ONLY — POST supports multipart image replacement)
    if (($method === 'PUT' || $method === 'POST') && $id !== null) {
        requireRoles(['admin', 'owner']);
        $isMultipart = !empty($_POST) || !empty($_FILES);
        $body = $isMultipart ? $_POST : getJsonBody();

        $allowed = ['title', 'category', 'carving_style', 'wood_species', 'base_price', 'tags', 'description', 'is_trending', 'is_archived'];
        $fields = [];
        $params = [];
        foreach ($allowed as $key) {
            if (array_key_exists($key, $body)) {
                $fields[] = "$key = ?";
                if ($key === 'is_trending' || $key === 'is_archived') {
                    $v = $body[$key];
                    $truthy = ($v === true || $v === 1 || $v === '1' || $v === 'true');
                    $params[] = $truthy ? 1 : 0;
                } elseif ($key === 'base_price') {
                    $params[] = (float)$body[$key];
                } else {
                    $params[] = trim((string)$body[$key]);
                }
            }
        }

        if (!empty($_FILES['images'])) {
            $uploadedUrls = saveUploadedCatalogImages($_FILES['images']);
            if (!empty($uploadedUrls)) {
                $fields[] = 'image_url = ?';
                $params[] = $uploadedUrls[0];
                if (count($uploadedUrls) > 1) {
                    $fields[] = 'additional_images = ?';
                    $params[] = json_encode(array_slice($uploadedUrls, 1));
                }
            }
        }

        if (!$fields) jsonResponse(['success' => false, 'message' => 'No fields to update'], 400);
        $params[] = $id;
        $pdo->prepare('UPDATE design_catalog SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);

        $get = $pdo->prepare('SELECT * FROM design_catalog WHERE id = ?');
        $get->execute([$id]);
        jsonResponse(['success' => true, 'design' => $get->fetch()]);
    }

    // DELETE /api/catalog/:id (Admin / Owner ONLY)
    if ($method === 'DELETE' && $id !== null) {
        requireRoles(['admin', 'owner']);
        if (($_GET['permanent'] ?? '') === 'true') {
            $pdo->prepare('DELETE FROM design_catalog WHERE id = ?')->execute([$id]);
            jsonResponse(['success' => true, 'message' => 'Design permanently deleted']);
        }
        $pdo->prepare('UPDATE design_catalog SET is_archived = 1 WHERE id = ?')->execute([$id]);
        jsonResponse(['success' => true, 'message' => 'Design archived']);
    }

    jsonResponse(['success' => false, 'message' => 'Catalog endpoint not found'], 404);
}
