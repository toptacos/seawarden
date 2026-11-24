<?php
/**
 * Plugin Name: SeaWarden Backup Status
 * Description: Live vault metrics for SeaWarden pull backups (HTTPS status API only — no vault SSH keys).
 * Version: 1.0.0
 * Author: SeaWarden
 * License: GPL-2.0-or-later
 * Text Domain: seawarden-backup-status
 */

if (!defined('ABSPATH')) {
    exit;
}

define('SWBS_VERSION', '1.0.0');
define('SWBS_PATH', plugin_dir_path(__FILE__));

require_once SWBS_PATH . 'includes/class-backup-status.php';

new SeaWarden_Backup_Status();
