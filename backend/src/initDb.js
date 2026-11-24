const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
require('dotenv').config();

const { renderDoorPng } = require('./utils/aiDoorGenerator');
const { getStageName } = require('./config/constants');

async function initDb() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    multipleStatements: true,
  });

  console.log('Connected to MySQL server. Running schema.sql...');
  const schemaPath = path.join(__dirname, '..', 'sql', 'schema.sql');
  const schemaSql = fs.readFileSync(schemaPath, 'utf8');
  await connection.query(schemaSql);
  await connection.query(`USE \`${process.env.DB_NAME || 'wooden_door_db'}\``);

  // 1. Seed default staff accounts (Admin, Owner, Sales, Production)
  const defaultPasswordHash = await bcrypt.hash('123456', 10);
  const seedUsers = [
    ['Admin', 'admin@wooden.com', '7603970435', 'admin'],
    ['Owner', 'owner@wooden.com', '7603970435', 'owner'],
    ['Sales Team', 'sales@wooden.com', '7603970435', 'sales'],
    ['Production Team', 'production@wooden.com', '7603970435', 'production'],
  ];

  for (const [name, email, phone, role] of seedUsers) {
    await connection.query(
      `INSERT IGNORE INTO users (name, email, phone, password_hash, role, is_active)
       VALUES (?, ?, ?, ?, ?, 1)`,
      [name, email, phone, defaultPasswordHash, role]
    );
  }

  const [[salesUser]] = await connection.query("SELECT id FROM users WHERE role = 'sales' LIMIT 1");
  const [[prodUser]] = await connection.query("SELECT id FROM users WHERE role = 'production' LIMIT 1");

  // 2. Seed Design Catalog (uses Suresh Timbers catalog manifest if available)
  const [[catalogCount]] = await connection.query('SELECT COUNT(*) AS cnt FROM design_catalog');
  if (catalogCount.cnt === 0) {
    const catalogDir = path.join(__dirname, '..', 'uploads', 'catalog');
    const stManifestPath = path.join(catalogDir, 'suresh_timbers_catalog.json');
    if (fs.existsSync(stManifestPath)) {
      const stData = JSON.parse(fs.readFileSync(stManifestPath, 'utf8'));
      const stItems = Array.isArray(stData.items) ? stData.items : [];
      for (const item of stItems) {
        await connection.query(
          `INSERT INTO design_catalog
            (title, category, carving_style, wood_species, base_price, image_url, additional_images, tags, description, is_trending, created_by)
           VALUES (?, ?, ?, ?, ?, ?, '[]', ?, ?, ?, ?)`,
          [
            item.title,
            item.category || 'Main Door & Frame',
            item.carving_style || '',
            item.wood_species || 'Burma Teak',
            Number(item.base_price) || 35000,
            item.image_url,
            item.tags || 'suresh timbers',
            item.description || '',
            item.is_trending ? 1 : 0,
            salesUser ? salesUser.id : null,
          ]
        );
      }
      console.log(`Seeded ${stItems.length} Suresh Timbers catalog designs.`);
    } else {
      const samples = [
        {
          title: 'Royal Chettinad Lotus Main Door',
          category: 'Main Door & Frame',
          carving_style: 'Chettinad Floral & Pillar',
          wood_species: 'Burma Teak',
          base_price: 42000,
          polish: 'Natural Teak Matte',
          leaf: 'Double Leaf',
          tags: 'main door,chettinad,double leaf,luxury',
          trending: 1,
        },
        {
          title: 'Temple Bells Pooja Door',
          category: 'Pooja Door',
          carving_style: 'Traditional Temple Brass Bells',
          wood_species: 'Nilambur Teak',
          base_price: 34000,
          polish: 'Honey Gold Gloss',
          leaf: 'Double Leaf',
          tags: 'pooja,temple,bells,teak',
          trending: 1,
        },
        {
          title: 'Modern Heritage Panel Main Door',
          category: 'Main Door & Frame',
          carving_style: 'Minimalist Carved Medallion',
          wood_species: 'Ghana Teak',
          base_price: 29500,
          polish: 'Dark Walnut Satin',
          leaf: 'Single Leaf',
          tags: 'modern,single leaf,walnut',
          trending: 1,
        },
        {
          title: 'Rosewood Peacock Grand Frame',
          category: 'Main Door & Frame',
          carving_style: 'Peacock Arch Carving',
          wood_species: 'Indian Rosewood',
          base_price: 54000,
          polish: 'Royal Rosewood Gloss',
          leaf: 'Double Leaf',
          tags: 'rosewood,peacock,grand,luxury',
          trending: 0,
        },
        {
          title: 'Classic Teak Arch Window',
          category: 'Window',
          carving_style: 'Beaded Border Frame',
          wood_species: 'Burma Teak',
          base_price: 18500,
          polish: 'Natural PU Clear',
          leaf: 'Double Leaf',
          tags: 'window,teak,ventilation',
          trending: 0,
        },
      ];

      for (let i = 0; i < samples.length; i++) {
        const s = samples[i];
        const rendered = renderDoorPng({
          woodSpecies: s.wood_species,
          polishShade: s.polish,
          leafType: s.leaf,
          carvingPattern: s.carving_style,
          category: s.category,
          seed: i + 10,
          outputDir: catalogDir,
          filePrefix: `catalog-${i + 1}`,
        });

        await connection.query(
          `INSERT INTO design_catalog
            (title, category, carving_style, wood_species, base_price, image_url, tags, description, is_trending, created_by)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            s.title,
            s.category,
            s.carving_style,
            s.wood_species,
            s.base_price,
            `/uploads/catalog/${rendered.filename}`,
            s.tags,
            `Handcrafted ${s.title} in seasoned ${s.wood_species}.`,
            s.trending,
            salesUser ? salesUser.id : null,
          ]
        );
      }
      console.log('Seeded 5 sample designs with PNG artwork.');
    }
  }

  // 3. Seed Initial Customer & Orders if empty
  const [[orderCount]] = await connection.query('SELECT COUNT(*) AS cnt FROM orders');
  if (orderCount.cnt === 0) {
    const [cust1] = await connection.query(
      `INSERT INTO customers (name, mobile, delivery_address, created_by)
       VALUES ('Surexo Customer', '7603970435', '', ?)
       ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id)`,
      [salesUser ? salesUser.id : null]
    );
    const cust2 = cust1;

    const [designs] = await connection.query('SELECT id FROM design_catalog ORDER BY id ASC LIMIT 3');
    const dIds = designs.map((d) => d.id);

    const aiOutDir = path.join(__dirname, '..', 'uploads', 'ai-outputs');
    const ai1 = renderDoorPng({
      woodSpecies: 'Burma Teak',
      polishShade: 'Natural Teak Matte',
      leafType: 'Double Leaf',
      carvingPattern: 'Chettinad Lotus + Temple Border',
      category: 'Main Door & Frame',
      seed: 42,
      outputDir: aiOutDir,
      filePrefix: 'seed-order-1',
    });
    const ai2 = renderDoorPng({
      woodSpecies: 'Nilambur Teak',
      polishShade: 'Honey Gold Gloss',
      leafType: 'Single Leaf',
      carvingPattern: 'Temple Brass Bell Pooja',
      category: 'Pooja Door',
      seed: 77,
      outputDir: aiOutDir,
      filePrefix: 'seed-order-2',
    });

    const delivery1 = new Date(Date.now() + 10 * 86400000).toISOString().slice(0, 10);
    const delivery2 = new Date(Date.now() + 4 * 86400000).toISOString().slice(0, 10);

    const [ord1] = await connection.query(
      `INSERT INTO orders (
        job_id, customer_id, sales_user_id, assigned_production_user_id,
        woodwork_category, width_inches, height_inches, frame_section, door_thickness,
        leaf_type, wood_species, carving_pattern, polish_shade, hardware, quantity,
        custom_notes, workshop_notes, reference_design_ids, reference_elements, ai_output_image_url,
        total_cost, advance_amount, balance_amount, expected_delivery_date, priority,
        current_stage, current_stage_name, is_dispatched
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`,
      [
        'SUW-2026-0001',
        cust1.insertId,
        salesUser?.id || null,
        prodUser?.id || null,
        'Main Door & Frame',
        48,
        84,
        '5 x 3.5 inch',
        '2 inch (50mm)',
        'Double Leaf',
        'Burma Teak',
        'Chettinad Lotus Center + Beaded Frame',
        'Natural Teak Matte',
        'Antique Brass Lion Handles & Yale Mortise',
        1,
        'Ensure deep 3D lotus carving in center panels',
        'Check timber moisture <10% before CNC carving. 5x3.5 seasoned Burma teak frame.',
        JSON.stringify(dIds.slice(0, 2)),
        JSON.stringify([
          { design_id: dIds[0], element: 'Frame Style & Center Carving' },
          { design_id: dIds[1], element: 'Border & Polish Finish' },
        ]),
        `/uploads/ai-outputs/${ai1.filename}`,
        78500,
        35000,
        43500,
        delivery1,
        'High',
        4,
        getStageName(4),
      ]
    );

    for (let st = 1; st <= 4; st++) {
      await connection.query(
        'INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes) VALUES (?, ?, ?, ?, ?)',
        [ord1.insertId, st, getStageName(st), st === 1 ? salesUser?.id : prodUser?.id, `Completed / moved to ${getStageName(st)}`]
      );
    }

    const [ord2] = await connection.query(
      `INSERT INTO orders (
        job_id, customer_id, sales_user_id, assigned_production_user_id,
        woodwork_category, width_inches, height_inches, frame_section, door_thickness,
        leaf_type, wood_species, carving_pattern, polish_shade, hardware, quantity,
        custom_notes, workshop_notes, reference_design_ids, reference_elements, ai_output_image_url,
        total_cost, advance_amount, balance_amount, expected_delivery_date, priority,
        current_stage, current_stage_name, is_dispatched
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`,
      [
        'SUW-2026-0002',
        cust2.insertId,
        salesUser?.id || null,
        prodUser?.id || null,
        'Pooja Door',
        36,
        78,
        '4 x 3 inch',
        '1.5 inch (38mm)',
        'Double Leaf',
        'Nilambur Teak',
        'Traditional Temple Bells Grid',
        'Honey Gold Gloss',
        '24 Solid Brass Bells + Brass Aldrop',
        1,
        'Include Om motif on top arch',
        'Drill brass bell slots precisely with 1.5 inch spacing.',
        JSON.stringify(dIds.slice(1, 3)),
        JSON.stringify([{ design_id: dIds[1], element: 'Temple Bells Grid' }]),
        `/uploads/ai-outputs/${ai2.filename}`,
        46000,
        20000,
        26000,
        delivery2,
        'Urgent',
        6,
        getStageName(6),
      ]
    );

    for (let st = 1; st <= 6; st++) {
      await connection.query(
        'INSERT INTO order_stage_history (order_id, stage_number, stage_name, updated_by, notes) VALUES (?, ?, ?, ?, ?)',
        [ord2.insertId, st, getStageName(st), st === 1 ? salesUser?.id : prodUser?.id, `Stage updated: ${getStageName(st)}`]
      );
    }

    console.log('Seeded initial customer (7603970435) and 2 live orders.');
  }

  console.log('Database initialization complete!');
  console.log('Staff Logins:');
  console.log('  Admin:      admin@wooden.com');
  console.log('  Owner:      owner@wooden.com');
  console.log('  Sales:      sales@wooden.com');
  console.log('  Production: production@wooden.com');
  console.log('Customer Mobile for OTP Login: 7603970435');
  await connection.end();
}

initDb().catch((err) => {
  console.error('Database initialization failed:', err.message);
  process.exit(1);
});
