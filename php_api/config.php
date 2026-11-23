<?php
// cPanel MySQL Database Configuration
// Update these 4 values with your cPanel MySQL database details
define('DB_HOST', 'localhost');
define('DB_PORT', '3306');
define('DB_NAME', 'wooden_door_db');
define('DB_USER', 'root');
define('DB_PASS', '');

// JWT Security Secret (change to a random string in production)
define('JWT_SECRET', 'wooden_door_super_secret_jwt_key_2026');
define('JWT_EXPIRES_SECONDS', 7 * 24 * 60 * 60); // 7 days

// Automatic OTP Verification for Customer App (true = auto-fill & auto-verify)
define('AUTO_VERIFY_OTP', true);

// Optional: Google Gemini API Key for Generative AI Door Combining
// Leave empty ('') to use the built-in photorealistic PHP catalog photo compositor
define('GEMINI_API_KEY', '');
define('GEMINI_IMAGE_MODEL', 'gemini-2.5-flash-image');
