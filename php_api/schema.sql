-- Wooden Door & Frame Customizer - cPanel phpMyAdmin Ready Schema
-- Select your cPanel database in phpMyAdmin, then import this file directly.

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(120) NOT NULL,
  email VARCHAR(160) NOT NULL UNIQUE,
  phone VARCHAR(20) NULL,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('admin', 'owner', 'sales', 'production') NOT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_users_role (role),
  INDEX idx_users_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS customers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  mobile VARCHAR(20) NOT NULL UNIQUE,
  delivery_address TEXT NULL,
  created_by INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_customers_mobile (mobile),
  CONSTRAINT fk_customers_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS customer_otps (
  id INT AUTO_INCREMENT PRIMARY KEY,
  mobile VARCHAR(20) NOT NULL,
  otp_code VARCHAR(10) NOT NULL,
  expires_at DATETIME NOT NULL,
  verified TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_otp_mobile (mobile)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS wooden_categories (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description VARCHAR(255) NOT NULL DEFAULT '',
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 0,
  created_by INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_wooden_categories_active (is_active),
  INDEX idx_wooden_categories_sort (sort_order),
  CONSTRAINT fk_wooden_categories_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS design_catalog (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(180) NOT NULL,
  category VARCHAR(80) NOT NULL DEFAULT 'Door',
  carving_style VARCHAR(100) NULL,
  wood_species VARCHAR(100) NOT NULL DEFAULT 'Burma Teak',
  base_price DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  image_url VARCHAR(500) NOT NULL,
  additional_images TEXT NULL,
  tags VARCHAR(255) NULL,
  description TEXT NULL,
  is_trending TINYINT(1) NOT NULL DEFAULT 0,
  is_archived TINYINT(1) NOT NULL DEFAULT 0,
  created_by INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_catalog_category (category),
  INDEX idx_catalog_wood (wood_species),
  INDEX idx_catalog_archived (is_archived),
  CONSTRAINT fk_catalog_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  job_id VARCHAR(40) NOT NULL UNIQUE,
  customer_id INT NOT NULL,
  sales_user_id INT NULL,
  assigned_production_user_id INT NULL,
  production_place VARCHAR(180) NULL,

  woodwork_category VARCHAR(80) NOT NULL DEFAULT 'Door',
  width_inches DECIMAL(8, 2) NOT NULL DEFAULT 36.00,
  height_inches DECIMAL(8, 2) NOT NULL DEFAULT 84.00,
  frame_section VARCHAR(60) NOT NULL DEFAULT '5 x 3 inch',
  door_thickness VARCHAR(40) NOT NULL DEFAULT '1.75 inch (45mm)',
  leaf_type ENUM('Single Leaf', 'Double Leaf') NOT NULL DEFAULT 'Single Leaf',
  wood_species VARCHAR(100) NOT NULL DEFAULT 'Burma Teak',
  carving_pattern VARCHAR(120) NULL,
  polish_shade VARCHAR(100) NOT NULL DEFAULT 'Natural Teak Matte',
  hardware VARCHAR(180) NULL,
  quantity INT NOT NULL DEFAULT 1,
  custom_notes TEXT NULL,
  workshop_notes TEXT NULL,

  reference_design_ids TEXT NULL,
  reference_elements TEXT NULL,
  ai_output_image_url VARCHAR(500) NULL,

  total_cost DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  advance_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  balance_amount DECIMAL(12, 2) NOT NULL DEFAULT 0.00,

  expected_delivery_date DATE NOT NULL,
  priority ENUM('Normal', 'High', 'Urgent') NOT NULL DEFAULT 'Normal',
  current_stage TINYINT NOT NULL DEFAULT 1,
  current_stage_name VARCHAR(80) NOT NULL DEFAULT 'Pending / New Job',
  is_dispatched TINYINT(1) NOT NULL DEFAULT 1,
  has_blocker TINYINT(1) NOT NULL DEFAULT 0,
  blocker_note TEXT NULL,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_orders_job_id (job_id),
  INDEX idx_orders_stage (current_stage),
  INDEX idx_orders_delivery (expected_delivery_date),
  INDEX idx_orders_dispatched (is_dispatched),
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE RESTRICT,
  CONSTRAINT fk_orders_sales FOREIGN KEY (sales_user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_orders_production FOREIGN KEY (assigned_production_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS order_stage_history (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  stage_number TINYINT NOT NULL,
  stage_name VARCHAR(80) NOT NULL,
  updated_by INT NULL,
  notes TEXT NULL,
  is_blocker TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_history_order (order_id),
  CONSTRAINT fk_history_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_history_user FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS order_progress_photos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  stage_number TINYINT NOT NULL,
  stage_name VARCHAR(80) NOT NULL,
  photo_url VARCHAR(500) NOT NULL,
  caption VARCHAR(255) NULL,
  uploaded_by INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_photos_order (order_id),
  CONSTRAINT fk_photos_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  CONSTRAINT fk_photos_user FOREIGN KEY (uploaded_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS notifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  order_id INT NOT NULL,
  type VARCHAR(50) NOT NULL,
  title VARCHAR(180) NOT NULL,
  message TEXT NOT NULL,
  notify_for_date DATE NULL,
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_user_order_type_date (user_id, order_id, type, notify_for_date),
  INDEX idx_notif_user_read (user_id, is_read),
  INDEX idx_notif_order (order_id),
  CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_notif_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
